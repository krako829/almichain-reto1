# 4. Pruebas

[← Volver al README](../README.md)

Pruebas para comprobar que el despliegue cumple el reto. Haced una captura de cada una para la memoria.

## Desde el navegador

| # | Prueba | Cómo | Resultado esperado |
|---|---|---|---|
| 1 | La web carga por HTTPS | Abrir `https://almichain2.duckdns.org` | Carga la web de Almi Bites con el **candado** en la barra de direcciones |
| 2 | Redirección HTTP → HTTPS | Escribir `http://almichain2.duckdns.org` (sin la *s*) | Salta sola a `https://` |
| 3 | Certificado válido | Candado → *La conexión es segura* → *El certificado es válido* | Emitido para `almichain2.duckdns.org` por **Let's Encrypt**, con validez de 90 días |
| 4 | Geolocalización | Sección *Dónde estamos* → **¿A cuánto estoy?** → *Permitir* | "Estás a X km del restaurante…" y enlace **Ver cómo llegar** |
| 5 | Ruta | Pulsar **Ver cómo llegar** | Se abre OpenStreetMap con la ruta hasta el restaurante |
| 6 | Mapa | Sección *Dónde estamos* | Mapa de OpenStreetMap con el marcador en Avda. Lehendakari Aguirre 29 |
| 7 | Responsive | Abrir la web en el móvil | Se adapta a una columna |

## Desde la terminal del PC

**DNS: el dominio apunta a la IP elástica**
```bash
dig +short almichain2.duckdns.org
terraform output ip_publica
```
Las dos IPs tienen que coincidir.

**Redirección (código 301)**
```bash
curl -I http://almichain2.duckdns.org
```
```
HTTP/1.1 301 Moved Permanently
Location: https://almichain2.duckdns.org/
```

**HTTPS y cabeceras de seguridad**
```bash
curl -I https://almichain2.duckdns.org
```
```
HTTP/2 200
server: nginx
x-content-type-options: nosniff
x-frame-options: SAMEORIGIN
referrer-policy: strict-origin-when-cross-origin
permissions-policy: geolocation=(self)
```

**Datos del certificado**
```bash
echo | openssl s_client -connect almichain2.duckdns.org:443 -servername almichain2.duckdns.org 2>/dev/null | openssl x509 -noout -subject -issuer -dates
```
```
subject=CN = almichain2.duckdns.org
issuer=C = US, O = Let's Encrypt, CN = ...
notBefore=...
notAfter=...    (90 días después)
```

**Puertos abiertos** (solo 22, 80 y 443)
```bash
nmap -Pn -p 1-1000 almichain2.duckdns.org
```

## Dentro del servidor

```bash
ssh -i almibites-key.pem ubuntu@$(terraform output -raw ip_publica)
```

| Comando | Qué comprueba |
|---|---|
| `sudo tail -n 40 /var/log/almibites-setup.log` | Log de la instalación; tiene que acabar con `==> LISTO` |
| `systemctl status nginx` | Nginx en marcha (`active (running)`) |
| `sudo nginx -t` | Configuración de Nginx correcta |
| `sudo certbot certificates` | Certificado instalado y fecha de caducidad |
| `systemctl list-timers \| grep certbot` | Renovación automática programada |
| `sudo certbot renew --dry-run` | Simula la renovación (tiene que decir *succeeded*) |
| `ls -la /var/www/almibites` | Ficheros de la web, propiedad de `www-data` |

## Infraestructura como código

| Prueba | Resultado esperado |
|---|---|
| `terraform plan` justo después de un `apply` | `No changes. Your infrastructure matches the configuration.` |
| Cambiar un texto de `web/index.html` y hacer `terraform apply` | Solo se reemplaza `terraform_data.subir_web`, y el cambio se ve en la web en segundos |
| `terraform destroy` y luego `terraform apply` | Todo se borra y se vuelve a crear igual, sin tocar nada a mano (ojo con el límite de Let's Encrypt, ver [Mantenimiento](05-mantenimiento.md)) |
| Consola de AWS → EC2, VPC | Los recursos llevan las etiquetas `Proyecto = Almi-Chain Reto 1` y `Gestion = Terraform` |
