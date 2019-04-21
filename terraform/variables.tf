variable "aws_es_ami" {
  description = "AMI created by Packer for ES"
  default     = "ami-01047da08bb44f2f1"
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

