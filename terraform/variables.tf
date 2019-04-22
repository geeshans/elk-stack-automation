variable "aws_es_ami" {
  description = "AMI created by Packer for ES"
  default     = "ami-09e9f677328d27613"
}

variable "aws_es_instance_type" {
  description = "Instance size for the elasticsearch"
  default     = "t2.large"
}

variable "aws_logstash_ami" {
  description = "AMI created by Packer for Logstash"
  default     = "ami-08e4e84d43de34ced"
}

variable "aws_logstash_instance_type" {
  description = "Instance size for the logstash"
  default     = "t2.large"
}

variable "aws_kibana_ami" {
  description = "AMI created by Packer for Kibana"
  default     = "ami-009a49474236bc42a"
}

variable "aws_kibana_instance_type" {
  description = "Instance size for the Kibana"
  default     = "t2.large"
}

variable "aws_region" {
  description = "The AWS region to create things in."
  default     = "us-east-1"
}


variable "az_count" {
  description = "Number of AZs to cover in a given AWS region"
  default     = "2"
}

variable "keypair_name" {
  description = "Name of the keypair to access ec2 instances"
  default     = "terraform"
}