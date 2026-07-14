resource "aws_cognito_user_pool" "pacientes" {
  name                     = "${local.prefijo}Pacientes"
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]
  mfa_configuration        = "OPTIONAL"

  software_token_mfa_configuration {
    enabled = true
  }

  password_policy {
    minimum_length                   = 10
    require_lowercase                = true
    require_numbers                  = true
    require_symbols                  = true
    require_uppercase                = true
    temporary_password_validity_days = 3
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  user_attribute_update_settings {
    attributes_require_verification_before_update = ["email"]
  }
}

resource "aws_cognito_user_pool_client" "web" {
  name                                 = "${local.prefijo}Web"
  user_pool_id                         = aws_cognito_user_pool.pacientes.id
  generate_secret                      = false
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["openid", "email", "profile"]
  supported_identity_providers         = ["COGNITO"]
  callback_urls                        = [local.dominioHabilitado ? "https://${var.Dominio}" : "https://${aws_cloudfront_distribution.frontend.domain_name}", "http://localhost:8080"]
  logout_urls                          = [local.dominioHabilitado ? "https://${var.Dominio}" : "https://${aws_cloudfront_distribution.frontend.domain_name}", "http://localhost:8080"]
  prevent_user_existence_errors        = "ENABLED"
  enable_token_revocation              = true
  access_token_validity                = 60
  id_token_validity                    = 60
  refresh_token_validity               = 30

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }
}

resource "aws_cognito_user_pool_domain" "web" {
  domain       = local.dominioCognito
  user_pool_id = aws_cognito_user_pool.pacientes.id
}

resource "aws_apigatewayv2_api" "principal" {
  name          = "${local.prefijo}Api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_credentials = false
    allow_headers     = ["Authorization", "Content-Type", "XClaveInicializacion"]
    allow_methods     = ["GET", "POST", "PATCH", "OPTIONS"]
    allow_origins     = local.dominioHabilitado ? ["https://${var.Dominio}"] : ["*"]
    max_age           = 3600
  }
}

resource "aws_apigatewayv2_vpc_link" "principal" {
  name               = "${local.prefijo}Vinculo"
  security_group_ids = [aws_security_group.vinculoApi.id]
  subnet_ids         = aws_subnet.privadas[*].id
}

resource "aws_apigatewayv2_integration" "balanceador" {
  api_id                 = aws_apigatewayv2_api.principal.id
  integration_type       = "HTTP_PROXY"
  integration_method     = "ANY"
  integration_uri        = aws_lb_listener.http.arn
  connection_type        = "VPC_LINK"
  connection_id          = aws_apigatewayv2_vpc_link.principal.id
  payload_format_version = "1.0"
  timeout_milliseconds   = 29000
  request_parameters = {
    "overwrite:path" = "$request.path"
  }
}

resource "aws_apigatewayv2_authorizer" "cognito" {
  api_id           = aws_apigatewayv2_api.principal.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "${local.prefijo}Cognito"

  jwt_configuration {
    audience = [aws_cognito_user_pool_client.web.id]
    issuer   = "https://cognito-idp.${var.RegionAws}.amazonaws.com/${aws_cognito_user_pool.pacientes.id}"
  }
}

resource "aws_apigatewayv2_route" "personasRaiz" {
  api_id             = aws_apigatewayv2_api.principal.id
  route_key          = "ANY /personas"
  target             = "integrations/${aws_apigatewayv2_integration.balanceador.id}"
  authorization_type = var.ProtegerApi ? "JWT" : "NONE"
  authorizer_id      = var.ProtegerApi ? aws_apigatewayv2_authorizer.cognito.id : null
}

resource "aws_apigatewayv2_route" "personas" {
  api_id             = aws_apigatewayv2_api.principal.id
  route_key          = "ANY /personas/{proxy+}"
  target             = "integrations/${aws_apigatewayv2_integration.balanceador.id}"
  authorization_type = var.ProtegerApi ? "JWT" : "NONE"
  authorizer_id      = var.ProtegerApi ? aws_apigatewayv2_authorizer.cognito.id : null
}

resource "aws_apigatewayv2_route" "citasRaiz" {
  api_id             = aws_apigatewayv2_api.principal.id
  route_key          = "ANY /citas"
  target             = "integrations/${aws_apigatewayv2_integration.balanceador.id}"
  authorization_type = var.ProtegerApi ? "JWT" : "NONE"
  authorizer_id      = var.ProtegerApi ? aws_apigatewayv2_authorizer.cognito.id : null
}

resource "aws_apigatewayv2_route" "citas" {
  api_id             = aws_apigatewayv2_api.principal.id
  route_key          = "ANY /citas/{proxy+}"
  target             = "integrations/${aws_apigatewayv2_integration.balanceador.id}"
  authorization_type = var.ProtegerApi ? "JWT" : "NONE"
  authorizer_id      = var.ProtegerApi ? aws_apigatewayv2_authorizer.cognito.id : null
}

resource "aws_cloudwatch_log_group" "api" {
  name              = "/aws/apigateway/${local.prefijo}"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.principal.arn
}

resource "aws_apigatewayv2_stage" "principal" {
  api_id      = aws_apigatewayv2_api.principal.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      responseLength = "$context.responseLength"
      integrationError = "$context.integrationErrorMessage"
    })
  }

  default_route_settings {
    throttling_burst_limit = 500
    throttling_rate_limit  = 1000
  }
}

resource "aws_apigatewayv2_route" "especialistasPublicos" {
  api_id             = aws_apigatewayv2_api.principal.id
  route_key          = "GET /personas/especialistas"
  target             = "integrations/${aws_apigatewayv2_integration.balanceador.id}"
  authorization_type = "NONE"
}

resource "aws_apigatewayv2_route" "especialistaPublico" {
  api_id             = aws_apigatewayv2_api.principal.id
  route_key          = "GET /personas/especialistas/{id}"
  target             = "integrations/${aws_apigatewayv2_integration.balanceador.id}"
  authorization_type = "NONE"
}

resource "aws_apigatewayv2_route" "horariosPublicos" {
  api_id             = aws_apigatewayv2_api.principal.id
  route_key          = "GET /citas/horarios"
  target             = "integrations/${aws_apigatewayv2_integration.balanceador.id}"
  authorization_type = "NONE"
}

resource "aws_apigatewayv2_route" "saludPersonas" {
  api_id             = aws_apigatewayv2_api.principal.id
  route_key          = "GET /personas/salud"
  target             = "integrations/${aws_apigatewayv2_integration.balanceador.id}"
  authorization_type = "NONE"
}

resource "aws_apigatewayv2_route" "saludCitas" {
  api_id             = aws_apigatewayv2_api.principal.id
  route_key          = "GET /citas/salud"
  target             = "integrations/${aws_apigatewayv2_integration.balanceador.id}"
  authorization_type = "NONE"
}

resource "aws_apigatewayv2_route" "inicializacionControlada" {
  api_id             = aws_apigatewayv2_api.principal.id
  route_key          = "POST /personas/inicializar"
  target             = "integrations/${aws_apigatewayv2_integration.balanceador.id}"
  authorization_type = "NONE"
}
