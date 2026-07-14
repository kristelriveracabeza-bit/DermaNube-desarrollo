const inicio = Date.now()
const valores = {
  solicitudes: 0,
  errores: 0,
  duracionTotal: 0,
  citasCreadas: 0,
  citasCanceladas: 0,
  alertasRecibidas: 0,
  cargaActiva: 0
}

export function medirSolicitud(solicitud, respuesta, siguiente) {
  const comienzo = process.hrtime.bigint()
  valores.solicitudes += 1
  respuesta.on("finish", () => {
    valores.duracionTotal += Number(process.hrtime.bigint() - comienzo) / 1e9
    if (respuesta.statusCode >= 500) valores.errores += 1
  })
  siguiente()
}

export function incrementar(nombre, cantidad = 1) {
  if (Object.hasOwn(valores, nombre)) valores[nombre] += cantidad
}

export function establecer(nombre, cantidad) {
  if (Object.hasOwn(valores, nombre)) valores[nombre] = cantidad
}

export function obtenerMetricas() {
  const promedio = valores.solicitudes ? valores.duracionTotal / valores.solicitudes : 0
  return [
    "# HELP serviciocitas_solicitudes_total Solicitudes recibidas por el servicio",
    "# TYPE serviciocitas_solicitudes_total counter",
    `serviciocitas_solicitudes_total ${valores.solicitudes}`,
    "# HELP serviciocitas_errores_total Errores internos del servicio",
    "# TYPE serviciocitas_errores_total counter",
    `serviciocitas_errores_total ${valores.errores}`,
    "# HELP serviciocitas_duracion_promedio_segundos Duracion promedio de las solicitudes",
    "# TYPE serviciocitas_duracion_promedio_segundos gauge",
    `serviciocitas_duracion_promedio_segundos ${promedio}`,
    "# HELP serviciocitas_creadas_total Citas registradas",
    "# TYPE serviciocitas_creadas_total counter",
    `serviciocitas_creadas_total ${valores.citasCreadas}`,
    "# HELP serviciocitas_canceladas_total Citas canceladas",
    "# TYPE serviciocitas_canceladas_total counter",
    `serviciocitas_canceladas_total ${valores.citasCanceladas}`,
    "# HELP serviciocitas_alertas_recibidas_total Alertas recibidas desde Grafana",
    "# TYPE serviciocitas_alertas_recibidas_total counter",
    `serviciocitas_alertas_recibidas_total ${valores.alertasRecibidas}`,
    "# HELP serviciocitas_carga_activa Cargas de CPU activas",
    "# TYPE serviciocitas_carga_activa gauge",
    `serviciocitas_carga_activa ${valores.cargaActiva}`,
    "# HELP serviciocitas_proceso_activo_segundos Tiempo activo del proceso",
    "# TYPE serviciocitas_proceso_activo_segundos gauge",
    `serviciocitas_proceso_activo_segundos ${(Date.now() - inicio) / 1000}`
  ].join("\n") + "\n"
}
