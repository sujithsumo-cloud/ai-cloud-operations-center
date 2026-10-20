data "aws_caller_identity" "current" {}

resource "aws_cloudwatch_log_group" "nginx_access" {
  name              = "/ai-cloud-operations-center/nginx/access"
  retention_in_days = 14
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "nginx_error" {
  name              = "/ai-cloud-operations-center/nginx/error"
  retention_in_days = 14
  tags              = local.common_tags
}

resource "aws_sns_topic" "alarm" {
  name = "${local.name_prefix}-alarm-trigger"
  tags = local.common_tags
}

resource "aws_sns_topic_policy" "alarm" {
  arn = aws_sns_topic.alarm.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowCloudWatchAlarmPublish"
      Effect = "Allow"
      Principal = {
        Service = "cloudwatch.amazonaws.com"
      }
      Action   = "sns:Publish"
      Resource = aws_sns_topic.alarm.arn
      Condition = {
        StringEquals = {
          "AWS:SourceAccount" = data.aws_caller_identity.current.account_id
        }
      }
    }]
  })
}

resource "aws_cloudwatch_metric_alarm" "nginx_process" {
  alarm_name          = "${local.name_prefix}-nginx-process-down"
  alarm_description   = "Nginx process count is zero on the web instance."
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  datapoints_to_alarm = 2
  metric_name         = "procstat_lookup_pid_count"
  namespace           = "CWAgent"
  period              = 60
  statistic           = "Minimum"
  threshold           = 1
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = aws_instance.web.id
    exe        = "nginx"
  }

  alarm_actions = [aws_sns_topic.alarm.arn]

  depends_on = [
    aws_cloudwatch_log_group.nginx_access,
    aws_cloudwatch_log_group.nginx_error,
    aws_sns_topic_policy.alarm
  ]

  tags = local.common_tags
}
