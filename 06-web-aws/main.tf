locals {
  dominio = "${var.duckdns_subdominio}.duckdns.org"

  # Huella de todos los ficheros de web/: si cambia alguno, se vuelve a subir la web
  hash_web = sha1(join("", [for f in sort(fileset("${path.module}/web", "**")) : "${f}:${filesha1("${path.module}/web/${f}")}"]))
}

# ---------------------------------------------------------------
# RED: VPC + subred pública + Internet Gateway + tabla de rutas
# ---------------------------------------------------------------
data "aws_availability_zones" "disponibles" {
  state = "available"
}

resource "aws_vpc" "principal" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${var.proyecto}-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.principal.id

  tags = { Name = "${var.proyecto}-igw" }
}

resource "aws_subnet" "publica" {
  vpc_id                  = aws_vpc.principal.id
  cidr_block              = var.subred_publica_cidr
  availability_zone       = data.aws_availability_zones.disponibles.names[0]
  map_public_ip_on_launch = true

  tags = { Name = "${var.proyecto}-subred-publica" }
}

resource "aws_route_table" "publica" {
  vpc_id = aws_vpc.principal.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = { Name = "${var.proyecto}-rt-publica" }
}

resource "aws_route_table_association" "publica" {
  subnet_id      = aws_subnet.publica.id
  route_table_id = aws_route_table.publica.id
}

# ---------------------------------------------------------------
# GRUPO DE SEGURIDAD: HTTP, HTTPS y SSH
# ---------------------------------------------------------------
resource "aws_security_group" "web" {
  name        = "${var.proyecto}-sg-web"
  description = "HTTP, HTTPS y SSH para el servidor web"
  vpc_id      = aws_vpc.principal.id

  ingress {
    description = "HTTP (certificado y redireccion a HTTPS)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH (Terraform sube la web por aqui)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_cidr]
  }

  egress {
    description = "Salida a Internet"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.proyecto}-sg-web" }
}

# ---------------------------------------------------------------
# CLAVE SSH: Terraform genera una clave propia para entrar al
# servidor y subir la web (se guarda en almibites-key.pem)
# ---------------------------------------------------------------
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "web" {
  key_name   = "${var.proyecto}-key"
  public_key = tls_private_key.ssh.public_key_openssh
}

resource "local_sensitive_file" "clave_privada" {
  content         = tls_private_key.ssh.private_key_pem
  filename        = "${path.module}/${var.proyecto}-key.pem"
  file_permission = "0400"
}

# ---------------------------------------------------------------
# IP ELÁSTICA: IP fija para que el dominio no cambie aunque
# AWS Academy apague la máquina al acabar la sesión
# ---------------------------------------------------------------
resource "aws_eip" "web" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.igw]

  tags = { Name = "${var.proyecto}-eip" }
}

# ---------------------------------------------------------------
# EC2: Ubuntu 24.04 + Nginx + Certbot (Let's Encrypt)
# ---------------------------------------------------------------
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "web" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.tipo_instancia
  subnet_id              = aws_subnet.publica.id
  vpc_security_group_ids = [aws_security_group.web.id]
  key_name               = aws_key_pair.web.key_name

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
  }

  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    dominio            = local.dominio
    duckdns_subdominio = var.duckdns_subdominio
    duckdns_token      = var.duckdns_token
    eip                = aws_eip.web.public_ip
    email              = var.email
    staging            = var.certbot_staging
  })
  # Si cambia el script de arranque (p. ej. certbot_staging = false, otro token o correo),
  # la máquina se recrea: si solo se parara y arrancara, cloud-init no lo volvería a ejecutar
  user_data_replace_on_change = true

  # Si Canonical publica una AMI nueva, NO recrear la máquina
  # (si no, habría que pedir otro certificado)
  lifecycle {
    ignore_changes = [ami]
  }

  tags = { Name = "${var.proyecto}-web" }
}

resource "aws_eip_association" "web" {
  instance_id   = aws_instance.web.id
  allocation_id = aws_eip.web.id
}

# ---------------------------------------------------------------
# SUBIR LA WEB: copia la carpeta web/ al servidor por SSH.
# Se repite solo si cambia algún fichero de web/ o la máquina.
# Espera a que termine el script de arranque (Nginx + HTTPS),
# así que cuando acaba el apply la web ya está lista.
# ---------------------------------------------------------------
resource "terraform_data" "subir_web" {
  triggers_replace = [aws_instance.web.id, local.hash_web]

  depends_on = [aws_eip_association.web]

  connection {
    type        = "ssh"
    host        = aws_eip.web.public_ip
    user        = "ubuntu"
    private_key = tls_private_key.ssh.private_key_pem
    timeout     = "5m"
  }

  provisioner "remote-exec" {
    inline = ["rm -rf /tmp/web"]
  }

  provisioner "file" {
    source      = "${path.module}/web"
    destination = "/tmp"
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'Esperando a que termine la instalacion (Nginx, DuckDNS y certificado HTTPS)...'",
      "cloud-init status --wait > /dev/null || true",
      "sudo mkdir -p /var/www/almibites",
      "sudo find /var/www/almibites -mindepth 1 -delete",
      "sudo cp -r /tmp/web/. /var/www/almibites/",
      "sudo chown -R www-data:www-data /var/www/almibites",
      "echo '----- Resultado de la instalacion -----'",
      "sudo grep -E '^(==> LISTO|ERROR|Certbot)' /var/log/almibites-setup.log || echo 'Revisa el log: sudo tail -n 40 /var/log/almibites-setup.log'",
    ]
  }
}
