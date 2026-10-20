resource "aws_instance" "web" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.web.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2.name
  associate_public_ip_address = true

  user_data = <<-EOF
    #!/bin/bash
    set -euxo pipefail

    dnf install -y nginx
    systemctl enable --now nginx

    cat > /usr/share/nginx/html/index.html <<'HTML'
    <!DOCTYPE html>
    <html lang="en">
    <head><meta charset="UTF-8"><title>AI Cloud Operations Center</title></head>
    <body>
      <h1>AI Cloud Operations Center</h1>
      <p>Nginx is running on the project EC2 instance.</p>
    </body>
    </html>
    HTML
  EOF

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name      = "${local.name_prefix}-web"
    Component = "web-server"
  }

  depends_on = [
    aws_iam_role_policy_attachment.ssm_managed_instance
  ]
}
