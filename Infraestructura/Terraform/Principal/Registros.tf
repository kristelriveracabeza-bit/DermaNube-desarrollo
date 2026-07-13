resource "aws_s3_bucket" "registros" {
  bucket        = lower("${local.nombreMinimo}-registros-${substr(data.aws_caller_identity.actual.account_id, 8, 4)}")
  force_destroy = !var.ProtegerRecursos
}

resource "aws_s3_bucket_versioning" "registros" {
  bucket = aws_s3_bucket.registros.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "registros" {
  bucket = aws_s3_bucket.registros.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "registros" {
  bucket                  = aws_s3_bucket.registros.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "registros" {
  bucket = aws_s3_bucket.registros.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "registros" {
  bucket = aws_s3_bucket.registros.id
  acl    = "log-delivery-write"

  depends_on = [
    aws_s3_bucket_ownership_controls.registros,
    aws_s3_bucket_public_access_block.registros
  ]
}

data "aws_iam_policy_document" "registros" {
  statement {
    sid       = "PermitirRegistrosAlb"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.registros.arn}/alb/AWSLogs/${data.aws_caller_identity.actual.account_id}/*"]

    principals {
      type        = "Service"
      identifiers = ["logdelivery.elasticloadbalancing.amazonaws.com"]
    }
  }

  statement {
    sid       = "ComprobarAclAlb"
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.registros.arn]

    principals {
      type        = "Service"
      identifiers = ["logdelivery.elasticloadbalancing.amazonaws.com"]
    }
  }
}

resource "aws_s3_bucket_policy" "registros" {
  bucket = aws_s3_bucket.registros.id
  policy = data.aws_iam_policy_document.registros.json
}

resource "aws_s3_bucket_lifecycle_configuration" "registros" {
  bucket = aws_s3_bucket.registros.id

  rule {
    id     = "ArchivarRegistros"
    status = "Enabled"

    filter {}

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}
