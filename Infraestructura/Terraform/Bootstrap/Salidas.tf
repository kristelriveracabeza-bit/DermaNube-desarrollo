output "BaldeEstado" {
  value = aws_s3_bucket.estado.id
}

output "TablaBloqueo" {
  value = aws_dynamodb_table.bloqueo.name
}

output "LlaveEstadoArn" {
  value = aws_kms_key.estado.arn
}
