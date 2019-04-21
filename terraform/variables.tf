variable "aws_es_ami" {
  description = "AMI created by Packer for ES"
  default     = "ami-0f7fadd03214a5118"
}

variable "aws_es_instance_type" {
  description = "Instance size for the elasticsearch"
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