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

    dnf install -y nginx curl
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

    curl -fsSL \
      https://amazoncloudwatch-agent.s3.amazonaws.com/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm \
      -o /tmp/amazon-cloudwatch-agent.rpm

    dnf install -y /tmp/amazon-cloudwatch-agent.rpm

    cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<'CWCONFIG'
    {
      "agent": {
        "metrics_collection_interval": 60,
        "run_as_user": "root"
      },
      "metrics": {
        "namespace": "CWAgent",
        "append_dimensions": {
          "InstanceId": "$${aws:InstanceId}"
        },
        "metrics_collected": {
          "procstat": [
            {
              "exe": "nginx",
              "measurement": ["pid_count"],
              "metrics_collection_interval": 60
            }
          ]
        }
      },
      "logs": {
        "logs_collected": {
          "files": {
            "collect_list": [
              {
                "file_path": "/var/log/nginx/access.log",
                "log_group_name": "/ai-cloud-operations-center/nginx/access",
                "log_stream_name": "{instance_id}"
              },
              {
                "file_path": "/var/log/nginx/error.log",
                "log_group_name": "/ai-cloud-operations-center/nginx/error",
                "log_stream_name": "{instance_id}"
              }
            ]
          }
        }
      }
    }
    CWCONFIG

    /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
      -a fetch-config -m ec2 \
      -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s
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
    aws_iam_role_policy_attachment.ssm_managed_instance,
    aws_iam_role_policy_attachment.cloudwatch_agent
  ]
}
