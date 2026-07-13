import assert from "node:assert/strict"
import test from "node:test"
import { once } from "node:events"
import { crearAplicacion } from "../src/Aplicacion.js"

test("lista especialistas disponibles", async () => {
  process.env.MODOALMACENAMIENTO = "memoria"
  const servidor = crearAplicacion().listen(0)
  await once(servidor, "listening")
  const puerto = servidor.address().port
  const respuesta = await fetch(`http://127.0.0.1:${puerto}/personas/especialistas`)
  const cuerpo = await respuesta.json()
  assert.equal(respuesta.status, 200)
  assert.ok(cuerpo.total >= 4)
  servidor.close()
})

test("rechaza pacientes incompletos", async () => {
  const servidor = crearAplicacion().listen(0)
  await once(servidor, "listening")
  const puerto = servidor.address().port
  const respuesta = await fetch(`http://127.0.0.1:${puerto}/personas/pacientes`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ nombre: "Paciente" }) })
  assert.equal(respuesta.status, 400)
  servidor.close()
})
