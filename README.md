# DermaNube

DermaNube es una plataforma web para la gestión de evaluaciones dermatológicas, especialistas, citas y procesos asíncronos. El repositorio integra aplicación, contenedores, infraestructura como código, automatización, seguridad, mensajería y observabilidad.

## Capacidades

- Portal web adaptable para pacientes.
- Búsqueda de especialistas por especialidad y sede.
- Reserva y cancelación de citas.
- Prevención de reservas duplicadas mediante escritura transaccional.
- Autenticación con Amazon Cognito.
- Frontend privado en Amazon S3 distribuido por CloudFront.
- Protección perimetral con AWS WAF.
- API Gateway conectado a un ALB interno mediante VPC Link.
- Microservicios en Amazon ECS Fargate.
- Descubrimiento interno con AWS Cloud Map.
- Persistencia en Amazon DynamoDB.
- Caché de horarios en Amazon ElastiCache para Redis.
- Búsqueda de especialistas mediante Amazon OpenSearch.
- Eventos FIFO con Amazon SNS y Amazon SQS.
- Procesamiento de notificaciones con AWS Lambda.
- Generación de documentos mediante un trabajador desplegable en Amazon EKS.
- Imágenes inmutables en Amazon ECR.
- Autoescalado de servicios y trabajadores.
- Métricas con Prometheus, tableros con Grafana y registros con Loki.
- Auditoría con AWS CloudTrail.
- Gestión de secretos con AWS Secrets Manager.
- Respaldo con AWS Backup.
- Control financiero con AWS Budgets.
- Integración continua con GitHub Actions.
- Despliegue continuo con Jenkins.
- Aprovisionamiento con Terraform y configuración con Ansible.
- Análisis de infraestructura con Checkov y políticas OPA.
- Análisis de código con SonarQube.

