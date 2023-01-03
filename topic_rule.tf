resource "aws_dynamodb_table" "connection-events" {
  name         = "iot-connection-events-${random_id.id.hex}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "timestamp"

  attribute {
    name = "timestamp"
    type = "N"
  }
}

data "aws_iam_policy_document" "topic_rule" {
  statement {
    actions = [
      "dynamodb:PutItem",
    ]
    resources = [
			aws_dynamodb_table.connection-events.arn
    ]
  }
}

resource "aws_iam_role_policy" "topic_rule" {
  role   = aws_iam_role.topic_rule.id
  policy = data.aws_iam_policy_document.topic_rule.json
}

resource "aws_iam_role" "topic_rule" {
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "iot.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iot_topic_rule" "rule" {
  name        = "test_${random_id.id.hex}"
  enabled     = true
  sql         = "SELECT * as event, timestamp, version, topic(4) as eventType, topic(5) as clientId FROM '$aws/events/presence/+/+' WHERE topic(4) = 'connected' or topic(4) = 'disconnected'"
  sql_version = "2016-03-23"

	dynamodbv2 {
		put_item {
			table_name = aws_dynamodb_table.connection-events.name
		}
		role_arn = aws_iam_role.topic_rule.arn
	}
}

