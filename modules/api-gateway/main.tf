locals {
  api_name = "ridelines-api-${var.environment}"
}

# Process the OpenAPI spec with template variable substitutions
locals {
  # Use templatefile to substitute all variables at once
  openapi_spec_substituted = templatefile(var.openapi_spec_path, {
    auth_lambda_arn             = var.auth_lambda_arn
    user_lambda_arn             = var.user_lambda_arn
    auth_verify_lambda_arn      = var.auth_verify_lambda_arn
    auth_verify_lambda_role_arn = var.auth_verify_lambda_role_arn
    domain_name                 = var.domain_name
    frontend_origin             = var.frontend_origin
  })

  # Parse the final OpenAPI spec
  updated_spec = yamldecode(local.openapi_spec_substituted)
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# ACM Certificate for API Gateway (regional)
resource "aws_acm_certificate" "api_certificate" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  tags = {
    Environment = var.environment
    Project     = "ridelines"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Certificate validation
resource "aws_acm_certificate_validation" "api_certificate_validation" {
  certificate_arn         = aws_acm_certificate.api_certificate.arn
  validation_record_fqdns = [for record in aws_route53_record.api_certificate_validation : record.fqdn]
}

# Route53 records for certificate validation
resource "aws_route53_record" "api_certificate_validation" {
  for_each = {
    for dvo in aws_acm_certificate.api_certificate.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.route53_zone_id
}

# Create the REST API Gateway using OpenAPI specification
resource "aws_api_gateway_rest_api" "api" {
  name        = local.api_name
  description = "Ridelines API - ${var.environment} environment"

  body = jsonencode(local.updated_spec)

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = {
    Environment = var.environment
    Project     = "ridelines"
  }
}

# JWT Authorizer is configured in the OpenAPI spec using x-amazon-apigateway-authorizer
# No separate Terraform resource needed - API Gateway creates it from the spec

# Lambda permissions for API Gateway to invoke functions
resource "aws_lambda_permission" "auth_lambda_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.auth_lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "user_lambda_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.user_lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

# Create /openapi.yaml endpoint
resource "aws_api_gateway_resource" "openapi" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "openapi.yaml"
}

resource "aws_api_gateway_method" "openapi_get" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.openapi.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "openapi_200" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.openapi.id
  http_method = aws_api_gateway_method.openapi_get.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Content-Type" = true
  }
}

resource "aws_api_gateway_integration" "openapi" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.openapi.id
  http_method = aws_api_gateway_method.openapi_get.http_method
  type        = "MOCK"
}

resource "aws_api_gateway_integration_response" "openapi_200" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.openapi.id
  http_method = aws_api_gateway_method.openapi_get.http_method
  status_code = aws_api_gateway_method_response.openapi_200.status_code

  response_parameters = {
    "method.response.header.Content-Type" = "'application/x-yaml'"
  }

  response_templates = {
    "application/x-yaml" = file(var.openapi_spec_path)
  }

  depends_on = [aws_api_gateway_integration.openapi]
}

# API Gateway deployment
resource "aws_api_gateway_deployment" "api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.api.id

  triggers = {
    redeployment = sha1(jsonencode([
      local.updated_spec,
      aws_api_gateway_integration_response.openapi_200.response_templates
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration_response.openapi_200
  ]
}

# API Gateway stage
resource "aws_api_gateway_stage" "api_stage" {
  stage_name    = "v1"
  rest_api_id   = aws_api_gateway_rest_api.api.id
  deployment_id = aws_api_gateway_deployment.api_deployment.id

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway_logs.arn
    format = jsonencode({
      requestId        = "$context.requestId"
      ip               = "$context.identity.sourceIp"
      caller           = "$context.identity.caller"
      user             = "$context.identity.user"
      requestTime      = "$context.requestTime"
      httpMethod       = "$context.httpMethod"
      resourcePath     = "$context.resourcePath"
      status           = "$context.status"
      protocol         = "$context.protocol"
      responseLength   = "$context.responseLength"
      error            = "$context.error.message"
      integrationError = "$context.integration.error"
    })
  }

  depends_on = [aws_api_gateway_account.api_gateway_account]

  tags = {
    Environment = var.environment
    Project     = "ridelines"
  }
}

# IAM role for API Gateway CloudWatch Logs
resource "aws_iam_role" "api_gateway_cloudwatch_role" {
  name = "api-gateway-cloudwatch-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Environment = var.environment
    Project     = "ridelines"
  }
}

# Attach the managed policy for CloudWatch Logs
resource "aws_iam_role_policy_attachment" "api_gateway_cloudwatch_policy" {
  role       = aws_iam_role.api_gateway_cloudwatch_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

# Set the CloudWatch Logs role ARN in API Gateway account settings
resource "aws_api_gateway_account" "api_gateway_account" {
  cloudwatch_role_arn = aws_iam_role.api_gateway_cloudwatch_role.arn

  depends_on = [aws_iam_role_policy_attachment.api_gateway_cloudwatch_policy]
}

# CloudWatch log group for API Gateway
resource "aws_cloudwatch_log_group" "api_gateway_logs" {
  name              = "/aws/apigateway/${local.api_name}"
  retention_in_days = 30

  tags = {
    Environment = var.environment
    Project     = "ridelines"
  }
}

# Custom domain name
resource "aws_api_gateway_domain_name" "api_domain" {
  domain_name              = var.domain_name
  regional_certificate_arn = aws_acm_certificate.api_certificate.arn

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = {
    Environment = var.environment
    Project     = "ridelines"
  }
}

# Base path mapping
resource "aws_api_gateway_base_path_mapping" "api_mapping" {
  api_id      = aws_api_gateway_rest_api.api.id
  stage_name  = aws_api_gateway_stage.api_stage.stage_name
  domain_name = aws_api_gateway_domain_name.api_domain.domain_name
}

# Route53 record for the API domain
resource "aws_route53_record" "api_domain_record" {
  zone_id = var.route53_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_api_gateway_domain_name.api_domain.regional_domain_name
    zone_id                = aws_api_gateway_domain_name.api_domain.regional_zone_id
    evaluate_target_health = false
  }
}