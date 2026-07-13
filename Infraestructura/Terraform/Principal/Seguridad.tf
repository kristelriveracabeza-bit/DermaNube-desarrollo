resource "aws_security_group" "vinculoApi" {
  name        = "${local.prefijo}VinculoApi"
  description = "Acceso desde API Gateway"
  vpc_id      = aws_vpc.principal.id

  egress {
    description = "Conexion HTTP hacia el balanceador interno"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.CidrVpc]
  }
}

resource "aws_security_group" "balanceador" {
  name        = "${local.prefijo}Balanceador"
  description = "Acceso al balanceador interno"
  vpc_id      = aws_vpc.principal.id

  ingress {
    description     = "Solicitudes provenientes del vinculo privado de API Gateway"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.vinculoApi.id]
  }

  egress {
    description = "Distribucion hacia los microservicios"
    from_port   = 3001
    to_port     = 3002
    protocol    = "tcp"
    cidr_blocks = [var.CidrVpc]
  }
}

resource "aws_security_group" "servicios" {
  name        = "${local.prefijo}Servicios"
  description = "Acceso a microservicios"
  vpc_id      = aws_vpc.principal.id

  ingress {
    description     = "Solicitudes del balanceador"
    from_port       = 3001
    to_port         = 3002
    protocol        = "tcp"
    security_groups = [aws_security_group.balanceador.id]
  }

  ingress {
    description = "Comunicacion entre microservicios"
    from_port   = 3001
    to_port     = 3002
    protocol    = "tcp"
    self        = true
  }

  egress {
    description = "Servicios administrados y repositorios mediante HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Conexion cifrada con Redis"
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = [var.CidrVpc]
  }

  egress {
    description = "Resolucion DNS TCP"
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = [var.CidrVpc]
  }

  egress {
    description = "Resolucion DNS UDP"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = [var.CidrVpc]
  }
}

resource "aws_security_group" "datos" {
  name        = "${local.prefijo}Datos"
  description = "Acceso a servicios de datos"
  vpc_id      = aws_vpc.principal.id

  ingress {
    description     = "Acceso a Redis desde los microservicios"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.servicios.id]
  }

  ingress {
    description     = "Acceso HTTPS a OpenSearch desde los microservicios"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.servicios.id]
  }
}

resource "aws_security_group" "administracion" {
  count       = var.CrearJenkins ? 1 : 0
  name        = "${local.prefijo}Administracion"
  description = "Acceso administrativo controlado"
  vpc_id      = aws_vpc.principal.id

  ingress {
    description = "Administracion remota por SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.CidrAdministracion]
  }

  ingress {
    description = "Acceso a Jenkins"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.CidrAdministracion]
  }

  ingress {
    description = "Acceso administrativo a Grafana"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [var.CidrAdministracion]
  }

  egress {
    description = "Descargas de paquetes por HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Servicios y repositorios por HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Resolucion DNS TCP"
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = [var.CidrVpc]
  }

  egress {
    description = "Resolucion DNS UDP"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = [var.CidrVpc]
  }
}
