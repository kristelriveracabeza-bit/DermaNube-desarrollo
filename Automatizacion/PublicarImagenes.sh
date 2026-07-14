#!/usr/bin/env bash
set -euo pipefail

Raiz="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
Directorio="$Raiz/Infraestructura/Terraform/Principal"
ArchivoVariables="$Directorio/terraform.tfvars"
RegionAws="${REGIONAWS:-}"

if [ -z "$RegionAws" ] && [ -f "$ArchivoVariables" ]; then
  RegionAws="$(grep -E '^[[:space:]]*RegionAws[[:space:]]*=' "$ArchivoVariables" | head -1 | sed -E 's/.*=[[:space:]]*"([^"]+)".*/\1/' || true)"
fi

RegionAws="${RegionAws:-us-east-1}"
Etiqueta="${ETIQUETAIMAGEN:-$(git -C "$Raiz" rev-parse --short=12 HEAD 2>/dev/null || date +%Y%m%d%H%M%S)}"
RepositorioPersonas="$(terraform -chdir="$Directorio" output -raw RepositorioPersonas)"
RepositorioCitas="$(terraform -chdir="$Directorio" output -raw RepositorioCitas)"
RepositorioDocumentos="$(terraform -chdir="$Directorio" output -raw RepositorioDocumentos)"
Registro="${RepositorioPersonas%%/*}"

aws ecr get-login-password --region "$RegionAws" | docker login --username AWS --password-stdin "$Registro"

publicarImagen() {
  local Repositorio="$1"
  local Contexto="$2"
  local NombreRepositorio="${Repositorio#*/}"

  if aws ecr describe-images --region "$RegionAws" --repository-name "$NombreRepositorio" --image-ids "imageTag=$Etiqueta" >/dev/null 2>&1; then
    echo "La imagen $Repositorio:$Etiqueta ya existe"
    return
  fi

  docker build -t "$Repositorio:$Etiqueta" "$Contexto"
  docker push "$Repositorio:$Etiqueta"
}

publicarImagen "$RepositorioPersonas" "$Raiz/Aplicacion/ServicioPersonas"
publicarImagen "$RepositorioCitas" "$Raiz/Aplicacion/ServicioCitas"
publicarImagen "$RepositorioDocumentos" "$Raiz/Aplicacion/TrabajadorDocumentos"

cat > "$Directorio/Imagenes.auto.tfvars.json" <<ARCHIVO
{
  "CrearServicios": true,
  "ImagenServicioPersonas": "$RepositorioPersonas:$Etiqueta",
  "ImagenServicioCitas": "$RepositorioCitas:$Etiqueta",
  "ImagenTrabajadorDocumentos": "$RepositorioDocumentos:$Etiqueta"
}
ARCHIVO

echo "Imagenes disponibles con etiqueta $Etiqueta"
