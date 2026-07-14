resource "aws_ecr_repository" "personas" {
  name                 = "${local.nombreMinimo}/serviciopersonas"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = !var.ProtegerRecursos

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.principal.arn
  }
}

resource "aws_ecr_repository" "citas" {
  name                 = "${local.nombreMinimo}/serviciocitas"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = !var.ProtegerRecursos

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.principal.arn
  }
}

resource "aws_ecr_repository" "documentos" {
  name                 = "${local.nombreMinimo}/trabajadordocumentos"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = !var.ProtegerRecursos

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.principal.arn
  }
}

resource "aws_ecs_cluster" "principal" {
  name = "${local.prefijo}Cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_service_discovery_private_dns_namespace" "principal" {
  name = "dermanube.local"
  vpc  = aws_vpc.principal.id
}

resource "aws_service_discovery_service" "personas" {
  name = "personas"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.principal.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_service_discovery_service" "citas" {
  name = "citas"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.principal.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_lb" "interno" {
  name               = substr("${local.nombreMinimo}-alb", 0, 32)
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.balanceador.id]
  subnets            = aws_subnet.privadas[*].id

  enable_deletion_protection = var.ProtegerRecursos
  drop_invalid_header_fields = true

  access_logs {
    bucket  = aws_s3_bucket.registros.id
    prefix  = "alb"
    enabled = true
  }

  depends_on = [aws_s3_bucket_policy.registros]
}

resource "aws_lb_target_group" "personas" {
  name        = substr("${local.nombreMinimo}-personas", 0, 32)
  port        = 3001
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.principal.id

  health_check {
    enabled             = true
    path                = "/personas/salud"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 5
    matcher             = "200"
  }
}

resource "aws_lb_target_group" "citas" {
  name        = substr("${local.nombreMinimo}-citas", 0, 32)
  port        = 3002
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.principal.id

  health_check {
    enabled             = true
    path                = "/citas/salud"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 5
    matcher             = "200"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.interno.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "application/json"
      message_body = "{\"mensaje\":\"Ruta no encontrada\"}"
      status_code  = "404"
    }
  }
}

resource "aws_lb_listener_rule" "personas" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.personas.arn
  }

  condition {
    path_pattern {
      values = ["/personas", "/personas/*"]
    }
  }
}

resource "aws_lb_listener_rule" "citas" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 20

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.citas.arn
  }

  condition {
    path_pattern {
      values = ["/citas", "/citas/*"]
    }
  }
}

resource "aws_iam_role" "ejecucionEcs" {
  name = "${local.prefijo}EjecucionEcs"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ejecucionEcs" {
  role       = aws_iam_role.ejecucionEcs.name
  policy_arn = "arn:${data.aws_partition.actual.partition}:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "secretosEcs" {
  count = var.CrearCache ? 1 : 0
  role = aws_iam_role.ejecucionEcs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["secretsmanager:GetSecretValue", "kms:Decrypt"]
      Resource = [aws_secretsmanager_secret.redis[0].arn, aws_kms_key.principal.arn]
    }]
  })
}

resource "aws_iam_role" "tareaPersonas" {
  name = "${local.prefijo}TareaPersonas"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "tareaPersonas" {
  role = aws_iam_role.tareaPersonas.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        Effect = "Allow"
        Action = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:Scan", "dynamodb:Query"]
        Resource = [aws_dynamodb_table.personas.arn, "${aws_dynamodb_table.personas.arn}/index/*"]
      },
      {
        Effect = "Allow"
        Action = ["kms:Decrypt", "kms:Encrypt", "kms:GenerateDataKey"]
        Resource = aws_kms_key.principal.arn
      }
    ], var.CrearBusqueda ? [{
      Effect = "Allow"
      Action = ["es:ESHttpGet", "es:ESHttpPost", "es:ESHttpPut"]
      Resource = ["${local.arnBusqueda}/*"]
    }] : [])
  })
}

resource "aws_iam_role" "tareaCitas" {
  name = "${local.prefijo}TareaCitas"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "tareaCitas" {
  role = aws_iam_role.tareaCitas.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:DeleteItem", "dynamodb:Scan", "dynamodb:Query", "dynamodb:TransactWriteItems"]
        Resource = [aws_dynamodb_table.citas.arn, "${aws_dynamodb_table.citas.arn}/index/*"]
      },
      {
        Effect = "Allow"
        Action = ["sns:Publish"]
        Resource = aws_sns_topic.eventos.arn
      },
      {
        Effect = "Allow"
        Action = ["kms:Decrypt", "kms:Encrypt", "kms:GenerateDataKey"]
        Resource = aws_kms_key.principal.arn
      }
    ]
  })
}

data "aws_iam_policy_document" "opensearch" {
  statement {
    effect = "Allow"
    principals {
      type = "AWS"
      identifiers = [
        aws_iam_role.tareaPersonas.arn,
        "arn:${data.aws_partition.actual.partition}:iam::${data.aws_caller_identity.actual.account_id}:root"
      ]
    }
    actions   = ["es:ESHttp*"]
    resources = var.CrearBusqueda ? ["${local.arnBusqueda}/*"] : ["*"]
  }
}

