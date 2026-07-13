import { S3Client, PutObjectCommand } from "@aws-sdk/client-s3"
import { DeleteMessageCommand, ReceiveMessageCommand, SQSClient } from "@aws-sdk/client-sqs"
import { generarDocumento } from "./Documento.js"

const region = process.env.REGIONAWS || "us-east-1"
const colaUrl = process.env.COLADOCUMENTOSURL
const balde = process.env.BALDEDOCUMENTOS
const sqs = new SQSClient({ region })
const s3 = new S3Client({ region })

function registrar(nivel, mensaje, datos = {}) {
  process.stdout.write(`${JSON.stringify({ fecha: new Date().toISOString(), nivel, servicio: "TrabajadorDocumentos", mensaje, ...datos })}\n`)
}

async function procesarMensaje(mensaje) {
  const envoltura = JSON.parse(mensaje.Body || "{}")
  const evento = JSON.parse(envoltura.Message || mensaje.Body || "{}")
  const datos = evento.datos || {}
  const contenido = await generarDocumento(datos)
  const clave = `citas/${datos.pacienteId || "general"}/${datos.id || mensaje.MessageId}.pdf`
  await s3.send(new PutObjectCommand({ Bucket: balde, Key: clave, Body: contenido, ContentType: "application/pdf", ServerSideEncryption: "AES256" }))
  await sqs.send(new DeleteMessageCommand({ QueueUrl: colaUrl, ReceiptHandle: mensaje.ReceiptHandle }))
  registrar("INFO", "Documento generado", { clave, citaId: datos.id })
}

async function ejecutar() {
  if (!colaUrl || !balde) throw new Error("COLADOCUMENTOSURL y BALDEDOCUMENTOS son obligatorios")
  registrar("INFO", "Trabajador iniciado", { colaUrl, balde })
  while (true) {
    const respuesta = await sqs.send(new ReceiveMessageCommand({ QueueUrl: colaUrl, MaxNumberOfMessages: 5, WaitTimeSeconds: 20, VisibilityTimeout: 60 }))
    for (const mensaje of respuesta.Messages || []) {
      try {
        await procesarMensaje(mensaje)
      } catch (error) {
        registrar("ERROR", "No fue posible generar el documento", { error: error.message, mensajeId: mensaje.MessageId })
      }
    }
  }
}

if (process.env.NODEENV !== "prueba") ejecutar().catch(error => {
  registrar("ERROR", "El trabajador se detuvo", { error: error.message })
  process.exit(1)
})
