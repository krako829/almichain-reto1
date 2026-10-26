output "url" {
  description = "Dirección de la web."
  value       = "https://${local.dominio}"
}

output "ip_publica" {
  description = "IP elástica del servidor (DuckDNS apunta aquí)."
  value       = aws_eip.web.public_ip
}

output "ssh" {
  description = "Comando para entrar al servidor."
  value       = "ssh -i ${var.proyecto}-key.pem ubuntu@${aws_eip.web.public_ip}"
}

output "ver_log_instalacion" {
  description = "Una vez dentro por SSH, así ves cómo fue la instalación."
  value       = "sudo tail -n 40 /var/log/almibites-setup.log"
}
