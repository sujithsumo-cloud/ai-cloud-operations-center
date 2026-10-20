resource "aws_iam_role" "lambda_remediation" {
  name = "${local.name_prefix}-lambda-remediation-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_remediation.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_remediation" {
  name = "${local.name_prefix}-remediation-policy"
  role = aws_iam_role.lambda_remediation.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["ssm:SendCommand"]
        Resource = [
          "arn:aws:ssm:${var.aws_region}::document/AWS-RunShellScript",
          "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:instance/${aws_instance.web.id}"
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["ssm:GetCommandInvocation"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = aws_sns_topic.alarm.arn
      }
    ]
  })
}

data "archive_file" "lambda_remediation" {
  type        = "zip"
  source_file = "${path.module}/../lambda/handler.py"
  output_path = "${path.module}/remediation-lambda.zip"
}

resource "aws_lambda_function" "remediation" {
  function_name    = "${local.name_prefix}-remediation"
  role             = aws_iam_role.lambda_remediation.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.lambda_remediation.output_path
  source_code_hash = data.archive_file.lambda_remediation.output_base64sha256
  timeout          = 120
  memory_size      = 128

  environment {
    variables = {
      INSTANCE_ID   = aws_instance.web.id
      SNS_TOPIC_ARN = aws_sns_topic.alarm.arn
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs,
    aws_iam_role_policy.lambda_remediation
  ]

  tags = local.common_tags
}

resource "aws_lambda_permission" "allow_sns" {
  statement_id  = "AllowInvocationFromAlarmTopic"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.remediation.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.alarm.arn
}

resource "aws_sns_topic_subscription" "lambda_remediation" {
  topic_arn = aws_sns_topic.alarm.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.remediation.arn

  depends_on = [aws_lambda_permission.allow_sns]
}
