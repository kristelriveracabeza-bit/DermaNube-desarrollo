import { DynamoDBClient } from "@aws-sdk/client-dynamodb"
import { DynamoDBDocumentClient, GetCommand, PutCommand, ScanCommand } from "@aws-sdk/lib-dynamodb"
import { Client } from "@opensearch-project/opensearch"
import { AwsSigv4Signer } from "@opensearch-project/opensearch/aws"
import { fromNodeProviderChain } from "@aws-sdk/credential-providers"
import { especialistasIniciales } from "./DatosIniciales.js"
import { registrar } from "./Registro.js"

const memoria = new Map(especialistasIniciales.map(item => [item.id, structuredClone(item)]))

function usarAws() {
  return process.env.MODOALMACENAMIENTO === "aws"
}

function clienteDynamo() {
  const configuracion = { region: process.env.REGIONAWS || "us-east-1" }
  if (process.env.ENDPOINTDYNAMO) configuracion.endpoint = process.env.ENDPOINTDYNAMO
  return DynamoDBDocumentClient.from(new DynamoDBClient(configuracion), { marshallOptions: { removeUndefinedValues: true } })
}

function clienteBusqueda() {
  if (!process.env.ENDPOINTOPENSEARCH) return null
  return new Client({
    ...AwsSigv4Signer({
      region: process.env.REGIONAWS || "us-east-1",
      service: "es",
      getCredentials: () => fromNodeProviderChain()()
    }),
    node: process.env.ENDPOINTOPENSEARCH.startsWith("http") ? process.env.ENDPOINTOPENSEARCH : `https://${process.env.ENDPOINTOPENSEARCH}`
  })
}


async function asegurarIndiceBusqueda(busqueda) {
  const respuesta = await busqueda.indices.exists({ index: "especialistas" })
  const existe = typeof respuesta === "boolean" ? respuesta : Boolean(respuesta.body)
  if (existe) return
  await busqueda.indices.create({
    index: "especialistas",
    body: {
      mappings: {
        properties: {
          id: { type: "keyword" },
          nombre: { type: "text", fields: { keyword: { type: "keyword" } } },
          especialidad: { type: "text", fields: { keyword: { type: "keyword" } } },
          sede: { type: "text", fields: { keyword: { type: "keyword" } } },
          resumen: { type: "text" },
          disponible: { type: "boolean" }
        }
      }
    }
  })
}

async function indexarEspecialista(especialista) {
  const busqueda = clienteBusqueda()
  if (!busqueda) return
  try {
    await asegurarIndiceBusqueda(busqueda)
    await busqueda.index({ index: "especialistas", id: especialista.id, body: especialista, refresh: true })
  } catch (error) {
    registrar("WARN", "No fue posible indexar especialista", { especialistaId: especialista.id, error: error.message })
  }
}

export async function listarEspecialistas(filtros = {}) {
  const termino = String(filtros.termino || "").trim().toLowerCase()
  const especialidad = String(filtros.especialidad || "").trim()
  const busqueda = clienteBusqueda()
  if (usarAws() && busqueda && termino) {
    try {
      const respuesta = await busqueda.search({
        index: "especialistas",
        body: {
          size: 30,
          query: {
            bool: {
              must: [{ multi_match: { query: termino, fields: ["nombre^3", "especialidad^2", "sede", "resumen"] } }],
              filter: especialidad ? [{ term: { "especialidad.keyword": especialidad } }] : []
            }
          }
        }
      })
      const contenido = respuesta.body || respuesta
      return contenido.hits.hits.map(item => item._source)
    } catch (error) {
      registrar("WARN", "La búsqueda avanzada no estuvo disponible", { error: error.message })
    }
  }
  let elementos
  if (usarAws()) {
    const respuesta = await clienteDynamo().send(new ScanCommand({
      TableName: process.env.TABLAPERSONAS,
      FilterExpression: "#tipo = :tipo",
      ExpressionAttributeNames: { "#tipo": "tipo" },
      ExpressionAttributeValues: { ":tipo": "Especialista" }
    }))
    elementos = respuesta.Items || []
  } else {
    elementos = [...memoria.values()].filter(item => item.tipo === "Especialista")
  }
  return elementos.filter(item => {
    const texto = `${item.nombre} ${item.especialidad} ${item.sede} ${item.resumen}`.toLowerCase()
    return (!termino || texto.includes(termino)) && (!especialidad || item.especialidad === especialidad)
  })
}

export async function obtenerPersona(id) {
  if (!usarAws()) return memoria.get(id) || null
  const respuesta = await clienteDynamo().send(new GetCommand({ TableName: process.env.TABLAPERSONAS, Key: { id } }))
  return respuesta.Item || null
}

export async function guardarPersona(persona) {
  if (!usarAws()) {
    memoria.set(persona.id, structuredClone(persona))
    return persona
  }
  await clienteDynamo().send(new PutCommand({ TableName: process.env.TABLAPERSONAS, Item: persona, ConditionExpression: "attribute_not_exists(id)" }))
  if (persona.tipo === "Especialista") await indexarEspecialista(persona)
  return persona
}

export async function inicializarEspecialistas() {
  if (!usarAws()) return especialistasIniciales
  for (const especialista of especialistasIniciales) {
    await clienteDynamo().send(new PutCommand({ TableName: process.env.TABLAPERSONAS, Item: especialista }))
    await indexarEspecialista(especialista)
  }
  return especialistasIniciales
}
