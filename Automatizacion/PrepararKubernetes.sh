#!/usr/bin/env bash
set -euo pipefail

Raiz="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
Directorio="$Raiz/Infraestructura/Terraform/Principal"
Plantilla="$Raiz/Infraestructura/Kubernetes/TrabajadorDocumentos.yml"
Generado="$Raiz/Infraestructura/Kubernetes/TrabajadorDocumentosGenerado.yml"
EksNombre="$(terraform -chdir="$Directorio" output -raw EksNombre)"
Repositorio="$(terraform -chdir="$Directorio" output -raw RepositorioDocumentos)"
Cola="$(terraform -chdir="$Directorio" output -raw ColaDocumentosUrl)"
Balde="$(terraform -chdir="$Directorio" output -raw BaldeDocumentos)"
Etiqueta="${ETIQUETAIMAGEN:-latest}"
Region="${REGIONAWS:-us-east-1}"

if [ -z "$EksNombre" ]; then
  echo "EKS no esta habilitado"
  exit 1
fi

sed -e "s|IMAGENTRABAJADORDOCUMENTOS|$Repositorio:$Etiqueta|g" -e "s|COLADOCUMENTOSURL|$Cola|g" -e "s|BALDEDOCUMENTOS|$Balde|g" -e "s|REGIONAWS|$Region|g" "$Plantilla" > "$Generado"

aws eks update-kubeconfig --name "$EksNombre" --region "$Region"
kubectl apply -f "$Generado"
kubectl rollout status deployment/trabajadordocumentos -n dermanube --timeout=240s

echo "Trabajador desplegado en EKS"
