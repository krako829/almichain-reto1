variable "region" {
  description = "Región de AWS. En AWS Academy Learner Lab solo funcionan us-east-1 y us-west-2."
  type        = string
  default     = "us-east-1"
}

variable "proyecto" {
  description = "Prefijo para los nombres de los recursos."
  type        = string
  default     = "almibites"
}

variable "duckdns_subdominio" {
  description = "Subdominio de DuckDNS SIN '.duckdns.org'. El del reto es almichain2."
  type        = string
  default     = "almichain2"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.duckdns_subdominio))
    error_message = "Pon solo el subdominio en minúsculas, sin '.duckdns.org' (ej: almichain2)."
  }
}

variable "duckdns_token" {
  description = "Token de tu cuenta de DuckDNS (aparece arriba en duckdns.org al iniciar sesión)."
  type        = string
  sensitive   = true
}

variable "email" {
  description = "Correo para Let's Encrypt (avisos de caducidad del certificado)."
  type        = string
}

variable "certbot_staging" {
  description = "true = certificado de PRUEBA de Let's Encrypt (no sale el candado, pero no gasta el límite de 5 certificados/semana). Úsalo si vas a hacer muchos destroy/apply."
  type        = bool
  default     = false
}

variable "tipo_instancia" {
  description = "Tipo de instancia EC2."
  type        = string
  default     = "t3.micro"
}

variable "ssh_cidr" {
  description = "Desde qué IPs se permite SSH (puerto 22). Terraform lo usa para subir la web."
  type        = string
  default     = "0.0.0.0/0"
}

variable "vpc_cidr" {
  description = "Rango de la VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "subred_publica_cidr" {
  description = "Rango de la subred pública donde va el servidor web."
  type        = string
  default     = "10.0.1.0/24"
}
