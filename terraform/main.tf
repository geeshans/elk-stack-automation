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
resource "aws_iam_role" "ec2_role" {
  name = "tf_ec2_execution_role"

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

resource "aws_iam_role_policy" "ec2_policy" {
  name = "ec2_execution_policy"
  role = "${aws_iam_role.ec2_role.name}"

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

resource "aws_iam_instance_profile" "ec2_profile" {
  name  = "ec2_profile"
  role = "${aws_iam_role.ec2_role.name}"
}
    


# Security group
# These are the groups to edit if  want to restrict access to applications
resource "aws_security_group" "logstash-sg" {
  name        = "logstash-sg"
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
  name        = "kibana-sg"
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
  name        = "elasticsearch-sg"
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
  key_name = "${var.keypair_name}"
  vpc_security_group_ids = ["${aws_security_group.elasticsearch-sg.id}"]
  iam_instance_profile = "${aws_iam_instance_profile.ec2_profile.name}"
  user_data = "${file("userdata-es.sh")}"
  count = "3"
  subnet_id = "${element(aws_subnet.public.*.id, count.index)}"
  tags {
    Name = "elasticsearch_instance_${count.index}"
  }
}

##Logstash EC2 Instance##
resource "aws_instance" "logstash_instance" {
  ami           = "${var.aws_logstash_ami}"
  instance_type = "${var.aws_logstash_instance_type}"
  key_name = "${var.keypair_name}"
  vpc_security_group_ids = ["${aws_security_group.logstash-sg.id}"]
  iam_instance_profile = "${aws_iam_instance_profile.ec2_profile.name}"
  count = "1"
  subnet_id = "${element(aws_subnet.public.*.id, count.index)}"
  tags {
    Name = "logstash_instance_${count.index}"
  }
  user_data = "${data.template_file.es-ips.rendered}"


}

data "template_file" "es-ips" {
  template = "${file("./userdata-logstash.sh")}"
  vars {
    es_cluster_ip0 = "${element(aws_instance.elasticsearch_instance.*.private_ip, 0)}"
    es_cluster_ip1 = "${element(aws_instance.elasticsearch_instance.*.private_ip, 1)}"
    es_cluster_ip2 = "${element(aws_instance.elasticsearch_instance.*.private_ip, 2)}"

 
  }
}


##Kibana EC2 Instance##
resource "aws_instance" "kibana_instance" {
  ami           = "${var.aws_kibana_ami}"
  instance_type = "${var.aws_kibana_instance_type}"
  key_name = "${var.keypair_name}"
  vpc_security_group_ids = ["${aws_security_group.kibana-sg.id}"]
  iam_instance_profile = "${aws_iam_instance_profile.ec2_profile.name}"
  count = "1"
  subnet_id = "${element(aws_subnet.public.*.id, count.index)}"
  tags {
    Name = "logstash_instance_${count.index}"
  }
  user_data = "${data.template_file.test.rendered}"

}


