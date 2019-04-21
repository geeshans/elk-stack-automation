# Specify the provider and access details
provider "aws" {
  region = "${var.aws_region}"
}

### NETWORK CONFIGURATIONS ###

# Fetch AZs in the current region
data "aws_availability_zones" "available" {}

# Create VPC with support for service discovery
resource "aws_vpc" "main" {
  cidr_block = "10.16.0.0/16"
  enable_dns_support = "true"
  enable_dns_hostnames = "true"
}

# Create var.az_count private subnets, each in a different AZ
#cidrsubnet(iprange, newbits, netnum)
resource "aws_subnet" "private" {
  count             = "${var.az_count}"
  cidr_block        = "${cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)}"
  availability_zone = "${data.aws_availability_zones.available.names[count.index]}"
  vpc_id            = "${aws_vpc.main.id}"
}

# Create var.az_count public subnets, each in a different AZ
resource "aws_subnet" "public" {
  count                   = "${var.az_count}"
  cidr_block              = "${cidrsubnet(aws_vpc.main.cidr_block, 8, var.az_count + count.index)}"
  availability_zone       = "${data.aws_availability_zones.available.names[count.index]}"
  vpc_id                  = "${aws_vpc.main.id}"
  map_public_ip_on_launch = true
}


# Create Internet Gatway for the public subnet
resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.main.id}"
}

# Route the public subnet traffic through the IGW
resource "aws_route" "internet_access" {
  route_table_id         = "${aws_vpc.main.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.gw.id}"
}

# Create a NAT gateway with an EIP for each private subnet to get internet connectivity
resource "aws_eip" "gw" {
  count      = "${var.az_count}"
  vpc        = true
  depends_on = ["aws_internet_gateway.gw"]
}

resource "aws_nat_gateway" "gw" {
  count         = "${var.az_count}"
  subnet_id     = "${element(aws_subnet.public.*.id, count.index)}"
  allocation_id = "${element(aws_eip.gw.*.id, count.index)}"
}

# Create a new route table for the private subnets
# And make it route non-local traffic through the NAT gateway to the internet
resource "aws_route_table" "private" {
  count  = "${var.az_count}"
  vpc_id = "${aws_vpc.main.id}"

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = "${element(aws_nat_gateway.gw.*.id, count.index)}"
  }
}

# Explicitely associate the newly created route tables to the private subnets (so they don't default to the main route table)
resource "aws_route_table_association" "private" {
  count          = "${var.az_count}"
  subnet_id      = "${element(aws_subnet.private.*.id, count.index)}"
  route_table_id = "${element(aws_route_table.private.*.id, count.index)}"
}
#IAM
resource "aws_iam_role" "es_role" {
  name = "tf_ecs_execution_role"

  assume_role_policy = <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "es_policy" {
  name = "ecs_execution_policy"
  role = "${aws_iam_role.es_role.name}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:Describe*"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "elasticsearch_profile" {
  name  = "elasticsearch_profile"
  role = "${aws_iam_role.es_role.name}"
}
    


# Security group
# These are the groups to edit if  want to restrict access to applications
resource "aws_security_group" "logstash-sg" {
  name        = "elk-logstash-sg"
  description = "Controls access to the Logstash instances"
  vpc_id      = "${aws_vpc.main.id}"

  ingress = [
    {
      protocol    = "tcp"
      from_port   = 22
      to_port     = 22
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      protocol    = "tcp"
      from_port   = 5042
      to_port     = 5042
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "kibana-sg" {
  name        = "elk-kibana-sg"
  description = "Controls access to the Kibana instances"
  vpc_id      = "${aws_vpc.main.id}"

  ingress = [
    {
      protocol    = "tcp"
      from_port   = 22
      to_port     = 22
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      protocol    = "tcp"
      from_port   = 5601
      to_port     = 5601
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "elasticsearch-sg" {
  name        = "elk-elasticsearch-sg"
  description = "Controls access to the Elasticsearch instances"
  vpc_id      = "${aws_vpc.main.id}"

  ingress = [
    {
      protocol    = "tcp"
      from_port   = 22
      to_port     = 22
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      protocol    = "tcp"
      from_port   = 9200
      to_port     = 9200
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      protocol    = "tcp"
      from_port   = 9300
      to_port     = 9300
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

##Elasticsearch EC2 Cluster##
resource "aws_instance" "elasticsearch_instance" {
  ami           = "${var.aws_es_ami}"
  instance_type = "${var.aws_es_instance_type}"
  security_groups = ["${aws_security_group.elasticsearch-sg.name}"]
  iam_instance_profile = "${aws_iam_instance_profile.elasticsearch_profile.name}"
  user_data = "${file("userdata-es.sh")}"
  count = "3"

  tags {
    Name = "elasticsearch_instance_${count.index}"
  }
}





























### CERTIFICATES ###
#Creating a dummy SSL certificate
resource "tls_private_key" "example" {
  algorithm = "RSA"
}

resource "tls_self_signed_cert" "example" {
  key_algorithm   = "RSA"
  private_key_pem      = "${tls_private_key.example.private_key_pem}"
  subject {
    common_name  = "example.com"
    organization = "Smava Examples, Inc"
  }

  validity_period_hours = 336

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "cert_signing",
  ]
}

resource "aws_iam_server_certificate" "test_cert" {
  name = "terraform-test-cert"
  certificate_body = "${tls_self_signed_cert.example.cert_pem}"
  private_key      = "${tls_private_key.example.private_key_pem}"
}

### LOAD BALANCERS ###

#Creating the front end Application Load Balancer
resource "aws_alb" "main" {
  name            = "tf-ecs-task-alb"
  subnets         = ["${aws_subnet.public.*.id}"]
  security_groups = ["${aws_security_group.lb.id}"]
}

resource "aws_alb_target_group" "web" {
  name        = "tf-ecs-task-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = "${aws_vpc.main.id}"
  target_type = "ip"
}

# Redirect all traffic on ALB to the target group
resource "aws_alb_listener" "http" {
  load_balancer_arn = "${aws_alb.main.id}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_alb_target_group.web.id}"
    type             = "forward"
  }
}

resource "aws_alb_listener" "https" {
  load_balancer_arn = "${aws_alb.main.id}"
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2015-05"
  certificate_arn   = "${aws_iam_server_certificate.test_cert.arn}"


  default_action {
    target_group_arn = "${aws_alb_target_group.web.id}"
    type             = "forward"
  }
}


