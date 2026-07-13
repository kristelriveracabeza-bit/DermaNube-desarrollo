package dermanube.terraform

import rego.v1

deny contains mensaje if {
  recurso := input.resource_changes[_]
  recurso.type == "aws_security_group"
  entrada := recurso.change.after.ingress[_]
  entrada.cidr_blocks[_] == "0.0.0.0/0"
  entrada.from_port != 443
  mensaje := sprintf("El grupo %s expone un puerto administrativo a Internet", [recurso.name])
}

deny contains mensaje if {
  recurso := input.resource_changes[_]
  recurso.type == "aws_s3_bucket"
  recurso.change.after.force_destroy == true
  mensaje := sprintf("El balde %s no debe permitir destruccion forzada", [recurso.name])
}
