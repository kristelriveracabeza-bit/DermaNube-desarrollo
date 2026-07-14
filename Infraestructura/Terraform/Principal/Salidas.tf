output "UrlFrontend" {
  value = local.dominioHabilitado ? "https://${var.Dominio}" : "https://${aws_cloudfront_distribution.frontend.domain_name}"
}

output "BaldeFrontend" {
  value = aws_s3_bucket.frontend.id
}

output "DistribucionFrontend" {
  value = aws_cloudfront_distribution.frontend.id
}

output "UrlApi" {
  value = aws_apigatewayv2_api.principal.api_endpoint
}

output "GrupoUsuariosId" {
  value = aws_cognito_user_pool.pacientes.id
}

output "ClienteUsuariosId" {
  value = aws_cognito_user_pool_client.web.id
}

output "DominioCognito" {
  value = "https://${aws_cognito_user_pool_domain.web.domain}.auth.${var.RegionAws}.amazoncognito.com"
}

output "RepositorioPersonas" {
  value = aws_ecr_repository.personas.repository_url
}

output "RepositorioCitas" {
  value = aws_ecr_repository.citas.repository_url
}

output "RepositorioDocumentos" {
  value = aws_ecr_repository.documentos.repository_url
}

output "ClusterEcs" {
  value = aws_ecs_cluster.principal.name
}

output "TablaPersonas" {
  value = aws_dynamodb_table.personas.name
}

output "TablaCitas" {
  value = aws_dynamodb_table.citas.name
}

output "TemaEventosArn" {
  value = aws_sns_topic.eventos.arn
}

output "ColaDocumentosUrl" {
  value = aws_sqs_queue.documentos.url
}

output "BaldeDocumentos" {
  value = aws_s3_bucket.documentos.id
}

output "EksNombre" {
  value = var.CrearEks ? aws_eks_cluster.principal[0].name : ""
}

output "JenkinsIp" {
  value = var.CrearJenkins ? aws_instance.jenkins[0].public_ip : ""
}

output "PrometheusAdministradoUrl" {
  value = var.CrearPrometheusAdministrado ? aws_prometheus_workspace.principal[0].prometheus_endpoint : ""
}

output "GrafanaAdministradoUrl" {
  value = var.CrearGrafanaAdministrado ? aws_grafana_workspace.principal[0].endpoint : ""
}

output "RolGithubActionsArn" {
  value = var.RepositorioGithub != "" ? aws_iam_role.github[0].arn : ""
}

output "SecretoAplicacionArn" {
  value = aws_secretsmanager_secret.aplicacion.arn
}

output "ServicioPersonasNombre" {
  value = local.crearServiciosReales ? aws_ecs_service.personas[0].name : ""
}

output "ServicioCitasNombre" {
  value = local.crearServiciosReales ? aws_ecs_service.citas[0].name : ""
}
