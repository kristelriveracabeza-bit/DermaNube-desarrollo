import { DynamoDBClient } from "@aws-sdk/client-dynamodb"
import { DynamoDBDocumentClient, QueryCommand, ScanCommand, TransactWriteCommand, UpdateCommand } from "@aws-sdk/lib-dynamodb"

const memoria = new Map()
const bloqueos = new Set()

function usarAws() {
  return process.env.MODOALMACENAMIENTO === "aws"
}

function clienteDynamo() {
  const configuracion = { region: process.env.REGIONAWS || "us-east-1" }
  if (process.env.ENDPOINTDYNAMO) configuracion.endpoint = process.env.ENDPOINTDYNAMO
  return DynamoDBDocumentClient.from(new DynamoDBClient(configuracion), { marshallOptions: { removeUndefinedValues: true } })
}

export async function crearCita(cita) {
  const bloqueo = `BLOQUEO#${cita.especialistaId}#${cita.fechaHora}`
  if (!usarAws()) {
    if (bloqueos.has(bloqueo)) {
      const error = new Error("El horario ya no está disponible")
      error.name = "HorarioOcupado"
      throw error
    }
    bloqueos.add(bloqueo)
    memoria.set(cita.id, structuredClone(cita))
    return cita
  }
  await clienteDynamo().send(new TransactWriteCommand({
    TransactItems: [
      { Put: { TableName: process.env.TABLACITAS, Item: { id: bloqueo, tipo: "Bloqueo", especialistaId: cita.especialistaId, fechaHora: cita.fechaHora, citaId: cita.id }, ConditionExpression: "attribute_not_exists(id)" } },
      { Put: { TableName: process.env.TABLACITAS, Item: cita, ConditionExpression: "attribute_not_exists(id)" } }
    ]
  }))
  return cita
}

export async function listarCitas(pacienteId) {
  if (!usarAws()) return [...memoria.values()].filter(item => !pacienteId || item.pacienteId === pacienteId).sort((a, b) => b.fechaHora.localeCompare(a.fechaHora))
  if (pacienteId) {
    const respuesta = await clienteDynamo().send(new QueryCommand({
      TableName: process.env.TABLACITAS,
      IndexName: "PacienteFecha",
      KeyConditionExpression: "pacienteId = :pacienteId",
      ExpressionAttributeValues: { ":pacienteId": pacienteId },
      ScanIndexForward: false
    }))
    return respuesta.Items || []
  }
  const respuesta = await clienteDynamo().send(new ScanCommand({ TableName: process.env.TABLACITAS, FilterExpression: "#tipo = :tipo", ExpressionAttributeNames: { "#tipo": "tipo" }, ExpressionAttributeValues: { ":tipo": "Cita" } }))
  return respuesta.Items || []
}

export async function cancelarCita(id) {
  if (!usarAws()) {
    const cita = memoria.get(id)
    if (!cita) return null
    cita.estado = "Cancelada"
    cita.canceladaEn = new Date().toISOString()
    bloqueos.delete(`BLOQUEO#${cita.especialistaId}#${cita.fechaHora}`)
    memoria.set(id, cita)
    return cita
  }
  const citas = await clienteDynamo().send(new ScanCommand({ TableName: process.env.TABLACITAS, FilterExpression: "id = :id", ExpressionAttributeValues: { ":id": id } }))
  const cita = citas.Items?.[0]
  if (!cita) return null
  await clienteDynamo().send(new TransactWriteCommand({
    TransactItems: [
      { Update: { TableName: process.env.TABLACITAS, Key: { id }, UpdateExpression: "SET #estado = :estado, canceladaEn = :fecha", ExpressionAttributeNames: { "#estado": "estado" }, ExpressionAttributeValues: { ":estado": "Cancelada", ":fecha": new Date().toISOString() } } },
      { Delete: { TableName: process.env.TABLACITAS, Key: { id: `BLOQUEO#${cita.especialistaId}#${cita.fechaHora}` } } }
    ]
  }))
  return { ...cita, estado: "Cancelada" }
}
