import { SNSClient, PublishCommand } from "@aws-sdk/client-sns"
import { registrar } from "./Registro.js"

export async function publicarEvento(tipo, datos) {
  if (!process.env.TEMAEVENTOSARN) {
    registrar("INFO", "Evento procesado en modo local", { tipo, datos })
    return
  }
  const cliente = new SNSClient({ region: process.env.REGIONAWS || "us-east-1" })
  await cliente.send(new PublishCommand({
    TopicArn: process.env.TEMAEVENTOSARN,
    Message: JSON.stringify({ tipo, fecha: new Date().toISOString(), datos }),
    MessageAttributes: { tipo: { DataType: "String", StringValue: tipo } },
    MessageGroupId: datos.pacienteId || "DermaNube",
    MessageDeduplicationId: `${tipo}-${datos.id}-${Date.now()}`
  }))
}
