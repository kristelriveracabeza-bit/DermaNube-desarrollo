#!/usr/bin/env bash
set -euo pipefail

Raiz="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
Directorio="$Raiz/Infraestructura/Terraform/Principal"

if [ ! -f "$Directorio/Backend.hcl" ]; then
  echo "Ejecuta primero Automatizacion/CrearEstado.sh"
  exit 1
fi

if [ ! -f "$Directorio/terraform.tfvars" ]; then
  cp "$Directorio/terraform.tfvars.ejemplo" "$Directorio/terraform.tfvars"
  echo "Se creo terraform.tfvars. Revisa sus valores y vuelve a ejecutar este comando"
  exit 1
fi

terraform -chdir="$Directorio" init -backend-config=Backend.hcl -reconfigure
terraform -chdir="$Directorio" validate
terraform -chdir="$Directorio" plan -out=plan.tfplan -var="CrearServicios=false"
terraform -chdir="$Directorio" apply plan.tfplan

echo "Infraestructura base desplegada"
