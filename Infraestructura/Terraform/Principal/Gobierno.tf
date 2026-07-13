resource "aws_s3_bucket" "auditoria" {
  bucket        = lower("${local.nombreMinimo}-auditoria-${substr(data.aws_caller_identity.actual.account_id, 8, 4)}")
  force_destroy = !var.ProtegerRecursos
}

resource "aws_s3_bucket_versioning" "auditoria" {
  bucket = aws_s3_bucket.auditoria.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "auditoria" {
  bucket = aws_s3_bucket.auditoria.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "auditoria" {
  bucket                  = aws_s3_bucket.auditoria.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "auditoria" {
  statement {
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.auditoria.arn]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
  }

  statement {
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.auditoria.arn}/AWSLogs/${data.aws_caller_identity.actual.account_id}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
}

resource "aws_s3_bucket_policy" "auditoria" {
  bucket = aws_s3_bucket.auditoria.id
  policy = data.aws_iam_policy_document.auditoria.json
}

resource "aws_cloudwatch_log_group" "cloudtrail" {
  name              = "/aws/cloudtrail/${local.prefijo}"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.principal.arn
}

resource "aws_iam_role" "cloudtrail" {
  name = "${local.prefijo}CloudTrailLogs"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "cloudtrail.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "cloudtrail" {
  role = aws_iam_role.cloudtrail.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["logs:CreateLogStream", "logs:PutLogEvents"]
      Resource = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
    }]
  })
}

resource "aws_sns_topic" "auditoria" {
  name              = "${local.prefijo}Auditoria"
  kms_master_key_id = "alias/aws/sns"
}

resource "aws_cloudtrail" "principal" {
  name                          = "${local.prefijo}CloudTrail"
  s3_bucket_name                = aws_s3_bucket.auditoria.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  kms_key_id                    = aws_kms_key.principal.arn
  cloud_watch_logs_group_arn    = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
  cloud_watch_logs_role_arn     = aws_iam_role.cloudtrail.arn
  sns_topic_name                = aws_sns_topic.auditoria.name

  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type   = "AWS::DynamoDB::Table"
      values = [aws_dynamodb_table.personas.arn, aws_dynamodb_table.citas.arn]
    }

    data_resource {
      type   = "AWS::S3::Object"
      values = ["${aws_s3_bucket.documentos.arn}/"]
    }
  }

  depends_on = [aws_s3_bucket_policy.auditoria]
}

resource "aws_secretsmanager_secret" "aplicacion" {
  name                    = "${local.prefijo}/Aplicacion"
  recovery_window_in_days = 7
  kms_key_id              = aws_kms_key.principal.arn
}

resource "aws_secretsmanager_secret_version" "aplicacion" {
  secret_id = aws_secretsmanager_secret.aplicacion.id
  secret_string = jsonencode({
    claveInicializacion = random_password.inicializacion.result
  })
}

resource "aws_backup_vault" "principal" {
  name        = "${local.prefijo}Backup"
  kms_key_arn = aws_kms_key.principal.arn
}

resource "aws_iam_role" "backup" {
  name = "${local.prefijo}Backup"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "backup.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "backup" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:${data.aws_partition.actual.partition}:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_backup_plan" "principal" {
  name = "${local.prefijo}PlanBackup"

  rule {
    rule_name         = "RespaldoDiario"
    target_vault_name = aws_backup_vault.principal.name
    schedule          = "cron(0 5 * * ? *)"
    start_window      = 60
    completion_window = 180

    lifecycle {
      delete_after = 35
    }
  }
}

resource "aws_backup_selection" "principal" {
  name         = "${local.prefijo}Seleccion"
  iam_role_arn = aws_iam_role.backup.arn
  plan_id      = aws_backup_plan.principal.id
  resources = [
    aws_dynamodb_table.personas.arn,
    aws_dynamodb_table.citas.arn,
    aws_dynamodb_table.notificaciones.arn
  ]
}

resource "aws_budgets_budget" "mensual" {
  count        = var.CorreoPresupuesto != "" ? 1 : 0
  name         = "${local.prefijo}Presupuesto"
  budget_type  = "COST"
  limit_amount = tostring(var.LimitePresupuestoUsd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.CorreoPresupuesto]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.CorreoPresupuesto]
  }
}

resource "aws_cloudwatch_metric_alarm" "colaMuertaNotificaciones" {
  alarm_name          = "${local.prefijo}MensajesMuertosNotificaciones"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Maximum"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = aws_sqs_queue.notificacionesMuerta.name
  }
}

resource "aws_cloudwatch_metric_alarm" "colaMuertaDocumentos" {
  alarm_name          = "${local.prefijo}MensajesMuertosDocumentos"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Maximum"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = aws_sqs_queue.documentosMuerta.name
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "auditoria" {
  bucket = aws_s3_bucket.auditoria.id

  rule {
    id     = "ArchivarAuditoria"
    status = "Enabled"

    filter {}

    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 180
      storage_class = "GLACIER"
    }

    expiration {
      days = 2555
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}
