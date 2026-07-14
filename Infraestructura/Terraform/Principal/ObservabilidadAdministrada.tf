resource "aws_prometheus_workspace" "principal" {
  count = var.CrearPrometheusAdministrado ? 1 : 0
  alias = "${local.prefijo}Prometheus"
}

resource "aws_iam_role" "grafana" {
  count = var.CrearGrafanaAdministrado ? 1 : 0
  name  = "${local.prefijo}Grafana"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "grafana.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "grafana" {
  count = var.CrearGrafanaAdministrado ? 1 : 0
  role  = aws_iam_role.grafana[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["aps:ListWorkspaces", "aps:DescribeWorkspace", "aps:QueryMetrics", "aps:GetLabels", "aps:GetSeries", "aps:GetMetricMetadata"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = ["cloudwatch:DescribeAlarmsForMetric", "cloudwatch:DescribeAlarmHistory", "cloudwatch:DescribeAlarms", "cloudwatch:ListMetrics", "cloudwatch:GetMetricData", "cloudwatch:GetInsightRuleReport", "logs:DescribeLogGroups", "logs:GetLogGroupFields", "logs:StartQuery", "logs:StopQuery", "logs:GetQueryResults"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_grafana_workspace" "principal" {
  count                     = var.CrearGrafanaAdministrado ? 1 : 0
  name                      = "${local.prefijo}Grafana"
  account_access_type       = "CURRENT_ACCOUNT"
  authentication_providers  = ["AWS_SSO"]
  permission_type           = "CUSTOMER_MANAGED"
  role_arn                  = aws_iam_role.grafana[0].arn
  data_sources              = compact(["CLOUDWATCH", var.CrearPrometheusAdministrado ? "PROMETHEUS" : ""])
  notification_destinations = ["SNS"]
}
