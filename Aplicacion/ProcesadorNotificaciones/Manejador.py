import json
import os
from datetime import datetime, timezone

import boto3

cliente = boto3.resource("dynamodb")
tabla = cliente.Table(os.environ.get("TABLANOTIFICACIONES", "DermaNubeNotificaciones"))


def procesar(evento, contexto):
    procesados = 0
    for registro in evento.get("Records", []):
        cuerpo = json.loads(registro.get("body", "{}"))
        mensaje = json.loads(cuerpo.get("Message", "{}")) if "Message" in cuerpo else cuerpo
        datos = mensaje.get("datos", {})
        identificador = f"NOT{registro.get('messageId', procesados)}"
        elemento = {
            "id": identificador,
            "tipo": mensaje.get("tipo", "Evento"),
            "pacienteId": datos.get("pacienteId", "SinPaciente"),
            "citaId": datos.get("id", "SinCita"),
            "estado": "Procesada",
            "canal": "Correo",
            "creadaEn": datetime.now(timezone.utc).isoformat()
        }
        tabla.put_item(Item=elemento)
        print(json.dumps({"nivel": "INFO", "servicio": "ProcesadorNotificaciones", "mensaje": "Notificación procesada", "notificacionId": identificador}))
        procesados += 1
    return {"procesados": procesados}
