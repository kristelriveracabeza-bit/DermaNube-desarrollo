import assert from "node:assert/strict"
import test from "node:test"
import { once } from "node:events"
import { crearAplicacion } from "../src/Aplicacion.js"

async function iniciarServidor() {
  process.env.MODOALMACENAMIENTO = "memoria"
  const servidor = crearAplicacion().listen(0)
  await once(servidor, "listening")
  return servidor
}

test("registra y lista una cita", async () => {
  const servidor = await iniciarServidor()
  const puerto = servidor.address().port
  const fechaHora = new Date(Date.now() + 86400000).toISOString()
  const respuesta = await fetch(`http://127.0.0.1:${puerto}/citas`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ pacienteId: "PAC001", especialistaId: "ESP001", fechaHora, modalidad: "Presencial", motivo: "Evaluación" }) })
  assert.equal(respuesta.status, 201)
  const listado = await fetch(`http://127.0.0.1:${puerto}/citas?pacienteId=PAC001`).then(item => item.json())
  assert.equal(listado.total, 1)
  servidor.close()
})

test("evita reservar el mismo horario", async () => {
  const servidor = await iniciarServidor()
  const puerto = servidor.address().port
  const fechaHora = new Date(Date.now() + 172800000).toISOString()
  const cuerpo = { pacienteId: "PAC010", especialistaId: "ESP002", fechaHora, modalidad: "Presencial", motivo: "Control" }
  const primera = await fetch(`http://127.0.0.1:${puerto}/citas`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(cuerpo) })
  const segunda = await fetch(`http://127.0.0.1:${puerto}/citas`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ ...cuerpo, pacienteId: "PAC011" }) })
  assert.equal(primera.status, 201)
  assert.equal(segunda.status, 409)
  servidor.close()
})
