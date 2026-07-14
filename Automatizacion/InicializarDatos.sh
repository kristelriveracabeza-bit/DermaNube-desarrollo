#!/usr/bin/env bash
set -euo pipefail

Raiz="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
Directorio="$Raiz/Infraestructura/Terraform/Principal"
UrlApi="$(terraform -chdir="$Directorio" output -raw UrlApi)"
SecretoArn="$(terraform -chdir="$Directorio" output -raw SecretoAplicacionArn)"
Secreto="$(aws secretsmanager get-secret-value --secret-id "$SecretoArn" --query SecretString --output text | jq -r '.claveInicializacion')"

curl --fail --silent --show-error -X POST "$UrlApi/personas/inicializar" -H "x-clave-inicializacion: $Secreto" -H "Content-Type: application/json"
echo
echo "Especialistas inicializados"
