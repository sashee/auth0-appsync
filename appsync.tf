resource "aws_appsync_graphql_api" "appsync" {
  name                = "appsync_test"
  schema              = file("schema.graphql")
  authentication_type = "OPENID_CONNECT"
  openid_connect_config {
    issuer = "https://${var.auth0_domain}"
  }
  log_config {
    cloudwatch_logs_role_arn = aws_iam_role.appsync_logs.arn
    field_log_level          = "ALL"
  }
}

data "aws_iam_policy_document" "appsync_push_logs" {
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

resource "aws_iam_role" "appsync_logs" {
  assume_role_policy = <<POLICY
{
	"Version": "2012-10-17",
	"Statement": [
		{
		"Effect": "Allow",
		"Principal": {
			"Service": "appsync.amazonaws.com"
		},
		"Action": "sts:AssumeRole"
		}
	]
}
POLICY
}

resource "aws_iam_role_policy" "appsync_logs" {
  role   = aws_iam_role.appsync_logs.id
  policy = data.aws_iam_policy_document.appsync_push_logs.json
}

resource "aws_cloudwatch_log_group" "loggroup" {
  name              = "/aws/appsync/apis/${aws_appsync_graphql_api.appsync.id}"
  retention_in_days = 14
}

resource "aws_appsync_datasource" "none" {
  api_id           = aws_appsync_graphql_api.appsync.id
  name             = "none"
  type             = "NONE"
}

resource "aws_appsync_resolver" "Query_user" {
  api_id      = aws_appsync_graphql_api.appsync.id
  data_source = aws_appsync_datasource.none.name
  type        = "Query"
  field       = "user"

  request_template = <<EOF
{
	"version" : "2018-05-29",
	"payload": $util.toJson($ctx.identity)
}
EOF
  response_template = <<EOF
$util.toJson($util.toJson($ctx.result))
EOF
}
