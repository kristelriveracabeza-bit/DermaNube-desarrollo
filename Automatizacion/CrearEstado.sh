#!/usr/bin/env bash
set -euo pipefail

Raiz="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RegionAws="${REGIONAWS:-us-east-1}"

terraform -chdir="$Raiz/Infraestructura/Terraform/Bootstrap" init
terraform -chdir="$Raiz/Infraestructura/Terraform/Bootstrap" apply -auto-approve -var="RegionAws=$RegionAws"

BaldeEstado="$(terraform -chdir="$Raiz/Infraestructura/Terraform/Bootstrap" output -raw BaldeEstado)"
TablaBloqueo="$(terraform -chdir="$Raiz/Infraestructura/Terraform/Bootstrap" output -raw TablaBloqueo)"

cat > "$Raiz/Infraestructura/Terraform/Principal/Backend.hcl" <<ARCHIVO
bucket         = "$BaldeEstado"
key            = "DermaNube/Principal.tfstate"
region         = "$RegionAws"
dynamodb_table = "$TablaBloqueo"
encrypt        = true
ARCHIVO

echo "Estado remoto preparado en $BaldeEstado"
