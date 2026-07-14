variable "RegionAws" {
  type    = string
  default = "us-east-1"
}

variable "NombreProyecto" {
  type    = string
  default = "DermaNube"
}

variable "Ambiente" {
  type    = string
  default = "produccion"
}

variable "CidrVpc" {
  type    = string
  default = "10.30.0.0/16"
}

variable "Dominio" {
  type    = string
  default = ""
}

variable "IdZonaHospedada" {
  type    = string
  default = ""
}

variable "CorreoPresupuesto" {
  type    = string
  default = ""
}

variable "LimitePresupuestoUsd" {
  type    = number
  default = 80
}

variable "CidrAdministracion" {
  type    = string
  default = "127.0.0.1/32"

  validation {
    condition     = var.CidrAdministracion != "0.0.0.0/0"
    error_message = "CidrAdministracion debe limitarse a una direccion o red administrativa concreta"
  }
}

variable "LlaveSshPublica" {
  type      = string
  default   = ""
  sensitive = true
}

variable "ImagenServicioPersonas" {
  type    = string
  default = ""
}

variable "ImagenServicioCitas" {
  type    = string
  default = ""
}

variable "ImagenTrabajadorDocumentos" {
  type    = string
  default = ""
}

variable "CrearServicios" {
  type    = bool
  default = false
}

variable "CrearNatGateway" {
  type    = bool
  default = true
}

variable "CrearCache" {
  type    = bool
  default = true
}

variable "CrearBusqueda" {
  type    = bool
  default = true
}

variable "CrearEks" {
  type    = bool
  default = false
}

variable "CrearJenkins" {
  type    = bool
  default = false
}

variable "CrearPrometheusAdministrado" {
  type    = bool
  default = false
}

variable "CrearGrafanaAdministrado" {
  type    = bool
  default = false
}

variable "ProtegerRecursos" {
  type    = bool
  default = true
}

variable "ProtegerApi" {
  type    = bool
  default = true
}

variable "CapacidadMinimaServicios" {
  type    = number
  default = 2
}

variable "CapacidadMaximaServicios" {
  type    = number
  default = 6
}

variable "PrefijoDominioCognito" {
  type    = string
  default = ""
}

variable "RepositorioGithub" {
  type    = string
  default = ""
}
