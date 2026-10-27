# 5. Mantenimiento

[← Volver al README](../README.md)

## Cambiar la web

1. Edita lo que quieras dentro de `web/`: `index.html`, `estilos.css`, imágenes…
2. Ejecuta:
   ```bash
   terraform apply
   ```
3. El plan mostrará `1 to add, 0 to change, 1 to destroy`. Es solo `terraform_data.subir_web`, que se "reemplaza" para volver a subir la web. **No toca el servidor ni el certificado.**
4. Escribe `yes`. En unos segundos la web nueva está publicada (puede que tengas que recargar con **Ctrl + F5** por la caché del navegador).

Si sustituís la web entera por una versión nueva, mantened el botón de geolocalización (`<div class="geo">…</div>` en *Dónde estamos*, `<script src="geo.js" defer>` antes de `</body>` y los estilos `.geo` del CSS).

## Cada nueva sesión del lab

- Al cerrar la sesión, AWS Academy **apaga** la EC2. Al iniciar el lab otra vez, **se enciende sola** y conserva la web y el certificado.
- La IP es elástica, así que **no cambia** y DuckDNS sigue apuntando bien. No hay que hacer nada.
- Solo si vais a usar Terraform: copiad las credenciales nuevas en `~/.aws/credentials` (ver [paso 3 de la guía](02-guia-despliegue.md#paso-3-credenciales-de-aws-academy)).
- Mientras el lab está parado, la web no está disponible (la máquina está apagada). Para enseñarla, iniciad el lab unos minutos antes.

## Renovación del certificado

Los certificados de Let's Encrypt duran **90 días**. El paquete `certbot` de Ubuntu instala un temporizador (`certbot.timer`) que intenta renovarlos dos veces al día cuando les quedan menos de 30. Es automático.

Comprobarlo:
```bash
ssh -i almibites-key.pem ubuntu@IP
systemctl list-timers | grep certbot
sudo certbot renew --dry-run
```

## Límite de Let's Encrypt (importante)

Let's Encrypt solo da **5 certificados por semana para el mismo dominio**. Cada `terraform destroy` + `terraform apply` crea una máquina nueva y pide un certificado nuevo. Si se supera el límite, el `apply` funciona, pero la web se queda sin HTTPS durante una semana (error `too many certificates already issued` en el log).

Para hacer pruebas, en `terraform.tfvars`:
```hcl
certbot_staging = true
```
Así se pide un certificado de **prueba**: el navegador dice que no es de confianza, pero no gasta el límite. Para la versión final, volved a `false` y recread la máquina:
```bash
terraform apply -replace=aws_instance.web
```

## Recrear solo el servidor

Si algo se ha estropeado dentro de la máquina, o habéis cambiado el dominio o el token:
```bash
terraform apply -replace=aws_instance.web
```
Crea una EC2 nueva desde cero (con la misma IP elástica), vuelve a instalar todo y sube la web.

## Quién despliega

- El **estado** (`terraform.tfstate`) está en el PC de quien hizo el `apply`. Debe desplegar **siempre la misma persona** desde la misma carpeta.
- Si otra persona hace `apply` desde otro PC, Terraform no sabe que ya existe todo. Intentará crearlo otra vez y fallará (por ejemplo, porque ya existe el par de claves `almibites-key`) o creará una segunda copia.
- Haced copia de seguridad de `terraform.tfstate`, `terraform.tfvars` y `almibites-key.pem` (USB o Drive privado). **No** los subáis a GitHub. Ojo: `terraform.tfstate` contiene en claro la clave privada SSH (la genera `tls_private_key`) y el token de DuckDNS, así que se trata como un secreto más.

## Borrar todo

Al acabar el reto, para no gastar créditos:
```bash
terraform destroy
```
Escribe `yes`. Borra la EC2, la IP elástica, el par de claves y toda la red.

Si Terraform ya no tiene el estado (se perdió el `terraform.tfstate`), hay que borrar a mano en la consola de AWS, en este orden: instancia EC2 `almibites-web` → IP elástica `almibites-eip` (liberar) → par de claves `almibites-key` → VPC `almibites-vpc` (al borrar la VPC se borran su subred, tabla de rutas, gateway y grupo de seguridad).
