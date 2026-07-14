#!/usr/bin/env bash
set -euo pipefail

Raiz="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
Directorio="$Raiz/Infraestructura/Terraform/Principal"
UrlApi="$(terraform -chdir="$Directorio" output -raw UrlApi)"
UrlFrontend="$(terraform -chdir="$Directorio" output -raw UrlFrontend)"

curl --fail --silent "$UrlFrontend" >/dev/null
curl --fail --silent "$UrlApi/personas/salud" | jq -e '.estado == "saludable"' >/dev/null
curl --fail --silent "$UrlApi/citas/salud" | jq -e '.estado == "saludable"' >/dev/null
curl --fail --silent "$UrlApi/personas/especialistas" | jq -e '.total >= 1' >/dev/null

echo "Pruebas de humo superadas"
