export function registrar(nivel, mensaje, datos = {}) {
  process.stdout.write(`${JSON.stringify({ fecha: new Date().toISOString(), nivel, servicio: "ServicioPersonas", mensaje, ...datos })}\n`)
}
