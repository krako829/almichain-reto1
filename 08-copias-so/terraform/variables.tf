variable "region" {
  description = "Región de AWS (la que pone en AWS Details del Learner Lab)"
  type        = string
  default     = "us-east-1"
}

variable "clave_publica" {
  description = "Contenido de ~/.ssh/id_ed25519_remoto.pub del Ubuntu Backup (una sola línea)"
  type        = string
}

variable "ip_permitida" {
  description = "IP (con /32) que puede entrar por SSH. Vacío = se detecta sola la IP pública actual"
  type        = string
  default     = ""
}

variable "tipo_instancia" {
  description = "Tipo de instancia EC2"
  type        = string
  default     = "t2.micro"
}

variable "disco_gb" {
  description = "Tamaño del disco de la instancia en GB"
  type        = number
  default     = 10
}
