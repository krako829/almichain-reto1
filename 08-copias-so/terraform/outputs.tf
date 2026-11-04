output "ip_elastica" {
  description = "IP fija del servidor de copias remoto"
  value       = aws_eip.backup.public_ip
}

output "ip_permitida_ssh" {
  description = "IP que tiene permitido el SSH en el grupo de seguridad"
  value       = local.ip_permitida
}

output "ssh_config" {
  description = "Bloque para añadir a ~/.ssh/config del usuario copia en el Ubuntu Backup"
  value       = <<-EOT

    Host remoto
        HostName ${aws_eip.backup.public_ip}
        User ubuntu
        IdentityFile ~/.ssh/id_ed25519_remoto
  EOT
}
