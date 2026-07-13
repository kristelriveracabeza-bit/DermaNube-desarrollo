# Arquitectura de DermaNube

## Flujo de entrega

1. Un cambio se publica en GitHub.
2. GitHub Actions instala dependencias y ejecuta pruebas.
3. SonarQube analiza calidad, vulnerabilidades y mantenibilidad.
4. Checkov analiza Terraform, Docker y flujos de automatización.
5. OPA evalúa las políticas definidas para la infraestructura.
6. Las imágenes se construyen con Docker.
7. Las imágenes se publican en Amazon ECR con la etiqueta del commit.
8. Jenkins realiza el despliegue controlado.
9. Terraform crea o actualiza los recursos de AWS.
10. Ansible configura el nodo de automatización.
11. ECS actualiza los microservicios sin retirar las tareas saludables antes de tiempo.
12. EKS actualiza el trabajador de documentos y valida el despliegue.
13. Las pruebas de humo verifican el frontend, los microservicios y los datos iniciales.
14. Un fallo activa el procedimiento de reversión.

## Flujo de una cita

1. El paciente abre el frontend desde CloudFront.
2. AWS WAF inspecciona la solicitud.
3. Los archivos estáticos se recuperan desde un balde S3 privado.
4. El paciente inicia sesión mediante Cognito.
5. La aplicación consulta especialistas a través de API Gateway.
6. API Gateway conecta con el ALB interno mediante VPC Link.
7. El ALB dirige la solicitud al ServicioPersonas.
8. El servicio recupera perfiles desde DynamoDB y puede usar OpenSearch para búsquedas de texto.
9. El paciente consulta horarios.
10. ServicioCitas verifica la caché Redis.
11. Al confirmar, una transacción de DynamoDB crea el bloqueo del horario y la cita.
12. ServicioCitas publica el evento CitaCreada en un tema SNS FIFO.
13. SNS distribuye el evento hacia las colas de notificaciones y documentos.
14. Lambda registra el procesamiento de la notificación.
15. El trabajador de EKS genera un PDF y lo almacena en S3.
16. Prometheus recopila métricas y Grafana las presenta.
17. Alloy envía los registros a Loki para correlación y diagnóstico.

## Responsabilidad de las plataformas de contenedores

Amazon ECS ejecuta los microservicios HTTP permanentes. Amazon EKS ejecuta trabajadores asíncronos, tareas programadas y componentes que aprovechan capacidades de Kubernetes. Las dos plataformas no duplican la misma carga.

## Resiliencia

- Dos zonas de disponibilidad.
- Dos tareas por servicio en producción.
- Autoescalado por utilización de CPU.
- ElastiCache con réplica y conmutación automática.
- OpenSearch distribuido en dos zonas.
- Colas de mensajes con cola de mensajes muertos.
- DynamoDB con recuperación a un punto en el tiempo.
- AWS Backup para copias programadas.
- Despliegues de ECS con mínimo saludable del cien por ciento.
- Reversión a la definición de tarea anterior.

## Separación de responsabilidades

- Terraform crea recursos de nube.
- Ansible configura sistemas operativos y herramientas.
- GitHub Actions realiza integración continua.
- Jenkins realiza despliegue continuo.
- SonarQube evalúa el código.
- Checkov evalúa la infraestructura.
- OPA aplica reglas organizacionales.
- Prometheus almacena métricas.
- Loki almacena registros.
- Grafana correlaciona y visualiza las señales.
