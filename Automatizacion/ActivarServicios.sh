#!/usr/bin/env bash
set -euo pipefail

Raiz="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
Directorio="$Raiz/Infraestructura/Terraform/Principal"

if [ ! -f "$Directorio/Imagenes.auto.tfvars.json" ]; then
  echo "Ejecuta primero Automatizacion/PublicarImagenes.sh"
  exit 1
fi

terraform -chdir="$Directorio" plan -out=plan.tfplan
terraform -chdir="$Directorio" apply plan.tfplan

echo "Microservicios activados"
