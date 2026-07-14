#!/usr/bin/env bash
set -euo pipefail

for herramienta in aws terraform docker jq curl git; do
  if ! command -v "$herramienta" >/dev/null 2>&1; then
    echo "Falta la herramienta: $herramienta"
    exit 1
  fi
done

aws sts get-caller-identity >/dev/null
docker version >/dev/null
terraform version >/dev/null

echo "Herramientas y credenciales verificadas"
