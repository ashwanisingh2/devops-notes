output "web_instance_id" {
  description = "The ID of the EC2 instance"
  value       = aws_instance.web.id
}

output "web_public_ip" {
  description = "The public IP address of the web server"
  value       = aws_instance.web.public_ip
}

output "web_public_dns" {
  description = "The public DNS of the web server"
  value       = aws_instance.web.public_dns
}

output "website_url" {
  description = "The URL to access the deployed website"
  value       = "http://${aws_instance.web.public_ip}"
}
