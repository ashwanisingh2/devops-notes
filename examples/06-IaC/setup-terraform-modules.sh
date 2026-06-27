#!/bin/bash
# Script to scaffold a modular Terraform setup

MODULE_DIR="C:/Users/SPTL/Documents/devops/devops/examples/06-IaC/terraform-modules"
mkdir -p $MODULE_DIR/modules/web_server

# 1. Create Child Module - Variables
cat << 'EOF' > $MODULE_DIR/modules/web_server/variables.tf
variable "instance_name" {
  description = "Name tag for the EC2 instance"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}
EOF

# 2. Create Child Module - Main
cat << 'EOF' > $MODULE_DIR/modules/web_server/main.tf
resource "aws_instance" "web" {
  ami           = "ami-0c7217cdde317cfec" # Amazon Linux 2 / Ubuntu dummy AMI
  instance_type = var.instance_type
  tags = {
    Name   = var.instance_name
    Module = "True"
  }
}
EOF

# 3. Create Child Module - Outputs
cat << 'EOF' > $MODULE_DIR/modules/web_server/outputs.tf
output "instance_id" {
  description = "The ID of the EC2 instance"
  value       = aws_instance.web.id
}
EOF

# 4. Create Root Module (Caller)
cat << 'EOF' > $MODULE_DIR/main.tf
provider "aws" {
  region = "us-east-1"
}

module "frontend_server" {
  source        = "./modules/web_server"
  instance_name = "prod-frontend"
  instance_type = "t3.medium"
}

output "frontend_instance_id" {
  value = module.frontend_server.instance_id
}
EOF

echo "Terraform module structure created successfully in $MODULE_DIR"
