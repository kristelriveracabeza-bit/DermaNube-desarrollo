resource "aws_dynamodb_table" "personas" {
  name         = "${local.prefijo}Personas"
  billing_mode               = "PAY_PER_REQUEST"
  hash_key                   = "id"
  deletion_protection_enabled = var.ProtegerRecursos

  attribute {
    name = "id"
    type = "S"
  }

  attribute {
    name = "tipo"
    type = "S"
  }

  attribute {
    name = "correo"
    type = "S"
  }

  global_secondary_index {
    name            = "TipoCorreo"
    hash_key        = "tipo"
    range_key       = "correo"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.principal.arn
  }
}

resource "aws_dynamodb_table" "citas" {
  name         = "${local.prefijo}Citas"
  billing_mode               = "PAY_PER_REQUEST"
  hash_key                   = "id"
  deletion_protection_enabled = var.ProtegerRecursos

  attribute {
    name = "id"
    type = "S"
  }

  attribute {
    name = "pacienteId"
    type = "S"
  }

  attribute {
    name = "especialistaId"
    type = "S"
  }

  attribute {
    name = "fechaHora"
    type = "S"
  }

  global_secondary_index {
    name            = "PacienteFecha"
    hash_key        = "pacienteId"
    range_key       = "fechaHora"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "EspecialistaFecha"
    hash_key        = "especialistaId"
    range_key       = "fechaHora"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.principal.arn
  }
}

resource "aws_dynamodb_table" "notificaciones" {
  name         = "${local.prefijo}Notificaciones"
  billing_mode               = "PAY_PER_REQUEST"
  hash_key                   = "id"
  deletion_protection_enabled = var.ProtegerRecursos

  attribute {
    name = "id"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.principal.arn
  }
}

resource "random_password" "redis" {
  length  = 32
  special = false
}

resource "aws_secretsmanager_secret" "redis" {
  count                   = var.CrearCache ? 1 : 0
  name                    = "${local.prefijo}/Redis"
  recovery_window_in_days = 7
  kms_key_id              = aws_kms_key.principal.arn
}

resource "aws_secretsmanager_secret_version" "redis" {
  count         = var.CrearCache ? 1 : 0
  secret_id     = aws_secretsmanager_secret.redis[0].id
  secret_string = random_password.redis.result
}

resource "aws_elasticache_subnet_group" "principal" {
  count      = var.CrearCache ? 1 : 0
  name       = local.nombreMinimo
  subnet_ids = aws_subnet.datos[*].id
}

resource "aws_elasticache_replication_group" "principal" {
  count                      = var.CrearCache ? 1 : 0
  replication_group_id       = substr(local.nombreMinimo, 0, 40)
  description                = "Cache de horarios de DermaNube"
  node_type                  = "cache.t4g.micro"
  port                       = 6379
  parameter_group_name       = "default.redis7"
  engine_version             = "7.1"
  num_cache_clusters         = 2
  automatic_failover_enabled = true
  multi_az_enabled           = true
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token                 = random_password.redis.result
  kms_key_id                 = aws_kms_key.principal.arn
  subnet_group_name          = aws_elasticache_subnet_group.principal[0].name
  security_group_ids         = [aws_security_group.datos.id]
  apply_immediately          = true
}

resource "aws_cloudwatch_log_group" "opensearchAplicacion" {
  count             = var.CrearBusqueda ? 1 : 0
  name              = "/aws/opensearch/${local.prefijo}/Aplicacion"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.principal.arn
}

resource "aws_cloudwatch_log_group" "opensearchAuditoria" {
  count             = var.CrearBusqueda ? 1 : 0
  name              = "/aws/opensearch/${local.prefijo}/Auditoria"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.principal.arn
}

data "aws_iam_policy_document" "opensearchLogs" {
  count = var.CrearBusqueda ? 1 : 0

  statement {
    effect = "Allow"
    actions = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = [
      "${aws_cloudwatch_log_group.opensearchAplicacion[0].arn}:*",
      "${aws_cloudwatch_log_group.opensearchAuditoria[0].arn}:*"
    ]

    principals {
      type        = "Service"
      identifiers = ["es.amazonaws.com"]
    }
  }
}

resource "aws_cloudwatch_log_resource_policy" "opensearch" {
  count       = var.CrearBusqueda ? 1 : 0
  policy_name = "${local.prefijo}OpenSearch"
  policy_document = data.aws_iam_policy_document.opensearchLogs[0].json
}

resource "aws_opensearch_domain" "principal" {
  count          = var.CrearBusqueda ? 1 : 0
  domain_name    = substr(local.nombreMinimo, 0, 28)
  engine_version = "OpenSearch_2.17"

  cluster_config {
    instance_type          = "t3.small.search"
    instance_count         = 2
    zone_awareness_enabled = true

    zone_awareness_config {
      availability_zone_count = 2
    }
  }

  ebs_options {
    ebs_enabled = true
    volume_type = "gp3"
    volume_size = 20
  }

  encrypt_at_rest {
    enabled    = true
    kms_key_id = aws_kms_key.principal.arn
  }

  node_to_node_encryption {
    enabled = true
  }

  advanced_security_options {
    enabled                        = true
    internal_user_database_enabled = false

    master_user_options {
      master_user_arn = aws_iam_role.tareaPersonas.arn
    }
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearchAplicacion[0].arn
    log_type                 = "ES_APPLICATION_LOGS"
    enabled                  = true
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearchAuditoria[0].arn
    log_type                 = "AUDIT_LOGS"
    enabled                  = true
  }

  domain_endpoint_options {
    enforce_https       = true
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  }

  vpc_options {
    subnet_ids         = aws_subnet.datos[*].id
    security_group_ids = [aws_security_group.datos.id]
  }

  access_policies = data.aws_iam_policy_document.opensearch.json

  depends_on = [aws_cloudwatch_log_resource_policy.opensearch]
}
