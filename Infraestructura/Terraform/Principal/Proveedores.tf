provider "aws" {
  region = var.RegionAws
  default_tags {
    tags = {
      Proyecto   = var.NombreProyecto
      Ambiente   = var.Ambiente
      Gestionado = "Terraform"
    }
  }
}

provider "aws" {
  alias  = "virginia"
  region = "us-east-1"
  default_tags {
    tags = {
      Proyecto   = var.NombreProyecto
      Ambiente   = var.Ambiente
      Gestionado = "Terraform"
    }
  }
}

data "aws_caller_identity" "actual" {}
data "aws_partition" "actual" {}
data "aws_availability_zones" "disponibles" {
  state = "available"
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  prefijo          = "${var.NombreProyecto}${title(var.Ambiente)}"
  nombreMinimo     = lower(replace("${var.NombreProyecto}-${var.Ambiente}", "_", "-"))
  zonas            = slice(data.aws_availability_zones.disponibles.names, 0, 2)
  dominioHabilitado = var.Dominio != "" && var.IdZonaHospedada != ""
  dominioCognito   = var.PrefijoDominioCognito != "" ? var.PrefijoDominioCognito : lower("${var.NombreProyecto}-${var.Ambiente}-${substr(data.aws_caller_identity.actual.account_id, 8, 4)}")
}
