resource "aws_s3_bucket" "frontend" {
  bucket        = lower("${local.nombreMinimo}-web-${substr(data.aws_caller_identity.actual.account_id, 8, 4)}")
  force_destroy = !var.ProtegerRecursos
}

resource "aws_s3_bucket_versioning" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket                  = aws_s3_bucket.frontend.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_cloudfront_origin_access_control" "frontend" {
  name                              = "${local.prefijo}Frontend"
  description                       = "Acceso privado al frontend"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_wafv2_web_acl" "frontend" {
  provider = aws.virginia
  name     = "${local.prefijo}WebAcl"
  scope    = "CLOUDFRONT"

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${local.prefijo}WebAcl"
    sampled_requests_enabled   = true
  }

  rule {
    name     = "ReglasComunes"
    priority = 10

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.prefijo}ReglasComunes"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "EntradasPeligrosas"
    priority = 20

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.prefijo}EntradasPeligrosas"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "DireccionesAnonimas"
    priority = 25

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAnonymousIpList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.prefijo}DireccionesAnonimas"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "LimiteSolicitudes"
    priority = 30

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.prefijo}LimiteSolicitudes"
      sampled_requests_enabled   = true
    }
  }
}

resource "aws_acm_certificate" "frontend" {
  count             = local.dominioHabilitado ? 1 : 0
  provider          = aws.virginia
  domain_name       = var.Dominio
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "validacionCertificado" {
  for_each = local.dominioHabilitado ? {
    for opcion in aws_acm_certificate.frontend[0].domain_validation_options : opcion.domain_name => {
      nombre = opcion.resource_record_name
      tipo   = opcion.resource_record_type
      valor  = opcion.resource_record_value
    }
  } : {}

  zone_id = var.IdZonaHospedada
  name    = each.value.nombre
  type    = each.value.tipo
  records = [each.value.valor]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "frontend" {
  count                   = local.dominioHabilitado ? 1 : 0
  provider                = aws.virginia
  certificate_arn         = aws_acm_certificate.frontend[0].arn
  validation_record_fqdns = [for registro in aws_route53_record.validacionCertificado : registro.fqdn]
}

resource "aws_cloudfront_response_headers_policy" "seguridad" {
  name = "${local.prefijo}Encabezados"

  security_headers_config {
    content_type_options {
      override = true
    }

    frame_options {
      frame_option = "DENY"
      override     = true
    }

    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }

    strict_transport_security {
      access_control_max_age_sec = 63072000
      include_subdomains         = true
      preload                    = true
      override                   = true
    }

    xss_protection {
      mode_block = true
      protection = true
      override   = true
    }
  }
}

resource "aws_cloudwatch_log_group" "waf" {
  provider          = aws.virginia
  name              = "aws-waf-logs-${local.nombreMinimo}"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.virginia.arn
}

resource "aws_wafv2_web_acl_logging_configuration" "frontend" {
  provider                = aws.virginia
  resource_arn            = aws_wafv2_web_acl.frontend.arn
  log_destination_configs = [aws_cloudwatch_log_group.waf.arn]

  redacted_fields {
    single_header {
      name = "authorization"
    }
  }
}

resource "aws_cloudfront_distribution" "frontend" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  aliases             = local.dominioHabilitado ? [var.Dominio] : []
  web_acl_id          = aws_wafv2_web_acl.frontend.arn
  price_class         = "PriceClass_100"

  logging_config {
    include_cookies = false
    bucket          = aws_s3_bucket.registros.bucket_domain_name
    prefix          = "cloudfront/"
  }

  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id                = "FrontendS3"
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "FrontendS3"
    viewer_protocol_policy = "redirect-to-https"
    compress                   = true
    response_headers_policy_id = aws_cloudfront_response_headers_policy.seguridad.id

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 0
  }

  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 0
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn            = local.dominioHabilitado ? aws_acm_certificate_validation.frontend[0].certificate_arn : null
    cloudfront_default_certificate = local.dominioHabilitado ? false : true
    ssl_support_method             = local.dominioHabilitado ? "sni-only" : null
    minimum_protocol_version       = "TLSv1.2_2021"
  }

  depends_on = [aws_acm_certificate_validation.frontend]
}

data "aws_iam_policy_document" "frontend" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.frontend.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.frontend.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  policy = data.aws_iam_policy_document.frontend.json
}

resource "aws_route53_record" "frontend" {
  count   = local.dominioHabilitado ? 1 : 0
  zone_id = var.IdZonaHospedada
  name    = var.Dominio
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.frontend.domain_name
    zone_id                = aws_cloudfront_distribution.frontend.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  rule {
    id     = "ConservarVersiones"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 60
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}
