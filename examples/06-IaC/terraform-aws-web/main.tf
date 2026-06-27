# Security Group for Web Server
resource "aws_security_group" "web_sg" {
  name        = "web-server-sg-${var.environment}"
  description = "Allow HTTP and SSH inbound traffic"

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH from specific IP (Replace with your IP)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # WARNING: In production, lock this down!
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2 Instance
resource "aws_instance" "web" {
  ami           = var.ami_id
  instance_type = var.instance_type

  # Attach the security group
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  # User Data script to install Apache on boot
  user_data = <<-EOF
              #!/bin/bash
              sudo apt-get update -y
              sudo apt-get install apache2 -y
              sudo systemctl start apache2
              sudo systemctl enable apache2
              echo "<h1>Welcome to God Mode Vault Web Server</h1>" | sudo tee /var/www/html/index.html
              EOF

  tags = {
    Name = "WebServer-${var.environment}"
  }
}
