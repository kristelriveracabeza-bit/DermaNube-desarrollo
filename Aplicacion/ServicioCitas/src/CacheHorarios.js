import { createClient } from "redis"

let cliente
const memoria = new Map()

async function obtenerCliente() {
  if (!process.env.ENDPOINTREDIS) return null
  if (!cliente) {
    cliente = createClient({
      socket: { host: process.env.ENDPOINTREDIS, port: Number(process.env.PUERTOREDIS || 6379), tls: process.env.REDISTLS === "true" },
      password: process.env.CLAVEREDIS || undefined
    })
    cliente.on("error", () => {})
    await cliente.connect()
  }
  return cliente
}

export async function obtenerCache(clave) {
  const redis = await obtenerCliente().catch(() => null)
  if (redis) {
    const valor = await redis.get(clave)
    return valor ? JSON.parse(valor) : null
  }
  const elemento = memoria.get(clave)
  if (!elemento || elemento.expira < Date.now()) return null
  return elemento.valor
}

export async function guardarCache(clave, valor, segundos = 120) {
  const redis = await obtenerCliente().catch(() => null)
  if (redis) return redis.set(clave, JSON.stringify(valor), { EX: segundos })
  memoria.set(clave, { valor, expira: Date.now() + segundos * 1000 })
}

export async function eliminarCache(clave) {
  const redis = await obtenerCliente().catch(() => null)
  if (redis) return redis.del(clave)
  memoria.delete(clave)
}
