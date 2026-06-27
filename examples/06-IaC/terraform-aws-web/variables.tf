variable "aws_region" {
  description = "The AWS region to deploy infrastructure"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "The environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "instance_type" {
  description = "The EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "ami_id" {
  description = "The AMI ID for the EC2 instance (Ubuntu 22.04 LTS by default)"
  type        = string
  default     = "ami-0c7217cdde317cfec"
}
