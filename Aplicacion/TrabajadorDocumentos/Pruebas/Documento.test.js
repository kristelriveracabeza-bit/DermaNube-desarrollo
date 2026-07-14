import assert from "node:assert/strict"
import test from "node:test"
import { generarDocumento } from "../src/Documento.js"

test("genera un documento PDF", async () => {
  const contenido = await generarDocumento({ id: "CIT001", pacienteId: "PAC001", especialistaNombre: "Especialista", fechaHora: new Date().toISOString() })
  assert.ok(contenido.length > 500)
  assert.equal(String.fromCharCode(...contenido.slice(0, 4)), "%PDF")
})
