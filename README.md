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

## Arquitectura

```mermaid
flowchart TB
    Desarrollador --> GitHub
    GitHub --> GitHubActions
    GitHubActions --> SonarQube
    GitHubActions --> Checkov
    GitHubActions --> ECR
    GitHubActions --> Jenkins
    Jenkins --> Terraform
    Jenkins --> Ansible
    Jenkins --> ECS
    Jenkins --> EKS

    Usuario --> Route53
    Route53 --> WAF
    WAF --> CloudFront
    CloudFront --> S3
    Usuario --> ApiGateway
    ApiGateway --> Cognito
    ApiGateway --> ALB
    ALB --> ServicioPersonas
    ALB --> ServicioCitas
    ServicioPersonas --> DynamoDB
    ServicioPersonas --> OpenSearch
    ServicioCitas --> DynamoDB
    ServicioCitas --> Redis
    ServicioCitas --> SNS
    SNS --> SQSNotificaciones
    SNS --> SQSDocumentos
    SQSNotificaciones --> Lambda
    SQSDocumentos --> EKS
    EKS --> S3Documentos
    ECS --> CloudMap
    ECS --> Prometheus
    EKS --> Prometheus
    Prometheus --> Grafana
    ECS --> Loki
    EKS --> Loki
    Loki --> Grafana
    CloudTrail --> S3Auditoria
    AWSBackup --> DynamoDB
    AWSBudgets --> EquipoOperaciones
```

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