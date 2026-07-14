#!/usr/bin/env bash
set -euo pipefail

Raiz="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

bash "$Raiz/Automatizacion/VerificarHerramientas.sh"
bash "$Raiz/Automatizacion/CrearEstado.sh"
bash "$Raiz/Automatizacion/DesplegarBase.sh"
bash "$Raiz/Automatizacion/PublicarImagenes.sh"
bash "$Raiz/Automatizacion/ActivarServicios.sh"
bash "$Raiz/Automatizacion/PublicarFrontend.sh"
bash "$Raiz/Automatizacion/InicializarDatos.sh"
bash "$Raiz/Automatizacion/PruebasHumo.sh"
