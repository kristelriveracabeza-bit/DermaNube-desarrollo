$ErrorActionPreference = "Stop"
$RutaProyecto = Split-Path -Parent $PSScriptRoot
$RutaCompose = Join-Path $RutaProyecto "docker-compose.yml"
$RutaReglas = Join-Path $RutaProyecto "Observabilidad\Grafana\Aprovisionamiento\alerting\Reglas.yml"
$FechaRespaldo = Get-Date -Format "yyyyMMddHHmmss"

Copy-Item $RutaCompose "$RutaCompose.$FechaRespaldo.bak" -Force
Copy-Item $RutaReglas "$RutaReglas.$FechaRespaldo.bak" -Force

$Compose = Get-Content $RutaCompose -Raw
$Compose = $Compose.Replace('test: ["CMD", "wget", "-qO-", "http://localhost:3001/personas/salud"]', 'test: ["CMD", "node", "-e", "fetch(''http://127.0.0.1:3001/personas/salud'').then(respuesta=>{if(!respuesta.ok)process.exit(1)}).catch(()=>process.exit(1))"]')
$Compose = $Compose.Replace('test: ["CMD", "wget", "-qO-", "http://localhost:3002/citas/salud"]', 'test: ["CMD", "node", "-e", "fetch(''http://127.0.0.1:3002/citas/salud'').then(respuesta=>{if(!respuesta.ok)process.exit(1)}).catch(()=>process.exit(1))"]')
$Compose = $Compose.Replace("    container_name: dermanubeLoki`r`n    command:", "    container_name: dermanubeLoki`r`n    user: `"0`"`r`n    command:")
$Compose = $Compose.Replace("    container_name: dermanubeLoki`n    command:", "    container_name: dermanubeLoki`n    user: `"0`"`n    command:")
$Compose = $Compose.Replace("    command: [`"--path.rootfs=/host`"]`r`n    pid: host`r`n    volumes:`r`n      - /:/host:ro,rslave`r`n", "")
$Compose = $Compose.Replace("    command: [`"--path.rootfs=/host`"]`n    pid: host`n    volumes:`n      - /:/host:ro,rslave`n", "")
[System.IO.File]::WriteAllText($RutaCompose, $Compose, [System.Text.UTF8Encoding]::new($false))

$Reglas = Get-Content $RutaReglas -Raw
if ($Reglas -notmatch "relativeTimeRange") {
    $Reglas = $Reglas.Replace("          - refId: A`r`n            datasourceUid: prometheus`r`n            model:", "          - refId: A`r`n            datasourceUid: prometheus`r`n            relativeTimeRange:`r`n              from: 600`r`n              to: 0`r`n            model:")
    $Reglas = $Reglas.Replace("          - refId: A`n            datasourceUid: prometheus`n            model:", "          - refId: A`n            datasourceUid: prometheus`n            relativeTimeRange:`n              from: 600`n              to: 0`n            model:")
}
[System.IO.File]::WriteAllText($RutaReglas, $Reglas, [System.Text.UTF8Encoding]::new($false))

Set-Location $RutaProyecto
docker compose down --remove-orphans
docker compose up -d --build
Start-Sleep -Seconds 35
docker compose ps -a
