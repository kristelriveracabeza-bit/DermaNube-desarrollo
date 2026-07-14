pipeline {
    agent any

    parameters {
        string(name: 'ETIQUETAIMAGEN', defaultValue: 'latest', description: 'Etiqueta inmutable de las imagenes')
        choice(name: 'AMBIENTE', choices: ['desarrollo', 'produccion'], description: 'Ambiente de despliegue')
    }

    environment {
        REGIONAWS = credentials('RegionAws')
        CUENTAAWS = credentials('CuentaAws')
        REPOSITORIOPERSONAS = "${CUENTAAWS}.dkr.ecr.${REGIONAWS}.amazonaws.com/dermanube-${AMBIENTE}/serviciopersonas"
        REPOSITORIOCITAS = "${CUENTAAWS}.dkr.ecr.${REGIONAWS}.amazonaws.com/dermanube-${AMBIENTE}/serviciocitas"
        REPOSITORIODOCUMENTOS = "${CUENTAAWS}.dkr.ecr.${REGIONAWS}.amazonaws.com/dermanube-${AMBIENTE}/trabajadordocumentos"
    }

    stages {
        stage('Obtener codigo') {
            steps {
                checkout scm
            }
        }

        stage('Preparar Terraform') {
            steps {
                withCredentials([
                    file(credentialsId: 'BackendTerraform', variable: 'ARCHIVOBACKEND'),
                    file(credentialsId: 'VariablesTerraform', variable: 'ARCHIVOVARIABLES')
                ]) {
                    sh 'cp "$ARCHIVOBACKEND" Infraestructura/Terraform/Principal/Backend.hcl'
                    sh 'cp "$ARCHIVOVARIABLES" Infraestructura/Terraform/Principal/terraform.tfvars'
                }
                sh '''cat > Infraestructura/Terraform/Principal/Imagenes.auto.tfvars.json <<ARCHIVO
{
  "CrearServicios": true,
  "ImagenServicioPersonas": "${REPOSITORIOPERSONAS}:${ETIQUETAIMAGEN}",
  "ImagenServicioCitas": "${REPOSITORIOCITAS}:${ETIQUETAIMAGEN}",
  "ImagenTrabajadorDocumentos": "${REPOSITORIODOCUMENTOS}:${ETIQUETAIMAGEN}"
}
ARCHIVO'''
            }
        }

        stage('Validar infraestructura') {
            steps {
                dir('Infraestructura/Terraform/Principal') {
                    sh 'terraform init -input=false -backend-config=Backend.hcl'
                    sh 'terraform fmt -check'
                    sh 'terraform validate'
                    sh 'checkov -d . --config-file ../../../.checkov.yml'
                    sh 'terraform plan -input=false -out=plan.tfplan'
                    sh 'terraform show -json plan.tfplan > plan.json'
                    sh 'conftest test plan.json --policy ../../../Politicas/Terraform --namespace dermanube.terraform'
                }
            }
        }

        stage('Aprobar produccion') {
            when {
                expression { params.AMBIENTE == 'produccion' }
            }
            steps {
                input message: 'Confirmar despliegue en produccion', ok: 'Desplegar'
            }
        }

        stage('Aplicar infraestructura') {
            steps {
                dir('Infraestructura/Terraform/Principal') {
                    sh 'terraform apply -input=false -auto-approve plan.tfplan'
                }
            }
        }

        stage('Actualizar Kubernetes') {
            steps {
                script {
                    def nombreEks = sh(script: 'terraform -chdir=Infraestructura/Terraform/Principal output -raw EksNombre', returnStdout: true).trim()
                    if (nombreEks) {
                        sh 'ETIQUETAIMAGEN=${ETIQUETAIMAGEN} bash Automatizacion/PrepararKubernetes.sh'
                    } else {
                        echo 'EKS no esta habilitado para este ambiente'
                    }
                }
            }
        }

        stage('Pruebas de humo') {
            steps {
                sh 'bash Automatizacion/PruebasHumo.sh'
            }
        }
    }

    post {
        failure {
            sh 'bash Automatizacion/Reversion.sh || true'
        }
        always {
            sh 'rm -f Infraestructura/Terraform/Principal/Backend.hcl Infraestructura/Terraform/Principal/terraform.tfvars Infraestructura/Terraform/Principal/plan.tfplan Infraestructura/Terraform/Principal/plan.json Infraestructura/Kubernetes/TrabajadorDocumentosGenerado.yml'
        }
    }
}
