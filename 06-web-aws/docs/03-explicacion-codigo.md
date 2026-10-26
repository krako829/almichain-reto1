# 3. Explicación del código

[← Volver al README](../README.md)

## Cómo trabaja Terraform

Terraform lee todos los ficheros `.tf` de la carpeta como si fueran uno solo. En ellos se **describe** la infraestructura que se quiere tener, no los pasos para crearla. Al hacer `terraform apply`, Terraform:

1. Compara lo que dice el código con lo que hay guardado en `terraform.tfstate`.
2. Calcula qué hay que crear, cambiar o borrar (eso es el `plan`).
3. Lo hace en el orden correcto según las dependencias. Por ejemplo, la subred necesita que exista la VPC.
4. Guarda el resultado en `terraform.tfstate`.

Por eso el `terraform.tfstate` es tan importante: es la "memoria" de Terraform.

---

## `versions.tf`

```hcl
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws   = { source = "hashicorp/aws",   version = "~> 5.0" }
    tls   = { source = "hashicorp/tls",   version = "~> 4.0" }
    local = { source = "hashicorp/local", version = "~> 2.4" }
  }
}

provider "aws" {
  region = var.region
  default_tags { tags = { Proyecto = "Almi-Chain Reto 1", Gestion = "Terraform" } }
}
```

- **Proveedores**: son los "plugins" de Terraform. `aws` habla con Amazon, `tls` genera claves criptográficas y `local` escribe ficheros en el PC.
- `~> 5.0` significa "cualquier versión 5.x".
- El proveedor `aws` no lleva credenciales en el código: las lee de `~/.aws/credentials`. Así no se suben a GitHub.
- `default_tags` pone estas etiquetas a todos los recursos, para reconocerlos en la consola de AWS.

---

## `variables.tf`

Define los datos que se pueden cambiar sin tocar el código. Sus valores se ponen en `terraform.tfvars`.

| Variable | Valor por defecto | Para qué sirve |
|---|---|---|
| `region` | `us-east-1` | Región de AWS. El Learner Lab solo permite `us-east-1` y `us-west-2` |
| `proyecto` | `almibites` | Prefijo de los nombres (`almibites-vpc`, `almibites-web`…) |
| `duckdns_subdominio` | `almichain2` | Subdominio sin `.duckdns.org`. Tiene una **validación**: si alguien escribe `almichain2.duckdns.org`, Terraform da un error explicándolo |
| `duckdns_token` | — (obligatoria) | Token de DuckDNS. Marcada `sensitive` para que no aparezca en pantalla |
| `email` | — (obligatoria) | Correo para Let's Encrypt |
| `certbot_staging` | `false` | `true` pide un certificado de prueba (ver [Mantenimiento](05-mantenimiento.md)) |
| `tipo_instancia` | `t3.micro` | Tamaño de la EC2 (2 vCPU, 1 GB RAM) |
| `ssh_cidr` | `0.0.0.0/0` | Desde qué IPs se permite SSH |
| `vpc_cidr` | `10.0.0.0/16` | Rango de direcciones de la VPC |
| `subred_publica_cidr` | `10.0.1.0/24` | Rango de la subred pública |

---

## `main.tf`

### `locals`

```hcl
locals {
  dominio  = "${var.duckdns_subdominio}.duckdns.org"
  hash_web = sha1(join("", [for f in sort(fileset("${path.module}/web", "**")) : "${f}:${filesha1("${path.module}/web/${f}")}"]))
}
```

- `dominio` monta el nombre completo: `almichain2.duckdns.org`.
- `hash_web` es una "huella" de todos los ficheros de `web/`: calcula el SHA-1 de cada fichero y luego el de todos juntos. Si cambia cualquier fichero, cambia la huella, y Terraform sabe que tiene que volver a subir la web.

### Red

