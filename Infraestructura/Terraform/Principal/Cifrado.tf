data "aws_iam_policy_document" "cifrado" {
  statement {
    sid       = "AdministracionCuenta"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.actual.partition}:iam::${data.aws_caller_identity.actual.account_id}:root"]
    }
  }

  statement {
    sid    = "RegistrosCloudWatch"
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["logs.${var.RegionAws}.amazonaws.com"]
    }

    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:${data.aws_partition.actual.partition}:logs:${var.RegionAws}:${data.aws_caller_identity.actual.account_id}:*"]
    }
  }

  statement {
    sid    = "AuditoriaCloudTrail"
    effect = "Allow"
    actions = [
      "kms:GenerateDataKey*",
      "kms:Decrypt",
      "kms:DescribeKey"
    ]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.actual.account_id]
    }
  }
}

resource "aws_kms_key" "principal" {
  description             = "Cifrado administrado de DermaNube"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.cifrado.json
}

resource "aws_kms_alias" "principal" {
  name          = "alias/${local.nombreMinimo}"
  target_key_id = aws_kms_key.principal.key_id
}

data "aws_iam_policy_document" "cifradoVirginia" {
  statement {
    sid       = "AdministracionCuenta"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.actual.partition}:iam::${data.aws_caller_identity.actual.account_id}:root"]
    }
  }

  statement {
    sid    = "RegistrosCloudWatch"
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["logs.us-east-1.amazonaws.com"]
    }

    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:${data.aws_partition.actual.partition}:logs:us-east-1:${data.aws_caller_identity.actual.account_id}:*"]
    }
  }
}

resource "aws_kms_key" "virginia" {
  provider                = aws.virginia
  description             = "Cifrado de registros globales de DermaNube"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.cifradoVirginia.json
}

resource "aws_kms_alias" "virginia" {
  provider      = aws.virginia
  name          = "alias/${local.nombreMinimo}-global"
  target_key_id = aws_kms_key.virginia.key_id
}
