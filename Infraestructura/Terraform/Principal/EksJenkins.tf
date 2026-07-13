resource "aws_iam_role" "eksCluster" {
  count = var.CrearEks ? 1 : 0
  name  = "${local.prefijo}EksCluster"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eksCluster" {
  count      = var.CrearEks ? 1 : 0
  role       = aws_iam_role.eksCluster[0].name
  policy_arn = "arn:${data.aws_partition.actual.partition}:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role" "eksNodos" {
  count = var.CrearEks ? 1 : 0
  name  = "${local.prefijo}EksNodos"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eksNodosTrabajador" {
  count      = var.CrearEks ? 1 : 0
  role       = aws_iam_role.eksNodos[0].name
  policy_arn = "arn:${data.aws_partition.actual.partition}:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eksNodosCni" {
  count      = var.CrearEks ? 1 : 0
  role       = aws_iam_role.eksNodos[0].name
  policy_arn = "arn:${data.aws_partition.actual.partition}:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "eksNodosEcr" {
  count      = var.CrearEks ? 1 : 0
  role       = aws_iam_role.eksNodos[0].name
  policy_arn = "arn:${data.aws_partition.actual.partition}:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy" "eksDocumentos" {
  count = var.CrearEks ? 1 : 0
  role  = aws_iam_role.eksNodos[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes", "sqs:ChangeMessageVisibility"]
        Resource = aws_sqs_queue.documentos.arn
      },
      {
        Effect = "Allow"
        Action = ["s3:PutObject", "s3:AbortMultipartUpload"]
        Resource = "${aws_s3_bucket.documentos.arn}/*"
      },
      {
        Effect = "Allow"
        Action = ["kms:Decrypt", "kms:Encrypt", "kms:GenerateDataKey"]
        Resource = aws_kms_key.principal.arn
      }
    ]
  })
}

resource "aws_eks_cluster" "principal" {
  count    = var.CrearEks ? 1 : 0
  name     = "${local.prefijo}Eks"
  role_arn = aws_iam_role.eksCluster[0].arn
  version  = "1.35"

  vpc_config {
    subnet_ids              = aws_subnet.privadas[*].id
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = [var.CidrAdministracion]
  }

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  depends_on = [aws_iam_role_policy_attachment.eksCluster]
}

resource "aws_eks_node_group" "principal" {
  count           = var.CrearEks ? 1 : 0
  cluster_name    = aws_eks_cluster.principal[0].name
  node_group_name = "${local.prefijo}Nodos"
  node_role_arn   = aws_iam_role.eksNodos[0].arn
  subnet_ids      = aws_subnet.privadas[*].id
  instance_types  = ["t3.small"]
  capacity_type   = "ON_DEMAND"
  disk_size       = 30

  scaling_config {
    desired_size = 2
    min_size     = 1
    max_size     = 4
  }

  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.eksNodosTrabajador,
    aws_iam_role_policy_attachment.eksNodosCni,
    aws_iam_role_policy_attachment.eksNodosEcr
  ]
}

resource "aws_key_pair" "administracion" {
  count      = var.CrearJenkins && var.LlaveSshPublica != "" ? 1 : 0
  key_name   = "${local.prefijo}Administracion"
  public_key = var.LlaveSshPublica
}

resource "aws_iam_role" "jenkins" {
  count = var.CrearJenkins ? 1 : 0
  name  = "${local.prefijo}Jenkins"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}


resource "aws_iam_role_policy_attachment" "jenkinsPowerUser" {
  count      = var.CrearJenkins ? 1 : 0
  role       = aws_iam_role.jenkins[0].name
  policy_arn = "arn:${data.aws_partition.actual.partition}:iam::aws:policy/PowerUserAccess"
}