| Recurso | Qué hace |
|---|---|
| `data.aws_availability_zones.disponibles` | **Consulta** (no crea) qué zonas de disponibilidad hay en la región, para poner la subred en la primera (`us-east-1a`) |
| `aws_vpc.principal` | Crea la VPC `10.0.0.0/16` con resolución DNS activada |
| `aws_internet_gateway.igw` | Crea el Internet Gateway y lo conecta a la VPC |
| `aws_subnet.publica` | Crea la subred `10.0.1.0/24`. `map_public_ip_on_launch = true` da IP pública a las máquinas al arrancar, para que tengan Internet antes de recibir la IP elástica |
| `aws_route_table.publica` | Tabla con la ruta `0.0.0.0/0 → Internet Gateway`: todo lo que no es de la VPC sale a Internet |
| `aws_route_table_association.publica` | Asocia esa tabla a la subred. Esto es lo que la convierte en "pública" |

### Grupo de seguridad

`aws_security_group.web` es el firewall de la máquina:

| Dirección | Puerto | Origen | Motivo |
|---|---|---|---|
| Entrada | 80/TCP | Todo Internet | Let's Encrypt valida el dominio por aquí, y Nginx redirige a HTTPS |
| Entrada | 443/TCP | Todo Internet | La web en HTTPS |
| Entrada | 22/TCP | `var.ssh_cidr` | Terraform entra para subir la web; también sirve para administrar |
| Salida | Todos | Todo Internet | Instalar paquetes, hablar con DuckDNS y Let's Encrypt |

### Clave SSH

```hcl
resource "tls_private_key" "ssh"            # genera un par de claves RSA de 4096 bits
resource "aws_key_pair" "web"               # registra la parte pública en AWS como "almibites-key"
resource "local_sensitive_file" "clave_privada"  # guarda la privada en almibites-key.pem (permisos 0400)
```

AWS mete la clave pública en el usuario `ubuntu` de la máquina. Con la privada, Terraform (y tú) podéis entrar por SSH.

### IP elástica

`aws_eip.web` reserva una IP pública fija. Lleva `depends_on = [aws_internet_gateway.igw]` porque AWS no deja usar IPs elásticas en una VPC sin gateway.

### Servidor EC2

```hcl
data "aws_ami" "ubuntu" { ... }   # busca la imagen más reciente de Ubuntu 24.04 publicada por Canonical
```

`099720109477` es el ID de la cuenta oficial de Canonical, la empresa de Ubuntu. Así nos aseguramos de que la imagen es la oficial.

```hcl
resource "aws_instance" "web" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.tipo_instancia
  subnet_id              = aws_subnet.publica.id
  vpc_security_group_ids = [aws_security_group.web.id]
  key_name               = aws_key_pair.web.key_name
  root_block_device { volume_size = 8, volume_type = "gp3" }
  user_data = templatefile("user_data.sh.tftpl", { dominio = ..., eip = ..., ... })
  lifecycle { ignore_changes = [ami] }
}
```

- `user_data` es un script que la máquina ejecuta **solo la primera vez que arranca**. `templatefile` coge `user_data.sh.tftpl` y sustituye las variables `${dominio}`, `${eip}`, etc. por los valores reales.
- `ignore_changes = [ami]`: cuando Canonical publica una imagen nueva de Ubuntu, Terraform no recrea la máquina. Si la recreara, se perdería el certificado y habría que pedir otro.

`aws_eip_association.web` une la IP elástica con la máquina.

### Subida de la web

```hcl
resource "terraform_data" "subir_web" {
  triggers_replace = [aws_instance.web.id, local.hash_web]
  depends_on       = [aws_eip_association.web]
  connection { type = "ssh", host = aws_eip.web.public_ip, user = "ubuntu", private_key = ... }

  provisioner "remote-exec" { inline = ["rm -rf /tmp/web"] }
  provisioner "file"        { source = "web", destination = "/tmp" }
  provisioner "remote-exec" { inline = [ "cloud-init status --wait", "sudo cp -r /tmp/web/. /var/www/almibites/", ... ] }
}
```

