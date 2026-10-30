# Customer data dip — DynamoDB directory + Lambda lookup.
#
# Design points for review:
# - One GetItem per call. Phone number (E.164) is the key because caller ID is
#   what the flow actually has in its hand at decision time.
# - PAY_PER_REQUEST: bursty reads, asleep otherwise. Provisioned capacity would
#   be paying rent on an empty chair.
# - The function's IAM role can do exactly one useful thing: GetItem on this
#   table. Everything else is CloudWatch Logs so failures are visible.
# - The Connect resource-based permission (aws_lambda_permission) is what lets
#   the flow invoke the function; the association resource in modules/connect
#   registers it with the instance. Both halves are required — a classic
#   two-piece answer, like every hybrid question worth asking.

locals {
  seed_customers = {
    "+16135550101" = {
      customer_name = "Avery Collins"
      account_tier  = "Priority"
      routing_queue = "Priority"
      open_case     = "true"
      case_id       = "CASE-1042"
    }
    "+14165550102" = {
      customer_name = "Jordan Lee"
      account_tier  = "Standard"
      routing_queue = "Billing"
      open_case     = "true"
      case_id       = "CASE-2077"
    }
    "+15145550103" = {
      customer_name = "Sam Tremblay"
      account_tier  = "Standard"
      routing_queue = "General"
      open_case     = "false"
      case_id       = ""
    }
  }
}

resource "aws_dynamodb_table" "customers" {
  name         = "${var.project_name}-${var.environment}-customer-directory"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "phone_number"

  attribute {
    name = "phone_number"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = var.common_tags
}

# Demo callers, seeded as data — the same three people as sample-data/customers.seed.json.
resource "aws_dynamodb_table_item" "seed" {
  for_each   = local.seed_customers
  table_name = aws_dynamodb_table.customers.name
  hash_key   = aws_dynamodb_table.customers.hash_key

  item = jsonencode({
    phone_number  = { S = each.key }
    customer_name = { S = each.value.customer_name }
    account_tier  = { S = each.value.account_tier }
    routing_queue = { S = each.value.routing_queue }
    open_case     = { S = each.value.open_case }
    case_id       = { S = each.value.case_id }
  })
}

data "archive_file" "lookup" {
  type        = "zip"
  source_dir  = "${path.module}/../../../lambda/customer_lookup"
  output_path = "${path.module}/build/customer_lookup.zip"
  excludes    = ["test_event.json", "__pycache__"]
}

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lookup" {
  name               = "${var.project_name}-${var.environment}-connect-lookup"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
  tags               = var.common_tags
}

data "aws_iam_policy_document" "lookup" {
  statement {
    sid       = "ReadOneTable"
    actions   = ["dynamodb:GetItem"]
    resources = [aws_dynamodb_table.customers.arn]
  }
  statement {
    sid = "WriteOwnLogs"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["arn:aws:logs:*:*:log-group:/aws/lambda/${var.project_name}-${var.environment}-customer-lookup*"]
  }
}

resource "aws_iam_role_policy" "lookup" {
  name   = "customer-lookup"
  role   = aws_iam_role.lookup.id
  policy = data.aws_iam_policy_document.lookup.json
}

resource "aws_lambda_function" "lookup" {
  function_name    = "${var.project_name}-${var.environment}-customer-lookup"
  description      = "Amazon Connect data dip: caller ID -> customer record -> routing decision"
  role             = aws_iam_role.lookup.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  timeout          = 8 # Connect's synchronous-invoke ceiling — the budget the flow lives by
  memory_size      = 128
  filename         = data.archive_file.lookup.output_path
  source_code_hash = data.archive_file.lookup.output_base64sha256

  environment {
    variables = {
      CUSTOMER_TABLE = aws_dynamodb_table.customers.name
    }
  }

  tags = var.common_tags
}

# Lets Amazon Connect invoke the function. Scoped to Steven's account; the
# instance association in modules/connect completes the pairing.
resource "aws_lambda_permission" "connect_invoke" {
  statement_id   = "AllowConnectInvoke"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.lookup.function_name
  principal      = "connect.amazonaws.com"
  source_account = var.account_id
}

# If the data dip rots, someone hears about it — the flow keeps routing to the
# General queue, but not silently.
resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-${var.environment}-connect-alerts"
  tags = var.common_tags
}

resource "aws_cloudwatch_metric_alarm" "lookup_errors" {
  alarm_name          = "${var.project_name}-${var.environment}-lookup-errors"
  alarm_description   = "Customer lookup Lambda is erroring — calls are falling back to General Support"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 0

  dimensions = {
    FunctionName = aws_lambda_function.lookup.function_name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  tags          = var.common_tags
}
