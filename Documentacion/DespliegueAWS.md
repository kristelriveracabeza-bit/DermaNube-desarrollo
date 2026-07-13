# Despliegue de DermaNube en AWS

Esta guía parte de una cuenta AWS con permisos administrativos temporales para crear la infraestructura inicial. Después del primer despliegue se recomienda reducir los permisos y operar mediante los roles de GitHub Actions y Jenkins.

## 1. Herramientas

Instalar y comprobar:

- Git.
- Docker Desktop con Docker Compose.
- AWS CLI versión 2.
- Terraform.
- jq.
- curl.
- kubectl cuando se habilite EKS.
- Ansible cuando se habilite Jenkins en EC2.

En Git Bash, abrir el directorio del proyecto:

```bash
cd /ruta/DermaNube
```

Comprobar las herramientas:

```bash
bash Automatizacion/VerificarHerramientas.sh
```

## 2. Credenciales AWS

Configurar un perfil temporal:

```bash
aws configure
```

Ingresar:

```text
AWS Access Key ID: valor temporal
AWS Secret Access Key: valor temporal
Default region name: us-east-1
Default output format: json
```

Comprobar la identidad:

```bash
aws sts get-caller-identity
```

No guardar credenciales en el repositorio, archivos Terraform, GitHub Actions o Jenkinsfile.

## 3. Repositorio GitHub

Crear un repositorio vacío y publicar el proyecto:

```bash
git init
```

```bash
git add .
```

```bash
git commit -m "Inicializar DermaNube"
```

```bash
git branch -M main
```

```bash
git remote add origin URLDELREPOSITORIO
```

```bash
git push -u origin main
```

## 4. Estado remoto de Terraform

Definir la región:

```bash
export REGIONAWS=us-east-1
```

Crear el balde de estado y la tabla de bloqueo:

```bash
bash Automatizacion/CrearEstado.sh
```

El script genera:

```text
Infraestructura/Terraform/Principal/Backend.hcl
```

Ese archivo no se publica en GitHub.

## 5. Variables principales

Copiar el archivo de ejemplo:

```bash
cp Infraestructura/Terraform/Principal/terraform.tfvars.ejemplo Infraestructura/Terraform/Principal/terraform.tfvars
```

Abrirlo:

```bash
code Infraestructura/Terraform/Principal/terraform.tfvars
```

Configurar al menos:

```hcl
RegionAws            = "us-east-1"
CorreoPresupuesto    = "correo@dominio.com"
LimitePresupuestoUsd = 80
RepositorioGithub    = "usuario/repositorio"
```

Para comenzar con menor costo:

```hcl
CrearCache                  = false
CrearBusqueda               = false
CrearEks                    = false
CrearJenkins                = false
CrearPrometheusAdministrado = false
CrearGrafanaAdministrado    = false
CapacidadMinimaServicios    = 1
CapacidadMaximaServicios    = 2
```

Para la arquitectura completa:

```hcl
CrearCache                  = true
CrearBusqueda               = true
CrearEks                    = true
CrearJenkins                = true
CrearPrometheusAdministrado = true
CrearGrafanaAdministrado    = true
CapacidadMinimaServicios    = 2
CapacidadMaximaServicios    = 6
```

