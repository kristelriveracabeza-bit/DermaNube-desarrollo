import crypto from "node:crypto"
import express from "express"
import cors from "cors"
import { eliminarCache, guardarCache, obtenerCache } from "./CacheHorarios.js"
import { cancelarCita, crearCita, listarCitas } from "./RepositorioCitas.js"
import { publicarEvento } from "./Mensajeria.js"
import { establecer, incrementar, medirSolicitud, obtenerMetricas } from "./Metricas.js"
import { registrar } from "./Registro.js"

function generarHorarios(especialistaId, fecha) {
  const horas = ["09:00", "10:30", "12:00", "15:00", "16:30", "18:00"]
  return horas.map((hora, indice) => ({ id: `${especialistaId}-${fecha}-${hora}`, fecha, hora, disponible: indice % 4 !== 3 }))
}

export function crearAplicacion() {
  const aplicacion = express()
  aplicacion.disable("x-powered-by")
  aplicacion.use(cors({ origin: process.env.ORIGENESPERMITIDOS?.split(",") || true }))
  aplicacion.use(express.json({ limit: "2mb" }))
  aplicacion.use(medirSolicitud)

  aplicacion.get("/citas/salud", (solicitud, respuesta) => respuesta.json({ estado: "saludable", servicio: "ServicioCitas", fecha: new Date().toISOString() }))

  aplicacion.get("/citas/metricas", (solicitud, respuesta) => respuesta.type("text/plain").send(obtenerMetricas()))

  aplicacion.get("/citas/horarios", async (solicitud, respuesta, siguiente) => {
    try {
      const especialistaId = String(solicitud.query.especialistaId || "")
      const fecha = String(solicitud.query.fecha || "")
      if (!especialistaId || !fecha) return respuesta.status(400).json({ mensaje: "Especialista y fecha son obligatorios" })
      const clave = `horarios:${especialistaId}:${fecha}`
      const guardados = await obtenerCache(clave)
      if (guardados) return respuesta.json({ elementos: guardados, origen: "cache" })
      const elementos = generarHorarios(especialistaId, fecha)
      await guardarCache(clave, elementos)
      respuesta.json({ elementos, origen: "servicio" })
    } catch (error) {
      siguiente(error)
    }
  })

  aplicacion.get("/citas", async (solicitud, respuesta, siguiente) => {
    try {
      const elementos = await listarCitas(solicitud.query.pacienteId)
      respuesta.json({ elementos, total: elementos.length })
    } catch (error) {
      siguiente(error)
    }
  })

  aplicacion.post("/citas", async (solicitud, respuesta, siguiente) => {
    try {
      const { pacienteId, especialistaId, especialistaNombre = "", fechaHora, modalidad = "Presencial", motivo } = solicitud.body
      if (!pacienteId || !especialistaId || !fechaHora || !motivo) return respuesta.status(400).json({ mensaje: "Los datos de la cita están incompletos" })
      const fecha = new Date(fechaHora)
      if (Number.isNaN(fecha.getTime()) || fecha <= new Date()) return respuesta.status(400).json({ mensaje: "La fecha de la cita debe ser futura" })
      const cita = {
        id: `CIT${crypto.randomUUID().replaceAll("-", "").slice(0, 18).toUpperCase()}`,
        tipo: "Cita",
        pacienteId: String(pacienteId),
        especialistaId: String(especialistaId),
        especialistaNombre: String(especialistaNombre),
        fechaHora: fecha.toISOString(),
        modalidad: String(modalidad),
        motivo: String(motivo).slice(0, 1000),
        estado: "Confirmada",
        creadaEn: new Date().toISOString()
      }
      await crearCita(cita)
      await eliminarCache(`horarios:${cita.especialistaId}:${cita.fechaHora.slice(0, 10)}`)
      await publicarEvento("CitaCreada", cita)
      incrementar("citasCreadas")
      registrar("INFO", "Cita registrada", { citaId: cita.id, pacienteId: cita.pacienteId, especialistaId: cita.especialistaId })
      respuesta.status(201).json(cita)
    } catch (error) {
      if (error.name === "HorarioOcupado" || error.name === "TransactionCanceledException") return respuesta.status(409).json({ mensaje: "El horario ya no está disponible" })
      siguiente(error)
    }
  })

  aplicacion.patch("/citas/:id/cancelar", async (solicitud, respuesta, siguiente) => {
    try {
      const cita = await cancelarCita(solicitud.params.id)
      if (!cita) return respuesta.status(404).json({ mensaje: "Cita no encontrada" })
      await publicarEvento("CitaCancelada", cita)
      incrementar("citasCanceladas")
      registrar("WARN", "Cita cancelada", { citaId: cita.id })
      respuesta.json(cita)
    } catch (error) {
      siguiente(error)
    }
  })

  aplicacion.post("/citas/alertas", (solicitud, respuesta) => {
    incrementar("alertasRecibidas")
    registrar("ERROR", "Alerta recibida desde observabilidad", { alerta: solicitud.body })
    respuesta.status(202).json({ recibido: true })
  })

  aplicacion.post("/citas/carga", (solicitud, respuesta) => {
    const segundos = Math.min(Math.max(Number(solicitud.body.segundos || 15), 1), 60)
    establecer("cargaActiva", 1)
    const fin = Date.now() + segundos * 1000
    setImmediate(() => {
      let acumulado = 0
      while (Date.now() < fin) acumulado += Math.sqrt(Math.random() * 100000)
      establecer("cargaActiva", 0)
      registrar("INFO", "Carga de CPU finalizada", { segundos, acumulado })
    })
    respuesta.status(202).json({ mensaje: "Carga iniciada", segundos })
  })

  aplicacion.use((solicitud, respuesta) => respuesta.status(404).json({ mensaje: "Ruta no encontrada" }))

  aplicacion.use((error, solicitud, respuesta, siguiente) => {
    registrar("ERROR", "Error no controlado", { error: error.message, ruta: solicitud.originalUrl })
    respuesta.status(500).json({ mensaje: "Ocurrió un error interno" })
  })

  return aplicacion
}
