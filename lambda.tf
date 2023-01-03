data "external" "build" {
	program = ["bash", "-c", <<EOT
(make node_modules) >&2 && echo "{\"dest\": \".\"}"
EOT
	]
	working_dir = "${path.module}/lambda"
}

data "archive_file" "lambda_zip" {
	type        = "zip"
	output_path = "/tmp/lambda-${random_id.id.hex}.zip"
	source_dir  = "${data.external.build.working_dir}/${data.external.build.result.dest}"
}

resource "aws_lambda_function" "lambda" {
  function_name = "${random_id.id.hex}-lambda"

	filename         = data.archive_file.lambda_zip.output_path
	source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  handler = "index.handler"
  runtime = "nodejs18.x"
  role    = aws_iam_role.lambda_exec.arn
	reserved_concurrent_executions = 1
	environment {
		variables = {
			THING_NAME = aws_iot_thing.thing.name
			IOT_ENDPOINT = data.aws_iot_endpoint.iot_endpoint.endpoint_address
			CA = data.http.root_ca.response_body
			CERT = tls_self_signed_cert.cert.cert_pem
			KEY = tls_private_key.key.private_key_pem
		}
	}
}

resource "aws_cloudwatch_log_group" "loggroup" {
  name              = "/aws/lambda/${aws_lambda_function.lambda.function_name}"
  retention_in_days = 14
}

data "aws_iam_policy_document" "lambda_exec_role_policy" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "arn:aws:logs:*:*:*"
    ]
  }
}

resource "aws_iam_role_policy" "lambda_exec_role" {
  role   = aws_iam_role.lambda_exec.id
  policy = data.aws_iam_policy_document.lambda_exec_role_policy.json
}

resource "aws_iam_role" "lambda_exec" {
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_cloudwatch_event_rule" "scheduler" {
  schedule_expression = "rate(1 minute)"
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule = aws_cloudwatch_event_rule.scheduler.name
  arn  = aws_lambda_function.lambda.arn
}

resource "aws_lambda_permission" "scheduler" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.arn
  principal     = "events.amazonaws.com"

  source_arn = aws_cloudwatch_event_rule.scheduler.arn
}
