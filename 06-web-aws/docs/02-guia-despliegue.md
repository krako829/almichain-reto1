# 2. Guía de despliegue paso a paso

[← Volver al README](../README.md)

Esta guía parte de cero, en un PC con **Zorin OS** (o Ubuntu). Todos los comandos se escriben en la **terminal**.

> 💡 **¿Dónde estoy?** En la terminal, lo que aparece entre los `:` y el `$` es la carpeta en la que estás. Por ejemplo, `alberto@pc:~/reto1/almichain-web-terraform$` significa que estás en `~/reto1/almichain-web-terraform`. Todos los comandos de Terraform se ejecutan **dentro de la carpeta del proyecto**.

---

## Paso 1. Instalar Terraform

Comprueba si ya está instalado:

```bash
terraform -version
```

Si aparece `Terraform v1.x.x`, pasa al paso 2. Si aparece `orden no encontrada`, instálalo:

```bash
# 1. Descargar la clave de HashiCorp, para que el sistema confíe en sus paquetes
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

# 2. Añadir el repositorio de HashiCorp a apt
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(. /etc/os-release && echo $UBUNTU_CODENAME) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

# 3. Instalar
sudo apt update && sudo apt install -y terraform

# 4. Comprobar
terraform -version
```

En **Windows**: `winget install Hashicorp.Terraform` y abrir una terminal nueva.

---

## Paso 2. Descargar el proyecto

Clónalo en una carpeta fija (no en Descargas, para no borrarlo sin querer):

```bash
mkdir -p ~/reto1
cd ~/reto1
git clone https://github.com/krako829/almichain-web-terraform.git
cd almichain-web-terraform
ls
```

Tienen que aparecer `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`, `user_data.sh.tftpl`, `terraform.tfvars.example`, `README.md` y las carpetas `web` y `docs`.

> Si el repositorio es privado, GitHub pedirá usuario y un *token* personal en lugar de la contraseña. También puedes descargarlo como ZIP desde GitHub: **Code → Download ZIP**.

---

## Paso 3. Credenciales de AWS Academy

Terraform necesita permiso para crear cosas en la cuenta del lab.

1. Entra en AWS Academy → tu curso → **Learner Lab** → **Start Lab**. Espera a que el círculo junto a "AWS" se ponga **verde**.
2. Pulsa **AWS Details**:
   - Apunta la **Region** que aparece (normalmente `us-east-1`).
   - Junto a **AWS CLI**, pulsa **Show** y copia el bloque entero, desde `[default]` hasta el final de `aws_session_token`.
3. Crea el fichero de credenciales y pega el bloque:
   ```bash
   mkdir -p ~/.aws
   nano ~/.aws/credentials
   ```
   - Pega con **Ctrl + Shift + V**. En la terminal, Ctrl + V solo no pega.
   - Guarda con **Ctrl + O** y **Enter**. Sal con **Ctrl + X**.
4. Comprueba que se ha guardado:
   ```bash
   cat ~/.aws/credentials
   ```
   Tienen que salir 4 líneas: `[default]`, `aws_access_key_id=...`, `aws_secret_access_key=...` y `aws_session_token=...`.

> ⚠️ Las credenciales **caducan a las ~4 horas**. Cada vez que inicies el lab, repite este paso con las nuevas.
>
> ⚠️ Usa `nano` **sin `sudo`**. Con `sudo`, el fichero se guarda en la carpeta de root y Terraform no lo encuentra.

---

## Paso 4. Token de DuckDNS

1. Entra en <https://www.duckdns.org> e inicia sesión con la cuenta donde está el subdominio **almichain2**.
2. Copia el **token**. Si el navegador traduce la página al español, aparece como **"simbólico"**.
3. Comprueba que en la lista de dominios de esa cuenta aparece **almichain2**. Si no aparece, créalo: escribe `almichain2` en *sub domain* y pulsa **add domain**.

El token solo sirve para la cuenta que tiene el dominio. Con el token de otra cuenta, DuckDNS responde `KO` y el HTTPS no se activa.

---

## Paso 5. Rellenar `terraform.tfvars`

Este fichero contiene los datos personales. No está en el repositorio: se crea a partir de la plantilla.

```bash
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars
```

Déjalo así, con tus datos:

```hcl
duckdns_subdominio = "almichain2"
duckdns_token      = "TU-TOKEN-DE-DUCKDNS"
email              = "tu-correo@gmail.com"
region             = "us-east-1"   # la que pone en AWS Details
```

El correo lo usa Let's Encrypt para avisar si el certificado va a caducar.

---

## Paso 6. `terraform init`

```bash
terraform init
```

Descarga los proveedores que usa el proyecto: `aws`, `tls` (para generar la clave SSH) y `local` (para guardarla en un fichero). Tiene que terminar con:

```
Terraform has been successfully initialized!
```

Solo hace falta la primera vez, o cuando cambie `versions.tf`.

---

## Paso 7. `terraform plan`

```bash
terraform plan
```

Todavía **no crea nada**: solo enseña lo que va a hacer. En un despliegue desde cero, al final pone:

```
Plan: 13 to add, 0 to change, 0 to destroy.
```

Los 13 recursos son: VPC, Internet Gateway, subred, tabla de rutas y su asociación, grupo de seguridad, clave privada, par de claves, fichero `.pem`, IP elástica, EC2, asociación de la IP y subida de la web.

---

## Paso 8. `terraform apply`

```bash
terraform apply
```

Vuelve a enseñar el plan y pregunta `Enter a value:`. Escribe **`yes`** y pulsa **Enter**.

El proceso tarda **unos 5 minutos**:

1. En 1-2 minutos crea la red, la IP y el servidor.
2. Luego aparece `terraform_data.subir_web: Still creating...` durante 3-4 minutos. Es normal: Terraform espera a que el servidor instale Nginx, actualice DuckDNS y consiga el certificado.
3. Después sube la web por SSH y termina.

Al final verás:

```
terraform_data.subir_web (remote-exec): ----- Resultado de la instalacion -----
terraform_data.subir_web (remote-exec): ==> LISTO: https://almichain2.duckdns.org

Apply complete! Resources: 13 added, 0 changed, 0 destroyed.

Outputs:
ip_publica          = "x.x.x.x"
ssh                 = "ssh -i almibites-key.pem ubuntu@x.x.x.x"
url                 = "https://almichain2.duckdns.org"
ver_log_instalacion = "sudo tail -n 40 /var/log/almibites-setup.log"
```

---

## Paso 9. Comprobar

Abre **https://almichain2.duckdns.org**. Las pruebas completas, para hacer capturas para la memoria, están en [4. Pruebas](04-pruebas.md).

---

## Resumen de comandos

```bash
# Cada sesión del lab: copiar credenciales nuevas
nano ~/.aws/credentials

# Primera vez
cp terraform.tfvars.example terraform.tfvars && nano terraform.tfvars
terraform init

# Desplegar o aplicar cambios
terraform plan
terraform apply

# Ver los datos de salida otra vez
terraform output

# Entrar al servidor
ssh -i almibites-key.pem ubuntu@$(terraform output -raw ip_publica)

# Borrar todo
terraform destroy
```
