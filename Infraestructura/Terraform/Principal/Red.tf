resource "aws_vpc" "principal" {
  cidr_block           = var.CidrVpc
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${local.prefijo}Vpc"
  }
}

resource "aws_internet_gateway" "principal" {
  vpc_id = aws_vpc.principal.id

  tags = {
    Name = "${local.prefijo}InternetGateway"
  }
}

resource "aws_subnet" "publicas" {
  count                   = 2
  vpc_id                  = aws_vpc.principal.id
  availability_zone       = local.zonas[count.index]
  cidr_block              = cidrsubnet(var.CidrVpc, 4, count.index)
  map_public_ip_on_launch = false

  tags = {
    Name                     = "${local.prefijo}Publica${count.index + 1}"
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_subnet" "privadas" {
  count             = 2
  vpc_id            = aws_vpc.principal.id
  availability_zone = local.zonas[count.index]
  cidr_block        = cidrsubnet(var.CidrVpc, 4, count.index + 4)

  tags = {
    Name                              = "${local.prefijo}Privada${count.index + 1}"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

resource "aws_subnet" "datos" {
  count             = 2
  vpc_id            = aws_vpc.principal.id
  availability_zone = local.zonas[count.index]
  cidr_block        = cidrsubnet(var.CidrVpc, 4, count.index + 8)

  tags = {
    Name = "${local.prefijo}Datos${count.index + 1}"
  }
}

resource "aws_route_table" "publica" {
  vpc_id = aws_vpc.principal.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.principal.id
  }

  tags = {
    Name = "${local.prefijo}RutaPublica"
  }
}

resource "aws_route_table_association" "publicas" {
  count          = 2
  subnet_id      = aws_subnet.publicas[count.index].id
  route_table_id = aws_route_table.publica.id
}

resource "aws_eip" "nat" {
  count  = var.CrearNatGateway ? 1 : 0
  domain = "vpc"

  depends_on = [aws_internet_gateway.principal]
}

resource "aws_nat_gateway" "principal" {
  count         = var.CrearNatGateway ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.publicas[0].id

  tags = {
    Name = "${local.prefijo}NatGateway"
  }
}

resource "aws_route_table" "privada" {
  vpc_id = aws_vpc.principal.id

  dynamic "route" {
    for_each = var.CrearNatGateway ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.principal[0].id
    }
  }

  tags = {
    Name = "${local.prefijo}RutaPrivada"
  }
}

resource "aws_route_table_association" "privadas" {
  count          = 2
  subnet_id      = aws_subnet.privadas[count.index].id
  route_table_id = aws_route_table.privada.id
}

resource "aws_route_table" "datos" {
  vpc_id = aws_vpc.principal.id

  tags = {
    Name = "${local.prefijo}RutaDatos"
  }
}

resource "aws_route_table_association" "datos" {
  count          = 2
  subnet_id      = aws_subnet.datos[count.index].id
  route_table_id = aws_route_table.datos.id
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.principal.id
  service_name      = "com.amazonaws.${var.RegionAws}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.privada.id, aws_route_table.datos.id]
}

resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = aws_vpc.principal.id
  service_name      = "com.amazonaws.${var.RegionAws}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.privada.id, aws_route_table.datos.id]
}


resource "aws_default_security_group" "principal" {
  vpc_id = aws_vpc.principal.id
}

resource "aws_cloudwatch_log_group" "flujoVpc" {
  name              = "/aws/vpc/${local.prefijo}"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.principal.arn
}

resource "aws_iam_role" "flujoVpc" {
  name = "${local.prefijo}FlujoVpc"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "flujoVpc" {
  role = aws_iam_role.flujoVpc.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogGroups", "logs:DescribeLogStreams"]
      Resource = "${aws_cloudwatch_log_group.flujoVpc.arn}:*"
    }]
  })
}

resource "aws_flow_log" "principal" {
  iam_role_arn    = aws_iam_role.flujoVpc.arn
  log_destination = aws_cloudwatch_log_group.flujoVpc.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.principal.id
}