![Diagrama de Dermanube](https://github.com/kristelriveracabeza-bit/DermaNube-desarrollo/blob/96bab7ec86a13306eee7644af788841696d6beac/Diagrama%20de%20Dermanube.png?raw=true)
El sistema "Dermanube" comienza cuando el paciente ingresa la dirección web; en ese momento interviene Route53, que funciona como el directorio telefónico de internet traduciendo el nombre del dominio para conectar al usuario. Esta conexión pasa primero por un WAF (Web Application Firewall), un escudo de seguridad que bloquea tráfico malicioso y previene ataques cibernéticos, para luego llegar a CloudFront, una red de distribución global que acelera la carga de la página web entregando el contenido desde el servidor más cercano al usuario. Los archivos visuales de esta página web están almacenados de forma segura e inalterable en un repositorio llamado Central S3. Una vez que el paciente interactúa con la página (por ejemplo, para iniciar sesión o buscar citas), sus peticiones pasan por el API Gateway, que actúa como la puerta principal de comunicación, validando primero su identidad y permisos de acceso mediante Cognito, el cual gestiona los registros y contraseñas de forma segura. Con el acceso aprobado, un ALB (Application Load Balancer) actúa como un director de tráfico, distribuyendo las peticiones de manera equitativa para que ningún servidor se sature.

Este tráfico llega al corazón del sistema, donde la lógica de la clínica se ejecuta dentro de contenedores orquestados por ECS (para servicios más sencillos) y EKS (Kubernetes, para microservicios más complejos), los cuales utilizan CloudMap como un mapa interno para que los distintos microservicios puedan descubrirse y hablar entre sí. Aquí operan el Servicio de Personas y el Servicio de Citas. Para responder de manera ultra rápida sobre qué horarios están libres, el sistema consulta Redis, una memoria caché que almacena los datos de uso más frecuente temporalmente. Para guardar la información permanente de perfiles y reservas, se utiliza DynamoDB, una base de datos altamente escalable y rápida, apoyada por OpenSearch, un motor que permite realizar búsquedas complejas (como buscar el historial de un paciente específico en milisegundos). Las imágenes médicas, como fotos de afecciones dermatológicas, se guardan en S3 Documentos, mientras que AWS Backup toma fotografías diarias de todas estas bases de datos para garantizar que jamás se pierda información clínica vital.

Cuando el paciente finalmente confirma su reserva, el sistema no lo hace esperar mientras procesa todo internamente; en su lugar, utiliza un modelo orientado a eventos. El servicio emite un aviso a través de SNS, un megáfono virtual que notifica al resto del sistema que hay una nueva cita. Este mensaje es recibido por SQS, un sistema de colas de espera que organiza las tareas pendientes para que no se pierdan. Una cola procesa la documentación (como actualizar expedientes o generar boletas), mientras que otra cola despierta a Lambda, un servicio de código que se ejecuta solo por unos segundos con el propósito específico de enviar un correo electrónico o SMS de confirmación al paciente, apagándose inmediatamente después para ahorrar costos.

Detrás de escena, la creación de este software sigue un flujo automatizado para evitar errores humanos. Los desarrolladores guardan su código en GitHub, lo que detona automáticamente a GitHub Actions, un robot ensamblador que toma ese código y lo somete a estrictas pruebas de calidad usando SonarQube (que revisa si el código está bien escrito) y Checkov (que asegura que la infraestructura no tenga huecos de seguridad). El software aprobado se empaqueta y se guarda en ECR, un almacén seguro para aplicaciones listas para usarse. Para poner estas aplicaciones a funcionar en la nube, el equipo usa Jenkins como el director de la orquesta de despliegue, apoyándose en Terraform para crear los servidores y redes mediante código, y en Ansible para configurar el software dentro de esos servidores.

Finalmente, para que el sistema médico nunca colapse, el equipo de operaciones vigila todo con herramientas de observabilidad: Prometheus toma los signos vitales midiendo el rendimiento de los servidores (como uso de CPU y memoria), Loki recolecta los diarios de actividad (logs) de cada error o proceso, y Grafana traduce todos estos datos en tableros visuales y gráficos fáciles de interpretar. Por razones legales y de auditoría, CloudTrail graba cada clic y cambio en la configuración de la infraestructura, guardando estas grabaciones en S3 Auditoría. Todo este ecosistema tecnológico es monitoreado financieramente por AWS Budgets, una alarma que avisa a los administradores si los costos de mantener la plataforma en la nube están excediendo el presupuesto mensual de la clínica.
## Estructura

```text
Aplicacion/
  Frontend/
  ServicioPersonas/
  ServicioCitas/
  ProcesadorNotificaciones/
  TrabajadorDocumentos/
Automatizacion/
Documentacion/
Infraestructura/
  Ansible/
  Kubernetes/
  Terraform/
Observabilidad/
Politicas/
.github/workflows/
```

## Ejecución local

Requisitos:

- Docker con Docker Compose.
- Al menos 6 GB de memoria libre para el stack completo.

Levantar la aplicación y observabilidad:

```bash
docker compose up -d --build
```

Abrir:

- Aplicación: `http://localhost:8080`
- Grafana: `http://localhost:3000`
- Prometheus: `http://localhost:9090`
- Loki: `http://localhost:3100/ready`
- Alloy: `http://localhost:12345`

La clave local inicial de Grafana se define con `CLAVEGRAFANA`. Cuando no se proporciona, se usa `DermaNubeLocal2026`.

Levantar SonarQube:

```bash
docker compose --profile calidad up -d sonarqube
```

Levantar Jenkins local:

```bash
docker compose --profile automatizacion up -d jenkins
```

## Pruebas

```bash
npm install
```

```bash
npm test
```

## Despliegue AWS

La guía completa se encuentra en [Documentacion/DespliegueAWS.md](Documentacion/DespliegueAWS.md).

Orden resumido:

```bash
bash Automatizacion/VerificarHerramientas.sh
```

```bash
bash Automatizacion/CrearEstado.sh
```

```bash
bash Automatizacion/DesplegarBase.sh
```

```bash
bash Automatizacion/PublicarImagenes.sh
```

```bash
bash Automatizacion/ActivarServicios.sh
```

```bash
bash Automatizacion/PublicarFrontend.sh
```

```bash
bash Automatizacion/InicializarDatos.sh
```

```bash
bash Automatizacion/PruebasHumo.sh
```

## Seguridad

- Los baldes de S3 permanecen privados.
- CloudFront accede al frontend mediante Origin Access Control.
- La API se integra con un ALB interno.
- Las tareas se ejecutan en subredes privadas.
- Las tablas y colas usan cifrado administrado.
- Redis usa cifrado en tránsito, cifrado en reposo y autenticación.
- OpenSearch usa HTTPS y cifrado entre nodos.
- Cognito protege las operaciones privadas.
- GitHub Actions usa OIDC y credenciales temporales.
- CloudTrail registra operaciones administrativas y eventos de datos seleccionados.
- Checkov y OPA detienen configuraciones inseguras antes del despliegue.
- Las excepciones controladas se documentan en [Documentacion/ExcepcionesSeguridad.md](Documentacion/ExcepcionesSeguridad.md).

## Costos

El modo completo crea recursos con cobro por hora, entre ellos NAT Gateway, OpenSearch, ElastiCache, ECS, EKS y componentes administrados de observabilidad. Antes de desplegar, revisar [Documentacion/Costos.md](Documentacion/Costos.md) y definir un presupuesto mensual.

## Licencia

MIT
