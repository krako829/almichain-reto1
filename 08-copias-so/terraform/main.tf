# Servidor de copias remoto de Almi-Chain en AWS
# Recibe por rsync+SSH la réplica de /backups/gerente del Ubuntu Backup

# Ubuntu 24.04 más reciente, de la cuenta oficial de Canonical
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

# VPC por defecto del Learner Lab
data "aws_vpc" "default" {
  default = true
}

# IP pública desde la que se ejecuta Terraform (la del aula)
data "http" "mi_ip" {
  url = "https://checkip.amazonaws.com"
}

locals {
  ip_permitida = var.ip_permitida != "" ? var.ip_permitida : "${chomp(data.http.mi_ip.response_body)}/32"
  nombre       = "almichain-backup-remoto"
}

# Clave pública del usuario "copia" del Ubuntu Backup
resource "aws_key_pair" "backup" {
  key_name   = "backup-almichain"
  public_key = var.clave_publica
}

# Solo se permite SSH desde la IP del aula
resource "aws_security_group" "backup" {
  name        = local.nombre
  description = "SSH solo desde la IP del aula"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [local.ip_permitida]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = local.nombre
  }
}

resource "aws_instance" "backup" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.tipo_instancia
  key_name               = aws_key_pair.backup.key_name
  vpc_security_group_ids = [aws_security_group.backup.id]

  root_block_device {
    volume_size = var.disco_gb
    volume_type = "gp3"
  }

  # Prepara la carpeta donde se guardará la réplica
  user_data = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y rsync
    mkdir -p /backups_remoto
    chown ubuntu:ubuntu /backups_remoto
  EOF

  tags = {
    Name = local.nombre
  }
}

# IP fija: no cambia aunque el lab apague y encienda la instancia
resource "aws_eip" "backup" {
  instance = aws_instance.backup.id
  domain   = "vpc"

  tags = {
    Name = local.nombre
  }
}
