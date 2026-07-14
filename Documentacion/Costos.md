# Control de costos

## Recursos con costo continuo

- NAT Gateway.
- Application Load Balancer.
- Tareas de ECS Fargate.
- Clúster y nodos de EKS.
- Instancias de ElastiCache.
- Dominio de OpenSearch.
- Instancia EC2 de Jenkins.
- Amazon Managed Service for Prometheus.
- Amazon Managed Grafana.

## Recursos de consumo variable

- API Gateway.
- DynamoDB en modalidad bajo demanda.
- Lambda.
- SNS y SQS.
- S3.
- CloudFront.
- CloudWatch y CloudTrail.
- AWS Backup.

## Modo de validación controlada

Para una primera validación se recomienda configurar:

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

Este modo mantiene VPC, frontend, Cognito, API Gateway, ALB, ECS, DynamoDB, SNS, SQS, Lambda, CloudTrail, Backup y Budgets.

## Modo completo

Para demostrar la arquitectura completa:

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

## Medidas de control

- Configurar `CorreoPresupuesto` antes de desplegar.
- Mantener `LimitePresupuestoUsd` acorde con el tiempo de demostración.
- Etiquetar todos los recursos por proyecto y ambiente.
- Destruir el ambiente cuando deje de utilizarse.
- No mantener EKS, OpenSearch o ElastiCache activos únicamente para conservar capturas.
- Revisar los cargos del día en Cost Explorer.