resource "aws_cloudwatch_log_group" "personas" {
  name              = "/ecs/${local.prefijo}/Personas"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.principal.arn
}

resource "aws_cloudwatch_log_group" "citas" {
  name              = "/ecs/${local.prefijo}/Citas"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.principal.arn
}

resource "aws_ecs_task_definition" "personas" {
  count                    = local.crearServiciosReales ? 1 : 0
  family                   = "${local.prefijo}Personas"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ejecucionEcs.arn
  task_role_arn            = aws_iam_role.tareaPersonas.arn

  container_definitions = jsonencode([{
    name      = "ServicioPersonas"
    image     = var.ImagenServicioPersonas
    essential = true
    portMappings = [{ containerPort = 3001, hostPort = 3001, protocol = "tcp" }]
    environment = local.variablesPersonas
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.personas.name
        awslogs-region        = var.RegionAws
        awslogs-stream-prefix = "servicio"
      }
    }
    healthCheck = {
      command     = ["CMD-SHELL", "wget -qO- http://localhost:3001/personas/salud || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 20
    }
  }])
}

resource "aws_ecs_task_definition" "citas" {
  count                    = local.crearServiciosReales ? 1 : 0
  family                   = "${local.prefijo}Citas"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ejecucionEcs.arn
  task_role_arn            = aws_iam_role.tareaCitas.arn

  container_definitions = jsonencode([{
    name      = "ServicioCitas"
    image     = var.ImagenServicioCitas
    essential = true
    portMappings = [{ containerPort = 3002, hostPort = 3002, protocol = "tcp" }]
    environment = local.variablesCitas
    secrets = var.CrearCache ? [{ name = "CLAVEREDIS", valueFrom = aws_secretsmanager_secret.redis[0].arn }] : []
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.citas.name
        awslogs-region        = var.RegionAws
        awslogs-stream-prefix = "servicio"
      }
    }
    healthCheck = {
      command     = ["CMD-SHELL", "wget -qO- http://localhost:3002/citas/salud || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 20
    }
  }])
}

resource "aws_ecs_service" "personas" {
  count                              = local.crearServiciosReales ? 1 : 0
  name                               = "${local.prefijo}Personas"
  cluster                            = aws_ecs_cluster.principal.id
  task_definition                    = aws_ecs_task_definition.personas[0].arn
  desired_count                      = var.CapacidadMinimaServicios
  launch_type                        = "FARGATE"
  platform_version                   = "LATEST"
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200
  health_check_grace_period_seconds  = 60

  network_configuration {
    subnets          = aws_subnet.privadas[*].id
    security_groups  = [aws_security_group.servicios.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.personas.arn
    container_name   = "ServicioPersonas"
    container_port   = 3001
  }

  service_registries {
    registry_arn = aws_service_discovery_service.personas.arn
  }

  lifecycle {
    ignore_changes = [desired_count]
  }

  depends_on = [aws_lb_listener_rule.personas]
}

resource "aws_ecs_service" "citas" {
  count                              = local.crearServiciosReales ? 1 : 0
  name                               = "${local.prefijo}Citas"
  cluster                            = aws_ecs_cluster.principal.id
  task_definition                    = aws_ecs_task_definition.citas[0].arn
  desired_count                      = var.CapacidadMinimaServicios
  launch_type                        = "FARGATE"
  platform_version                   = "LATEST"
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200
  health_check_grace_period_seconds  = 60

  network_configuration {
    subnets          = aws_subnet.privadas[*].id
    security_groups  = [aws_security_group.servicios.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.citas.arn
    container_name   = "ServicioCitas"
    container_port   = 3002
  }

  service_registries {
    registry_arn = aws_service_discovery_service.citas.arn
  }

  lifecycle {
    ignore_changes = [desired_count]
  }

  depends_on = [aws_lb_listener_rule.citas]
}

resource "aws_appautoscaling_target" "personas" {
  count              = local.crearServiciosReales ? 1 : 0
  max_capacity       = var.CapacidadMaximaServicios
  min_capacity       = var.CapacidadMinimaServicios
  resource_id        = "service/${aws_ecs_cluster.principal.name}/${aws_ecs_service.personas[0].name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "personasCpu" {
  count              = local.crearServiciosReales ? 1 : 0
  name               = "${local.prefijo}PersonasCpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.personas[0].resource_id
  scalable_dimension = aws_appautoscaling_target.personas[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.personas[0].service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 55
    scale_in_cooldown  = 180
    scale_out_cooldown = 60

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}

resource "aws_appautoscaling_target" "citas" {
  count              = local.crearServiciosReales ? 1 : 0
  max_capacity       = var.CapacidadMaximaServicios
  min_capacity       = var.CapacidadMinimaServicios
  resource_id        = "service/${aws_ecs_cluster.principal.name}/${aws_ecs_service.citas[0].name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "citasCpu" {
  count              = local.crearServiciosReales ? 1 : 0
  name               = "${local.prefijo}CitasCpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.citas[0].resource_id
  scalable_dimension = aws_appautoscaling_target.citas[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.citas[0].service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 55
    scale_in_cooldown  = 180
    scale_out_cooldown = 60

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}
