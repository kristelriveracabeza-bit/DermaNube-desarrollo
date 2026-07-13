import { crearAplicacion } from "./Aplicacion.js"
import { registrar } from "./Registro.js"

const puerto = Number(process.env.PUERTO || 3001)
const aplicacion = crearAplicacion()

aplicacion.listen(puerto, "0.0.0.0", () => registrar("INFO", "Servicio iniciado", { puerto }))
