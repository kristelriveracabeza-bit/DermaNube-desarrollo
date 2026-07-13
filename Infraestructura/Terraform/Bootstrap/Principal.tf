provider "aws" {
  region = var.RegionAws
  default_tags {
    tags = {
      Proyecto   = var.NombreProyecto
      Gestionado = "Terraform"
    }
  }
}

resource "random_id" "sufijo" {
  byte_length = 4
}

resource "aws_kms_key" "estado" {
  description             = "Cifrado del estado remoto de Terraform"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

resource "aws_kms_alias" "estado" {
  name          = "alias/${lower(var.NombreProyecto)}-terraform"
  target_key_id = aws_kms_key.estado.key_id
}

resource "aws_s3_bucket" "estado" {
  bucket        = lower("${var.NombreProyecto}-terraform-${random_id.sufijo.hex}")
  force_destroy = false
}

resource "aws_s3_bucket_versioning" "estado" {
  bucket = aws_s3_bucket.estado.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "estado" {
  bucket = aws_s3_bucket.estado.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.estado.arn
    }
  }
}

resource "aws_s3_bucket_public_access_block" "estado" {
  bucket                  = aws_s3_bucket.estado.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "bloqueo" {
  name         = "${var.NombreProyecto}BloqueoTerraform"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.estado.arn
  }
}


resource "aws_s3_bucket_lifecycle_configuration" "estado" {
  bucket = aws_s3_bucket.estado.id

  rule {
    id     = "ConservarVersiones"
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
