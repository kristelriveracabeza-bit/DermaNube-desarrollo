import crypto from "node:crypto"
import express from "express"
import cors from "cors"
import { incrementar, medirSolicitud, obtenerMetricas } from "./Metricas.js"
import { inicializarEspecialistas, listarEspecialistas, obtenerPersona, guardarPersona } from "./RepositorioPersonas.js"
import { registrar } from "./Registro.js"

export function crearAplicacion() {
  const aplicacion = express()
  aplicacion.disable("x-powered-by")
  aplicacion.use(cors({ origin: process.env.ORIGENESPERMITIDOS?.split(",") || true }))
  aplicacion.use(express.json({ limit: "1mb" }))
  aplicacion.use(medirSolicitud)

  aplicacion.get("/personas/salud", (solicitud, respuesta) => respuesta.json({ estado: "saludable", servicio: "ServicioPersonas", fecha: new Date().toISOString() }))

  aplicacion.get("/personas/metricas", (solicitud, respuesta) => {
    respuesta.type("text/plain").send(obtenerMetricas())
  })

  aplicacion.get("/personas/especialistas", async (solicitud, respuesta, siguiente) => {
    try {
      incrementar("especialistasConsultados")
      const elementos = await listarEspecialistas({ termino: solicitud.query.termino, especialidad: solicitud.query.especialidad })
      respuesta.json({ elementos, total: elementos.length })
    } catch (error) {
      siguiente(error)
    }
  })

  aplicacion.get("/personas/especialistas/:id", async (solicitud, respuesta, siguiente) => {
    try {
      const persona = await obtenerPersona(solicitud.params.id)
      if (!persona || persona.tipo !== "Especialista") return respuesta.status(404).json({ mensaje: "Especialista no encontrado" })
      respuesta.json(persona)
    } catch (error) {
      siguiente(error)
    }
  })

  aplicacion.post("/personas/pacientes", async (solicitud, respuesta, siguiente) => {
    try {
      const { nombre, correo, telefono = "" } = solicitud.body
      if (!nombre || !correo) return respuesta.status(400).json({ mensaje: "Nombre y correo son obligatorios" })
      const paciente = {
        id: `PAC${crypto.randomUUID().replaceAll("-", "").slice(0, 16).toUpperCase()}`,
        tipo: "Paciente",
        nombre: String(nombre).trim(),
        correo: String(correo).trim().toLowerCase(),
        telefono: String(telefono).trim(),
        creadoEn: new Date().toISOString()
      }
      await guardarPersona(paciente)
      incrementar("pacientesRegistrados")
      registrar("INFO", "Paciente registrado", { pacienteId: paciente.id })
      respuesta.status(201).json(paciente)
    } catch (error) {
      if (error.name === "ConditionalCheckFailedException") return respuesta.status(409).json({ mensaje: "La persona ya existe" })
      siguiente(error)
    }
  })

  aplicacion.get("/personas/pacientes/:id", async (solicitud, respuesta, siguiente) => {
    try {
      const persona = await obtenerPersona(solicitud.params.id)
      if (!persona || persona.tipo !== "Paciente") return respuesta.status(404).json({ mensaje: "Paciente no encontrado" })
      respuesta.json(persona)
    } catch (error) {
      siguiente(error)
    }
  })

  aplicacion.post("/personas/inicializar", async (solicitud, respuesta, siguiente) => {
    try {
      if (solicitud.headers["x-clave-inicializacion"] !== process.env.CLAVEINICIALIZACION) return respuesta.status(403).json({ mensaje: "Acceso denegado" })
      const elementos = await inicializarEspecialistas()
      registrar("INFO", "Especialistas inicializados", { total: elementos.length })
      respuesta.json({ total: elementos.length })
    } catch (error) {
      siguiente(error)
    }
  })

  aplicacion.use((solicitud, respuesta) => respuesta.status(404).json({ mensaje: "Ruta no encontrada" }))

  aplicacion.use((error, solicitud, respuesta, siguiente) => {
    registrar("ERROR", "Error no controlado", { error: error.message, ruta: solicitud.originalUrl })
    respuesta.status(500).json({ mensaje: "Ocurrió un error interno" })
  })

  return aplicacion
}