- `terraform_data` es un recurso "vacío" que sirve para ejecutar acciones.
- `triggers_replace`: se vuelve a ejecutar si cambia la máquina o la huella de la web. Si no cambia nada, `apply` no vuelve a subirla.
- Los **provisioners** se ejecutan en orden:
  1. Borra `/tmp/web` en el servidor, por si quedaba una copia antigua.
  2. Copia la carpeta `web/` del PC a `/tmp/web` del servidor por SSH (SCP).
  3. Espera a que termine el script de arranque (`cloud-init status --wait`), copia la web a `/var/www/almibites`, le da permisos a `www-data` (el usuario de Nginx) y enseña el resultado de la instalación.

---

## `user_data.sh.tftpl`

Script Bash que ejecuta la EC2 al arrancar. Todo lo que hace queda registrado en `/var/log/almibites-setup.log`.

| Fase | Qué hace |
|---|---|
| **1. Paquetes** | `apt-get install nginx certbot python3-certbot-nginx dnsutils curl` |
| **2. Carpeta web** | Crea `/var/www/almibites` con una página provisional "Subiendo la web…" |
| **Nginx** | Escribe `/etc/nginx/sites-available/almibites` con `server_name almichain2.duckdns.org`, cabeceras de seguridad y caché de 7 días para CSS e imágenes. Lo activa y desactiva el sitio por defecto |
| **3. DuckDNS** | Llama a `https://www.duckdns.org/update?domains=almichain2&token=...&ip=IP_ELASTICA` hasta que responde `OK`. Si responde `KO` (token o subdominio incorrectos), lo apunta como `ERROR` en el log y para |
| **Esperas** | Espera a que la IP elástica esté asociada (lo consulta en los metadatos de la instancia, IMDSv2) y a que el DNS de DuckDNS devuelva esa IP (`dig @ns1.duckdns.org`). Sin esto, Let's Encrypt fallaría |
| **4. Certificado** | `certbot --nginx -d almichain2.duckdns.org --redirect`. Certbot pide el certificado, modifica la configuración de Nginx para escuchar en el 443 con el certificado y añade la redirección 80 → 443. Lo reintenta hasta 3 veces |

Detalle técnico: dentro de una plantilla de Terraform, `${...}` se sustituye por una variable. Por eso en el script las variables de Bash se escriben como `$VARIABLE`, sin llaves, y Terraform no las toca.

---

## `outputs.tf`

Lo que muestra Terraform al terminar, o con `terraform output`:

| Output | Ejemplo |
|---|---|
| `url` | `https://almichain2.duckdns.org` |
| `ip_publica` | `3.215.x.x` |
| `ssh` | `ssh -i almibites-key.pem ubuntu@3.215.x.x` |
| `ver_log_instalacion` | `sudo tail -n 40 /var/log/almibites-setup.log` |

---

## `web/geo.js` (geolocalización)

1. Al pulsar **¿A cuánto estoy?** comprueba que la página va por HTTPS (`window.isSecureContext`) y que el navegador soporta geolocalización.
2. Llama a `navigator.geolocation.getCurrentPosition()`. El navegador pide permiso al usuario.
3. Calcula la distancia en línea recta al restaurante (43.2715, -2.9470) con la **fórmula del haversine**, que tiene en cuenta la curvatura de la Tierra.
4. Si está a 5 km o menos, estima los minutos andando (a 4,5 km/h).
5. Genera un enlace a OpenStreetMap con la ruta desde la ubicación del usuario: a pie si está cerca, en coche si está lejos.
6. Si el usuario deniega el permiso, o hay un error, muestra un mensaje explicándolo.

---

## `.gitignore`

```
.terraform/        # proveedores descargados (se regeneran con terraform init)
*.tfstate          # estado de Terraform (lleva datos sensibles)
*.tfstate.*
terraform.tfvars   # token de DuckDNS y correo
crash.log
*.pem              # clave privada SSH
```

`.terraform.lock.hcl` **sí** se sube: fija las versiones exactas de los proveedores, para que todos usen las mismas.
