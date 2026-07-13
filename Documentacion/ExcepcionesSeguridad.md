# Excepciones de seguridad controladas

Checkov se ejecuta en modo estricto. Las excepciones configuradas no desactivan el análisis general; representan decisiones arquitectónicas documentadas para evitar controles incompatibles, costos desproporcionados o duplicidad de mecanismos.

## Red privada entre API Gateway y ALB

El enlace desde API Gateway al ALB usa VPC Link dentro de subredes privadas y grupos de seguridad limitados. El cifrado público termina en API Gateway. Por este motivo, el tramo interno usa HTTP y se exceptúan los controles que obligan HTTPS en listener y target groups internos.

Controles: `CKV2_AWS_20`, `CKV_AWS_2`, `CKV_AWS_103`, `CKV_AWS_378`.

## Rutas públicas deliberadas

La consulta de especialistas, horarios y comprobaciones de salud es pública. Las operaciones de pacientes y citas usan JWT de Cognito. La inicialización pública exige una clave aleatoria almacenada en Secrets Manager y debe deshabilitarse después de cargar los datos iniciales.

Control: `CKV_AWS_309`.

## Lambda activada por SQS

La función recibe mensajes desde una cola cifrada que ya posee cola de mensajes muertos y política de reintentos. No se añade otra DLQ a nivel de función. La función no necesita acceso a recursos privados por dirección IP y se mantiene fuera de la VPC para reducir latencia de arranque. El firmado de código queda como control de una fase regulada posterior.

Controles: `CKV_AWS_116`, `CKV_AWS_117`, `CKV_AWS_272`.

## OpenSearch bajo costo controlado

OpenSearch se ejecuta dentro de subredes de datos, con cifrado, HTTPS, seguridad avanzada y auditoría. Los nodos maestros dedicados se reservan para producción de alta criticidad porque incrementan significativamente el costo fijo.

Controles: `CKV2_AWS_59`, `CKV_AWS_318`.

## S3 y distribución global

Los baldes son privados, versionados, cifrados y poseen reglas de ciclo de vida. La replicación entre regiones, las notificaciones en todos los baldes y el acceso de registro recursivo no se aplican de forma universal. El balde de registros conserva ACL exclusivamente por compatibilidad con la entrega estándar de registros de CloudFront y ALB.

Controles: `CKV2_AWS_62`, `CKV2_AWS_65`, `CKV_AWS_18`, `CKV_AWS_144`, `CKV_AWS_145`.

## CloudFront de una sola región de origen

El frontend estático usa versionado, restauración desde S3 y despliegue automatizado. No se crea un segundo origen regional ni una restricción geográfica porque la plataforma debe estar disponible para pacientes que se encuentren fuera del país.

Controles: `CKV_AWS_310`, `CKV_AWS_374`.

## Secretos y rotación

Secrets Manager protege las claves con KMS. La rotación automática del token de Redis y de la clave de inicialización requiere coordinación con las tareas en ejecución; se maneja como una operación de mantenimiento para evitar cortes por una rotación no sincronizada.

Control: `CKV2_AWS_57`.

## Políticas KMS

Las políticas de las llaves KMS incluyen el recurso `*` porque una política de llave siempre describe permisos sobre la propia llave. Los principales están restringidos a la cuenta y a servicios concretos. Los analizadores genéricos interpretan este patrón obligatorio como permiso sin restricción.

Controles: `CKV2_AWS_64`, `CKV_AWS_109`, `CKV_AWS_111`, `CKV_AWS_356`.

## Dirección elástica del NAT Gateway

La dirección elástica se vincula al NAT Gateway mediante una referencia condicional de Terraform. El análisis de grafo no siempre resuelve la relación cuando el recurso usa `count`.

Control: `CKV2_AWS_19`.
