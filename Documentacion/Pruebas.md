# Plan de pruebas

## Pruebas automatizadas

```bash
npm test
```

Las pruebas verifican:

- Listado de especialistas.
- Validación del registro de pacientes.
- Registro de citas.
- Consulta de citas por paciente.
- Bloqueo de reservas duplicadas.
- Generación de documentos PDF.

## Pruebas de humo

```bash
bash Automatizacion/PruebasHumo.sh
```

El script verifica:

- Disponibilidad del frontend.
- Salud de ServicioPersonas.
- Salud de ServicioCitas.
- Existencia de especialistas iniciales.

## Prueba de mensajería

1. Registrar una cita.
2. Verificar el incremento de mensajes enviados al tema SNS.
3. Verificar que la cola de notificaciones quede sin mensajes visibles.
4. Consultar la tabla de notificaciones.
5. Verificar la creación del PDF en el balde de documentos.
6. Confirmar que las colas de mensajes muertos permanezcan vacías.

## Prueba de escalabilidad

1. Ejecutar solicitudes sostenidas al endpoint `/citas/carga`.
2. Observar la utilización de CPU en CloudWatch o Grafana.
3. Confirmar el aumento del número deseado de tareas ECS.
4. Detener la carga.
5. Confirmar la reducción gradual de tareas después del periodo de estabilización.

## Prueba de recuperación

1. Detener una tarea ECS.
2. Confirmar que ECS cree una sustituta.
3. Publicar una revisión defectuosa en un ambiente controlado.
4. Ejecutar `Automatizacion/Reversion.sh`.
5. Confirmar que el servicio vuelva a la definición de tarea anterior.

## Prueba de seguridad

1. Cambiar temporalmente una regla de seguridad para exponer un puerto administrativo.
2. Ejecutar Checkov.
3. Generar un plan de Terraform en formato JSON.
4. Evaluarlo con Conftest y las políticas OPA.
5. Confirmar que la automatización rechace el cambio.
