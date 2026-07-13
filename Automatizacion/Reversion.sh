#!/usr/bin/env bash
set -euo pipefail

Raiz="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
Directorio="$Raiz/Infraestructura/Terraform/Principal"
Cluster="$(terraform -chdir="$Directorio" output -raw ClusterEcs)"
ServicioPersonas="$(terraform -chdir="$Directorio" output -raw ServicioPersonasNombre)"
ServicioCitas="$(terraform -chdir="$Directorio" output -raw ServicioCitasNombre)"
Region="${REGIONAWS:-us-east-1}"

for Servicio in "$ServicioPersonas" "$ServicioCitas"; do
  [ -z "$Servicio" ] && continue
  DefinicionActual="$(aws ecs describe-services --cluster "$Cluster" --services "$Servicio" --region "$Region" --query 'services[0].taskDefinition' --output text)"
  Familia="${DefinicionActual%:*}"
  Familia="${Familia##*/}"
  Anterior="$(aws ecs list-task-definitions --family-prefix "$Familia" --sort DESC --max-items 2 --region "$Region" --query 'taskDefinitionArns[1]' --output text)"
  if [ "$Anterior" != "None" ] && [ -n "$Anterior" ]; then
    aws ecs update-service --cluster "$Cluster" --service "$Servicio" --task-definition "$Anterior" --force-new-deployment --region "$Region" >/dev/null
  fi
done

echo "Reversion solicitada"
