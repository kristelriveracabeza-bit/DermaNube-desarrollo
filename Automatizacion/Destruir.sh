#!/usr/bin/env bash
set -euo pipefail

Raiz="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
Directorio="$Raiz/Infraestructura/Terraform/Principal"

terraform -chdir="$Directorio" apply -auto-approve -var="ProtegerRecursos=false"
terraform -chdir="$Directorio" destroy -var="ProtegerRecursos=false"
