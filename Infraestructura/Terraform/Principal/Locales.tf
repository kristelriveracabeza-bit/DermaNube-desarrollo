locals {
  arnBusqueda = "arn:${data.aws_partition.actual.partition}:es:${var.RegionAws}:${data.aws_caller_identity.actual.account_id}:domain/${substr(local.nombreMinimo, 0, 28)}"
  crearServiciosReales = var.CrearServicios && var.ImagenServicioPersonas != "" && var.ImagenServicioCitas != ""
  variablesPersonas = [
    { name = "PUERTO", value = "3001" },
    { name = "MODOALMACENAMIENTO", value = "aws" },
    { name = "REGIONAWS", value = var.RegionAws },
    { name = "TABLAPERSONAS", value = aws_dynamodb_table.personas.name },
    { name = "ENDPOINTOPENSEARCH", value = var.CrearBusqueda ? aws_opensearch_domain.principal[0].endpoint : "" },
    { name = "CLAVEINICIALIZACION", value = random_password.inicializacion.result }
  ]
  variablesCitas = [
    { name = "PUERTO", value = "3002" },
    { name = "MODOALMACENAMIENTO", value = "aws" },
    { name = "REGIONAWS", value = var.RegionAws },
    { name = "TABLACITAS", value = aws_dynamodb_table.citas.name },
    { name = "TEMAEVENTOSARN", value = aws_sns_topic.eventos.arn },
    { name = "ENDPOINTREDIS", value = var.CrearCache ? aws_elasticache_replication_group.principal[0].primary_endpoint_address : "" },
    { name = "PUERTOREDIS", value = "6379" },
    { name = "REDISTLS", value = var.CrearCache ? "true" : "false" }
  ]
}

resource "random_password" "inicializacion" {
  length  = 28
  special = false
}
