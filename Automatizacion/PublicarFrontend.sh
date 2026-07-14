#!/usr/bin/env bash
set -euo pipefail

Raiz="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
Directorio="$Raiz/Infraestructura/Terraform/Principal"
Publico="$Raiz/Aplicacion/Frontend/public"
UrlApi="$(terraform -chdir="$Directorio" output -raw UrlApi)"
UrlFrontend="$(terraform -chdir="$Directorio" output -raw UrlFrontend)"
GrupoUsuariosId="$(terraform -chdir="$Directorio" output -raw GrupoUsuariosId)"
ClienteUsuariosId="$(terraform -chdir="$Directorio" output -raw ClienteUsuariosId)"
DominioCognito="$(terraform -chdir="$Directorio" output -raw DominioCognito)"
BaldeFrontend="$(terraform -chdir="$Directorio" output -raw BaldeFrontend)"
DistribucionFrontend="$(terraform -chdir="$Directorio" output -raw DistribucionFrontend)"

cat > "$Publico/configuracion.js" <<ARCHIVO
window.ConfiguracionDermaNube = {
  urlApi: "$UrlApi",
  regionAws: "${REGIONAWS:-us-east-1}",
  idGrupoUsuarios: "$GrupoUsuariosId",
  idClienteUsuarios: "$ClienteUsuariosId",
  dominioCognito: "$DominioCognito",
  urlRetorno: "$UrlFrontend",
  modoLocal: false
}
ARCHIVO

aws s3 sync "$Publico" "s3://$BaldeFrontend" --delete --exclude "configuracion.ejemplo.js"
aws cloudfront create-invalidation --distribution-id "$DistribucionFrontend" --paths "/*" >/dev/null

echo "Frontend publicado en $UrlFrontend"