resource "aws_iam_role_policy" "jenkinsIam" {
  count = var.CrearJenkins ? 1 : 0
  role  = aws_iam_role.jenkins[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["iam:CreateRole", "iam:DeleteRole", "iam:GetRole", "iam:UpdateAssumeRolePolicy", "iam:TagRole", "iam:UntagRole", "iam:PutRolePolicy", "iam:GetRolePolicy", "iam:DeleteRolePolicy", "iam:AttachRolePolicy", "iam:DetachRolePolicy", "iam:ListRolePolicies", "iam:ListAttachedRolePolicies", "iam:PassRole"]
        Resource = "arn:${data.aws_partition.actual.partition}:iam::${data.aws_caller_identity.actual.account_id}:role/${local.prefijo}*"
      },
      {
        Effect = "Allow"
        Action = ["iam:CreateInstanceProfile", "iam:DeleteInstanceProfile", "iam:GetInstanceProfile", "iam:AddRoleToInstanceProfile", "iam:RemoveRoleFromInstanceProfile", "iam:TagInstanceProfile"]
        Resource = "arn:${data.aws_partition.actual.partition}:iam::${data.aws_caller_identity.actual.account_id}:instance-profile/${local.prefijo}*"
      },
      {
        Effect = "Allow"
        Action = ["iam:CreateServiceLinkedRole"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "jenkins" {
  count = var.CrearJenkins ? 1 : 0
  role  = aws_iam_role.jenkins[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = ["ecr:BatchCheckLayerAvailability", "ecr:GetDownloadUrlForLayer", "ecr:BatchGetImage", "ecr:PutImage", "ecr:InitiateLayerUpload", "ecr:UploadLayerPart", "ecr:CompleteLayerUpload"]
        Resource = [aws_ecr_repository.personas.arn, aws_ecr_repository.citas.arn, aws_ecr_repository.documentos.arn]
      },
      {
        Effect = "Allow"
        Action = ["ecs:DescribeServices", "ecs:UpdateService", "ecs:DescribeTaskDefinition", "ecs:RegisterTaskDefinition", "ecs:ListTasks", "ecs:DescribeTasks"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = ["eks:DescribeCluster"]
        Resource = var.CrearEks ? aws_eks_cluster.principal[0].arn : "*"
      },
      {
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]
        Resource = [aws_s3_bucket.frontend.arn, "${aws_s3_bucket.frontend.arn}/*"]
      },
      {
        Effect = "Allow"
        Action = ["cloudfront:CreateInvalidation"]
        Resource = aws_cloudfront_distribution.frontend.arn
      }
    ]
  })
}

resource "aws_iam_instance_profile" "jenkins" {
  count = var.CrearJenkins ? 1 : 0
  name  = "${local.prefijo}Jenkins"
  role  = aws_iam_role.jenkins[0].name
}

resource "aws_instance" "jenkins" {
  count                       = var.CrearJenkins ? 1 : 0
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.small"
  subnet_id                   = aws_subnet.publicas[0].id
  vpc_security_group_ids      = [aws_security_group.administracion[0].id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.jenkins[0].name
  key_name                    = var.LlaveSshPublica != "" ? aws_key_pair.administracion[0].key_name : null

  root_block_device {
    encrypted   = true
    volume_type = "gp3"
    volume_size = 30
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = {
    Name = "${local.prefijo}Jenkins"
  }

  lifecycle {
    precondition {
      condition     = var.LlaveSshPublica != ""
      error_message = "LlaveSshPublica es obligatoria cuando CrearJenkins es true"
    }
  }
}

resource "aws_eks_access_entry" "jenkins" {
  count         = var.CrearEks && var.CrearJenkins ? 1 : 0
  cluster_name  = aws_eks_cluster.principal[0].name
  principal_arn = aws_iam_role.jenkins[0].arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "jenkins" {
  count         = var.CrearEks && var.CrearJenkins ? 1 : 0
  cluster_name  = aws_eks_cluster.principal[0].name
  principal_arn = aws_iam_role.jenkins[0].arn
  policy_arn    = "arn:${data.aws_partition.actual.partition}:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.jenkins]
}
