resource "aws_sns_topic" "eventos" {
  name                        = "${local.prefijo}Eventos.fifo"
  fifo_topic                  = true
  content_based_deduplication = true
  kms_master_key_id           = aws_kms_key.principal.arn
}

resource "aws_sqs_queue" "notificacionesMuerta" {
  name                        = "${local.prefijo}NotificacionesMuerta.fifo"
  fifo_queue                  = true
  content_based_deduplication = true
  kms_master_key_id           = aws_kms_key.principal.arn
  message_retention_seconds   = 1209600
}

resource "aws_sqs_queue" "notificaciones" {
  name                        = "${local.prefijo}Notificaciones.fifo"
  fifo_queue                  = true
  content_based_deduplication = true
  kms_master_key_id           = aws_kms_key.principal.arn
  visibility_timeout_seconds  = 90

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.notificacionesMuerta.arn
    maxReceiveCount     = 4
  })
}

resource "aws_sqs_queue" "documentosMuerta" {
  name                        = "${local.prefijo}DocumentosMuerta.fifo"
  fifo_queue                  = true
  content_based_deduplication = true
  kms_master_key_id           = aws_kms_key.principal.arn
  message_retention_seconds   = 1209600
}

resource "aws_sqs_queue" "documentos" {
  name                        = "${local.prefijo}Documentos.fifo"
  fifo_queue                  = true
  content_based_deduplication = true
  kms_master_key_id           = aws_kms_key.principal.arn
  visibility_timeout_seconds  = 180

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.documentosMuerta.arn
    maxReceiveCount     = 4
  })
}

data "aws_iam_policy_document" "colaNotificaciones" {
  statement {
    sid       = "PermitirEventos"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.notificaciones.arn]

    principals {
      type        = "Service"
      identifiers = ["sns.amazonaws.com"]
    }

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_sns_topic.eventos.arn]
    }
  }
}

resource "aws_sqs_queue_policy" "notificaciones" {
  queue_url = aws_sqs_queue.notificaciones.id
  policy    = data.aws_iam_policy_document.colaNotificaciones.json
}

data "aws_iam_policy_document" "colaDocumentos" {
  statement {
    sid       = "PermitirEventos"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.documentos.arn]

    principals {
      type        = "Service"
      identifiers = ["sns.amazonaws.com"]
    }

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_sns_topic.eventos.arn]
    }
  }
}

resource "aws_sqs_queue_policy" "documentos" {
  queue_url = aws_sqs_queue.documentos.id
  policy    = data.aws_iam_policy_document.colaDocumentos.json
}

resource "aws_sns_topic_subscription" "notificaciones" {
  topic_arn            = aws_sns_topic.eventos.arn
  protocol             = "sqs"
  endpoint             = aws_sqs_queue.notificaciones.arn
  raw_message_delivery = false
  filter_policy        = jsonencode({ tipo = ["CitaCreada", "CitaCancelada"] })
}

resource "aws_sns_topic_subscription" "documentos" {
  topic_arn            = aws_sns_topic.eventos.arn
  protocol             = "sqs"
  endpoint             = aws_sqs_queue.documentos.arn
  raw_message_delivery = false
  filter_policy        = jsonencode({ tipo = ["CitaCreada"] })
}

resource "aws_s3_bucket" "documentos" {
  bucket        = lower("${local.nombreMinimo}-documentos-${substr(data.aws_caller_identity.actual.account_id, 8, 4)}")
  force_destroy = !var.ProtegerRecursos
}

resource "aws_s3_bucket_versioning" "documentos" {
  bucket = aws_s3_bucket.documentos.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "documentos" {
  bucket = aws_s3_bucket.documentos.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "documentos" {
  bucket                  = aws_s3_bucket.documentos.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "archive_file" "notificaciones" {
  type        = "zip"
  source_file = "${path.module}/../../../Aplicacion/ProcesadorNotificaciones/Manejador.py"
  output_path = "${path.module}/ProcesadorNotificaciones.zip"
}

resource "aws_iam_role" "lambdaNotificaciones" {
  name = "${local.prefijo}LambdaNotificaciones"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "lambdaNotificaciones" {
  role = aws_iam_role.lambdaNotificaciones.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
        Resource = aws_sqs_queue.notificaciones.arn
      },
      {
        Effect = "Allow"
        Action = ["dynamodb:PutItem"]
        Resource = aws_dynamodb_table.notificaciones.arn
      },
      {
        Effect = "Allow"
        Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:${data.aws_partition.actual.partition}:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = ["kms:Decrypt", "kms:Encrypt", "kms:GenerateDataKey"]
        Resource = aws_kms_key.principal.arn
      }
    ]
  })
}

resource "aws_lambda_function" "notificaciones" {
  function_name    = "${local.prefijo}ProcesadorNotificaciones"
  role             = aws_iam_role.lambdaNotificaciones.arn
  handler          = "Manejador.procesar"
  runtime          = "python3.12"
  filename         = data.archive_file.notificaciones.output_path
  source_code_hash = data.archive_file.notificaciones.output_base64sha256
  timeout                        = 30
  reserved_concurrent_executions = 10

  tracing_config {
    mode = "Active"
  }

  kms_key_arn = aws_kms_key.principal.arn

  environment {
    variables = {
      TABLANOTIFICACIONES = aws_dynamodb_table.notificaciones.name
    }
  }
}

resource "aws_lambda_event_source_mapping" "notificaciones" {
  event_source_arn = aws_sqs_queue.notificaciones.arn
  function_name    = aws_lambda_function.notificaciones.arn
  batch_size       = 5
}

resource "aws_s3_bucket_lifecycle_configuration" "documentos" {
  bucket = aws_s3_bucket.documentos.id

  rule {
    id     = "AdministrarDocumentos"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}
