const inicio = Date.now()
const valores = {
  solicitudes: 0,
  errores: 0,
  duracionTotal: 0,
  especialistasConsultados: 0,
  pacientesRegistrados: 0
}

export function medirSolicitud(solicitud, respuesta, siguiente) {
  const comienzo = process.hrtime.bigint()
  valores.solicitudes += 1
  respuesta.on("finish", () => {
    const duracion = Number(process.hrtime.bigint() - comienzo) / 1e9
    valores.duracionTotal += duracion
    if (respuesta.statusCode >= 500) valores.errores += 1
  })
  siguiente()
}

export function incrementar(nombre) {
  if (Object.hasOwn(valores, nombre)) valores[nombre] += 1
}

export function obtenerMetricas() {
  const promedio = valores.solicitudes ? valores.duracionTotal / valores.solicitudes : 0
  return [
    "# HELP serviciopersonas_solicitudes_total Solicitudes recibidas por el servicio",
    "# TYPE serviciopersonas_solicitudes_total counter",
    `serviciopersonas_solicitudes_total ${valores.solicitudes}`,
    "# HELP serviciopersonas_errores_total Errores internos del servicio",
    "# TYPE serviciopersonas_errores_total counter",
    `serviciopersonas_errores_total ${valores.errores}`,
    "# HELP serviciopersonas_duracion_promedio_segundos Duracion promedio de las solicitudes",
    "# TYPE serviciopersonas_duracion_promedio_segundos gauge",
    `serviciopersonas_duracion_promedio_segundos ${promedio}`,
    "# HELP serviciopersonas_especialistas_consultados_total Consultas de especialistas",
    "# TYPE serviciopersonas_especialistas_consultados_total counter",
    `serviciopersonas_especialistas_consultados_total ${valores.especialistasConsultados}`,
    "# HELP serviciopersonas_pacientes_registrados_total Pacientes registrados",
    "# TYPE serviciopersonas_pacientes_registrados_total counter",
    `serviciopersonas_pacientes_registrados_total ${valores.pacientesRegistrados}`,
    "# HELP serviciopersonas_proceso_activo_segundos Tiempo activo del proceso",
    "# TYPE serviciopersonas_proceso_activo_segundos gauge",
    `serviciopersonas_proceso_activo_segundos ${(Date.now() - inicio) / 1000}`
  ].join("\n") + "\n"
}