Cuando se use Jenkins en EC2, generar una llave:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/DermaNube -C DermaNube
```

Ver la llave pública:

```bash
cat ~/.ssh/DermaNube.pub
```

Copiar su contenido en:

```hcl
LlaveSshPublica = "ssh-ed25519 CONTENIDO"
```

Restringir el acceso administrativo a la IP pública actual:

```bash
curl https://checkip.amazonaws.com
```

Configurar:

```hcl
CidrAdministracion = "IPOBTENIDA/32"
```

No dejar `0.0.0.0/0` para SSH, Jenkins o Grafana.

## 6. Dominio opcional

La plataforma funciona con el dominio de CloudFront sin comprar un dominio.

Cuando exista un dominio administrado en Route 53, definir:

```hcl
Dominio         = "derma.dominio.com"
IdZonaHospedada = "ZONAID"
```

Terraform solicitará el certificado, creará la validación DNS y asociará el dominio con CloudFront.

## 7. Infraestructura base

Ejecutar:

```bash
bash Automatizacion/DesplegarBase.sh
```

La primera ejecución crea el archivo `terraform.tfvars` cuando no existe y se detiene para que pueda revisarse.

Después de revisar el archivo, ejecutar nuevamente:

```bash
bash Automatizacion/DesplegarBase.sh
```

Revisar el plan antes de confirmar la aplicación.

La base crea:

- VPC y subredes en dos zonas.
- Rutas, Internet Gateway y NAT Gateway cuando está habilitado.
- Security Groups.
- S3, CloudFront y WAF.
- Cognito.
- API Gateway y VPC Link.
- ALB interno.
- ECR.
- ECS.
- DynamoDB.
- SNS, SQS, Lambda y colas muertas.
- CloudTrail.
- Secrets Manager.
- AWS Backup.
- AWS Budgets.
- ElastiCache, OpenSearch, EKS, Jenkins y observabilidad administrada cuando están habilitados.

Los servicios ECS todavía no se crean porque ECR aún no contiene imágenes.

## 8. Imágenes Docker

Publicar las tres imágenes:

```bash
bash Automatizacion/PublicarImagenes.sh
```

El script:

1. Obtiene los repositorios desde Terraform.
2. Inicia sesión en Amazon ECR.
3. Construye ServicioPersonas.
4. Construye ServicioCitas.
5. Construye TrabajadorDocumentos.
6. Publica las imágenes con una etiqueta inmutable.
7. Genera `Imagenes.auto.tfvars.json`.

## 9. Servicios ECS

Activar los microservicios:

```bash
bash Automatizacion/ActivarServicios.sh
```

Comprobar el clúster:

```bash
aws ecs list-services --cluster DermaNubeProduccionCluster --region us-east-1
```

Comprobar tareas:

```bash
aws ecs list-tasks --cluster DermaNubeProduccionCluster --region us-east-1
```

## 10. Frontend

Publicar la web:

```bash
bash Automatizacion/PublicarFrontend.sh
```

El script genera la configuración pública con:

- URL de API Gateway.
- Identificador del grupo de Cognito.
- Identificador del cliente web.
- Dominio de acceso de Cognito.
- URL de retorno.

Luego sincroniza los archivos con S3 e invalida la caché de CloudFront.

Mostrar la URL:

```bash
terraform -chdir=Infraestructura/Terraform/Principal output -raw UrlFrontend
```

## 11. Datos iniciales

Esperar hasta que ambos servicios ECS aparezcan saludables.

Inicializar especialistas:

```bash
bash Automatizacion/InicializarDatos.sh
```

Comprobar la lista:

```bash
URLAPI=$(terraform -chdir=Infraestructura/Terraform/Principal output -raw UrlApi)
```

```bash
curl "$URLAPI/personas/especialistas"
```

## 12. Pruebas de humo

Ejecutar:

```bash
bash Automatizacion/PruebasHumo.sh
```

La respuesta correcta es:

```text
Pruebas de humo superadas
```

## 13. EKS

Confirmar que `CrearEks` sea `true` y que `ImagenTrabajadorDocumentos` haya sido escrita por el script de imágenes.

Aplicar la infraestructura si EKS se activó después:

```bash
terraform -chdir=Infraestructura/Terraform/Principal plan -out=plan.tfplan
```

```bash
terraform -chdir=Infraestructura/Terraform/Principal apply plan.tfplan
```

Definir la etiqueta utilizada:

```bash
export ETIQUETAIMAGEN=ETIQUETADELAIMAGEN
```

Desplegar el trabajador:

```bash
bash Automatizacion/PrepararKubernetes.sh
```

Verificar:

```bash
kubectl get pods -n dermanube
```

```bash
kubectl get hpa -n dermanube
```

## 14. Jenkins y Ansible

Confirmar que `CrearJenkins` sea `true` y que exista una llave pública.

Mostrar la IP:

```bash
terraform -chdir=Infraestructura/Terraform/Principal output -raw JenkinsIp
```

Copiar el inventario:

```bash
cp Infraestructura/Ansible/Inventarios/Produccion.ejemplo.ini Infraestructura/Ansible/Inventarios/Produccion.ini
```

Editar IP y ruta de llave:

```bash
code Infraestructura/Ansible/Inventarios/Produccion.ini
```

Probar conexión:

```bash
cd Infraestructura/Ansible
```

```bash
ansible automatizacion -m ping
```

Configurar el servidor:

```bash
ansible-playbook Playbooks/ConfigurarAutomatizacion.yml
```

Obtener la clave inicial de Jenkins:

```bash
ssh -i ~/.ssh/DermaNube ubuntu@IPJENKINS "sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
```

Abrir:

```text
http://IPJENKINS:8080
```

Instalar los complementos sugeridos y agregar:

- Pipeline.
- Git.
- GitHub Integration.
- Docker Pipeline.
- Credentials Binding.
- Pipeline Utility Steps.

Crear estas credenciales en Jenkins:

```text
RegionAws
CuentaAws
BackendTerraform
VariablesTerraform
```

`BackendTerraform` debe ser una credencial de archivo secreto con el contenido del `Backend.hcl` generado por `CrearEstado.sh`.

`VariablesTerraform` debe ser una credencial de archivo secreto con el contenido del `terraform.tfvars` usado para crear el ambiente. Jenkins copia ambos archivos únicamente durante el despliegue y los elimina al finalizar.

Crear un trabajo Pipeline desde SCM y seleccionar el `Jenkinsfile` del repositorio.

## 15. GitHub Actions con OIDC

Obtener el rol:

```bash
terraform -chdir=Infraestructura/Terraform/Principal output -raw RolGithubActionsArn
```

En GitHub abrir:

```text
Settings → Secrets and variables → Actions
```

Crear:

```text
AWSROLEARN
AWSREGION
SONARTOKEN
SONARHOSTURL
JENKINSURL
JENKINSTOKEN
```

`AWSROLEARN` contiene el rol creado por Terraform. No crear secretos con claves AWS permanentes.

## 16. SonarQube

Para una validación local:

```bash
docker compose --profile calidad up -d sonarqube
```

Abrir:

```text
http://localhost:9000
```

Crear el proyecto `DermaNube`, generar un token y guardarlo como `SONARTOKEN`.

## 17. Observabilidad local

Levantar:

```bash
docker compose up -d --build
```

Abrir Grafana:

```text
http://localhost:3000
```

Credenciales iniciales:

```text
admin
DermaNubeLocal2026
```

Generar carga:

```bash
curl -X POST http://localhost:3002/citas/carga -H "Content-Type: application/json" -d '{"segundos":30}'
```

Consultar registros de aplicación en Grafana con:

```text
{nivelarquitectura="aplicacion"} | json
```

Consultar errores:

```text
{nivelarquitectura="aplicacion"} | json | nivel="ERROR"
```

## 18. Validaciones de seguridad

Ejecutar Checkov:

```bash
checkov -d Infraestructura/Terraform --config-file .checkov.yml
```

Crear un plan JSON para OPA:

```bash
terraform -chdir=Infraestructura/Terraform/Principal plan -out=plan.tfplan
```

```bash
terraform -chdir=Infraestructura/Terraform/Principal show -json plan.tfplan > plan.json
```

Evaluar con Conftest:

```bash
conftest test plan.json --policy Politicas/Terraform --namespace dermanube.terraform
```

## 19. Reversión

Ejecutar:

```bash
bash Automatizacion/Reversion.sh
```

El script busca la definición de tarea anterior de cada microservicio y solicita un nuevo despliegue con esa revisión.

## 20. Destrucción

Antes de destruir, descargar cualquier evidencia o documento que se deba conservar. El script desactiva primero la protección de eliminación, habilita el vaciado controlado de baldes y repositorios, y luego presenta el plan de destrucción.

Ejecutar:

```bash
bash Automatizacion/Destruir.sh
```

Revisar la lista completa de recursos que Terraform eliminará.

Los puntos de recuperación de AWS Backup deben eliminarse o expirar antes de borrar un almacén que ya contenga respaldos. El balde de estado del Bootstrap se conserva de manera independiente. Destruirlo solo cuando ya no se necesite el historial de Terraform.
