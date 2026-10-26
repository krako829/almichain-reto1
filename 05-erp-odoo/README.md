# 5. ERP Odoo + TPV

## Objetivo

El restaurante necesita un ERP con facturación, clientes (CRM), personal, marketing, inventario y TPV. Se ha elegido **Odoo 18 Community**, instalado con **Docker** en la VM **ALMI-ODOO** y publicado solo por **HTTPS** con nginx. Los dos TPV de la barra son los puntos de venta **Barra 1** y **Barra 2** de Odoo. Cuando se cobra una venta a un cliente, Odoo **crea y publica la factura**, la **envía por correo** con el PDF y **descuenta el stock**, sin que nadie toque nada.

Tareas del tablero: E01 a E13.

## Requisitos

| Elemento | Valor |
|---|---|
| VM | ALMI-ODOO · 3 GB de RAM · 2 núcleos · disco de 25 GB · Red NAT ALMICHAIN |
| Sistema | Ubuntu Server 24.04 LTS |
| IP | 192.168.10.30/24 · puerta de enlace 192.168.10.1 · DNS 1.1.1.1 y 9.9.9.9 |
| Software | Docker y Docker Compose (paquetes de Ubuntu), imágenes `odoo:18.0` y `postgres:16`, nginx 1.24 |
| Usuario de administración | `almiadmin` (contraseña en KeePassXC) |
| Licencias | Odoo Community LGPL, Ubuntu, Docker, nginx y PostgreSQL: todo libre y gratis |

### Por qué Odoo (E01)

| ERP | Licencia | TPV integrado | Contabilidad española | Instalación con Docker |
|---|---|---|---|---|
| **Odoo Community** | LGPL, gratis | Sí (Punto de venta, modo bar/restaurante) | Sí (plan contable español) | Imagen oficial |
| Dolibarr | GPL, gratis | Sí (TakePOS) | Sí | Imágenes de la comunidad |
| ERPNext | GPL, gratis | Sí (POS) | Parcial | Oficial, pero más pesada |

Odoo tiene en un solo programa todo lo que pide el enunciado (facturas, CRM, personal, marketing, inventario y TPV), permite automatizar sin programar un módulo (reglas de automatización) y su imagen de Docker hace la instalación repetible. Además es el ERP que indicó el profesor.

## Arquitectura

```mermaid
flowchart LR
  TPV1["ALMI-TPV · usuario TPV1<br/>Edge en quiosco"] -- "HTTPS 443" --> NG
  TPV2["ALMI-TPV · usuario TPV2<br/>Edge en quiosco"] -- "HTTPS 443" --> NG
  GER["ALMI-GERENTE<br/>usuario Gerente"] -- "HTTPS 443" --> NG
  subgraph ODOO["ALMI-ODOO 192.168.10.30"]
    NG["nginx<br/>certificado propio<br/>80 → 443"] -- "127.0.0.1:8069" --> OD["contenedor odoo:18.0"]
    OD --> PG["contenedor postgres:16<br/>base almichain"]
  end
  OD -- "SMTP 587 (Gmail)" --> MAIL["Correo del cliente<br/>factura en PDF"]
  ODOO -- "copia diaria 02:30<br/>rsync por SSH" --> BD["ALMI-BD 192.168.10.20"]
```

- Odoo solo escucha en `127.0.0.1:8069`: desde la red **solo se entra por nginx con HTTPS**.
- La contraseña de PostgreSQL está en `/opt/odoo/.env` (solo la lee root) y no sale del servidor.
- Los datos están en volúmenes de Docker (`odoo-db` y `odoo-data`), así que se puede actualizar la imagen sin perder nada.

## Instalación y configuración paso a paso

Los archivos que se usan están en [`config/`](config/) y [`scripts/`](scripts/). Las contraseñas de los ejemplos (`<…>`) se sustituyen por las del gestor de contraseñas.

### 1. Ubuntu Server (E02)

1. VirtualBox → **Nueva** → ALMI-ODOO, ISO de Ubuntu Server 24.04, Linux / Ubuntu (64-bit), 3072 MB, 2 CPU, 25 GB. Red: **Red NAT ALMICHAIN**.
2. Instalador: teclado español, red manual (192.168.10.30/24, puerta 192.168.10.1, DNS 1.1.1.1,9.9.9.9), disco entero, nombre `almi-odoo`, usuario `almiadmin`, **Install OpenSSH server**.
3. Al terminar: `sudo apt update && sudo apt full-upgrade -y`.
4. Cortafuegos: solo SSH, HTTP y HTTPS desde las redes internas:

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
for p in 22 80 443; do sudo ufw allow from 192.168.0.0/16 to any port $p proto tcp; done
sudo ufw enable
sudo ufw status verbose
```

![Cortafuegos activo con SSH, HTTP y HTTPS solo desde 192.168.0.0/16](capturas/01-cortafuegos-ufw.png)

### 2. Docker y Odoo (E03)

```bash
sudo apt install -y docker.io docker-compose-v2
sudo systemctl enable --now docker
sudo mkdir -p /opt/odoo/config
sudo chmod 700 /opt/odoo
echo "DB_PASSWORD=$(openssl rand -base64 24)" | sudo tee /opt/odoo/.env
sudo chmod 600 /opt/odoo/.env
```

`almiadmin` **no** se mete en el grupo `docker` (ese grupo equivale a ser root): siempre `sudo docker`.

Se copian [`config/docker-compose.yml`](config/docker-compose.yml) a `/opt/odoo/docker-compose.yml` y [`config/odoo.conf`](config/odoo.conf) a `/opt/odoo/config/odoo.conf` (con la contraseña maestra del gestor) y se arranca:

```bash
sudo chmod 644 /opt/odoo/config/odoo.conf
sudo docker compose --project-directory /opt/odoo up -d
```

> Como `/opt/odoo` tiene permisos 700, `almiadmin` no puede hacer `cd /opt/odoo`. Por eso todos los comandos usan `--project-directory /opt/odoo` con `sudo`.

![Versiones de Docker y permisos de /opt/odoo](capturas/02-docker-version.png)

![Los dos contenedores en marcha y Odoo respondiendo en 127.0.0.1:8069](capturas/03-odoo-contenedores.png)

### 3. HTTPS interno con nginx (E04)

Certificado propio para la IP del servidor (válido 825 días) y nginx delante de Odoo. La configuración completa está en [`config/nginx-odoo.conf`](config/nginx-odoo.conf): redirige el puerto 80 al 443, solo permite TLS 1.2 y 1.3 y pasa a Odoo las cabeceras `X-Forwarded-*` (por eso `odoo.conf` lleva `proxy_mode = True`).

```bash
sudo apt install -y nginx
sudo mkdir -p /etc/ssl/almichain
sudo openssl req -x509 -nodes -newkey rsa:2048 -days 825 \
  -keyout /etc/ssl/almichain/odoo.key -out /etc/ssl/almichain/odoo.crt \
  -subj "/C=ES/ST=Bizkaia/L=Bilbao/O=Almi-Chain/CN=192.168.10.30" \
  -addext "subjectAltName=IP:192.168.10.30"
sudo chmod 600 /etc/ssl/almichain/odoo.key
sudo cp nginx-odoo.conf /etc/nginx/sites-available/odoo
sudo ln -s /etc/nginx/sites-available/odoo /etc/nginx/sites-enabled/odoo
sudo rm /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl reload nginx
```

![nginx correcto, HTTPS respondiendo y HTTP redirigiendo a HTTPS](capturas/04-nginx-https.png)

![Certificado con la IP 192.168.10.30, clave privada solo para root, 443 abierto y 8069 cerrado desde la red](capturas/05-certificado.png)

En los dos Windows se instala el certificado como de confianza con [`../01-windows-gerente-tpv/scripts/3-certificado-odoo.ps1`](../01-windows-gerente-tpv/scripts/3-certificado-odoo.ps1). Así Edge muestra el candado sin avisos.

### 4. Base de datos `almichain` (E05)

En el navegador, `https://192.168.10.30` → formulario de creación: contraseña maestra, base `almichain`, correo del administrador, idioma **Spanish (ES)**, país **Spain**, sin datos de demostración.

![Formulario de creación de la base de datos almichain](capturas/06-crear-base-de-datos.png)

![Base creada: pantalla de acceso de Odoo](capturas/07-base-creada-primer-acceso.png)

Después se oculta el gestor de bases de datos para que nadie pueda borrarlas o copiarlas desde la web. Al final de `odoo.conf`:

```ini
list_db = False
dbfilter = ^almichain$
```

```bash
sudo docker compose --project-directory /opt/odoo restart odoo
```

![El gestor de bases de datos queda desactivado](capturas/08-gestor-bd-oculto.png)

### 5. Aplicaciones, empresa, usuarios, productos, TPV y regla (E05 a E10)

Todo esto se hizo en la interfaz de Odoo siguiendo la guía y se dejó también en un script, [`scripts/configurar_odoo.py`](scripts/configurar_odoo.py), que lo rehace por XML-RPC en unos minutos si hay que reinstalar (las contraseñas se pasan como variables de entorno, no están en el script):

```bash
export ODOO_URL=https://192.168.10.30 ODOO_CA=/etc/ssl/almichain/odoo.crt
export ODOO_ADMIN_LOGIN=... ODOO_ADMIN_PASS=... ODOO_GERENTE_PASS=... ODOO_BARRA1_PASS=... ODOO_BARRA2_PASS=...
python3 scripts/configurar_odoo.py
```

**Aplicaciones**: Facturación, Punto de venta, CRM, Empleados, Marketing por correo electrónico, Inventario y Reglas de automatización.

![Aplicaciones instaladas](capturas/09-aplicaciones-instaladas.png)

**Empresa**: Almi Bites Restaurantes, Bilbao, EUR, con el logotipo de la web.

![Datos de la empresa](capturas/10-empresa.png)

**Usuarios con mínimo privilegio** (E06):

| Usuario | Inicio de sesión | Permisos |
|---|---|---|
| Gerente | gerente@almichain.local | Facturación: Facturación · TPV: Administrador · CRM: Administrador · Empleados: Administrador · Inventario: Administrador · Marketing: Usuario · **sin Ajustes** |
| Camarero Barra 1 | barra1@almichain.local | Solo Punto de venta: Usuario |
| Camarero Barra 2 | barra2@almichain.local | Solo Punto de venta: Usuario |

![Usuarios de Odoo](capturas/11-usuarios.png)

![Camarero Barra 1: solo Punto de venta como Usuario](capturas/12-permisos-camarero-barra1.png)

![Permisos del Gerente](capturas/13-permisos-gerente.png)

**Empleados**: Gorka Larrea (Gerente, Dirección, usuario Gerente), Nerea Olabarria (Camarera, Sala, usuario Camarero Barra 1), Asier Landa (Camarero, Sala, usuario Camarero Barra 2) y Miren Agirre (Cocinera, Cocina).

![Empleados](capturas/14-empleados.png)

**Productos** (E07): 4 bebidas y 4 platos, tipo Bienes con **Rastrear inventario**, **IVA 10 % (hostelería) con el precio con IVA incluido**, disponibles en el TPV en las categorías Bebidas y Platos, 50 unidades de stock inicial. **Clientes**: Ane Etxeberria, Jon Arrieta y Lucía Martín.

![Productos con su stock (después de la prueba de venta)](capturas/15-productos-stock.png)

![Producto con IVA 10 % hostelería](capturas/16-producto-iva-tpv.png)

![Clientes](capturas/17-clientes.png)

**TPV** (E08): **Barra 1** (`config_id=1`) y **Barra 2** (`config_id=2`), cada uno con **Tarjeta** y su propia caja de **Efectivo** (Odoo no deja compartir un método de efectivo entre dos TPV), cabecera y pie del recibo e **impresión automática** sin vista previa.

![Panel del Punto de venta con Barra 1 y Barra 2](capturas/22-tpv-panel.png)

![Ajustes de Barra 1: métodos de pago](capturas/23-tpv-ajustes-barra1.png)

**Correo saliente** (E09): servidor `smtp.gmail.com`, puerto 587, STARTTLS, usuario `almichain.reto@gmail.com`. La **contraseña de aplicación** de Gmail se escribe a mano en Odoo y se guarda en KeePassXC.

![Servidor de correo de Gmail](capturas/21-servidor-correo-gmail.png)

**Factura automática** (E10): regla **TPV - Facturar pedidos con cliente** sobre *Pedidos de TPV*, que se dispara cuando el estado pasa a **Pagado** y el pedido tiene cliente:

```python
for order in records:
    if order.partner_id and not order.account_move:
        order.action_pos_order_invoice()
```

![Reglas de automatización](capturas/18-reglas-automatizacion.png)

![Código de la regla de factura automática](capturas/19-regla-factura-automatica.png)

### 6. Prueba de principio a fin (E12)

Con el usuario **Camarero Barra 1** se abre la caja de **Barra 1**, se marcan una caña, un refresco y una hamburguesa, se elige la clienta **Ane Etxeberria** y se cobra en efectivo. Después, con **Camarero Barra 2**, una venta en **Barra 2** a **Jon Arrieta**.

| | Barra 1 | Barra 2 |
|---|---|---|
| Apertura de caja | ![](capturas/25-barra1-1-apertura-caja.png) | ![](capturas/26-barra2-1-apertura-caja.png) |
| Pedido con cliente | ![](capturas/25-barra1-2-pedido.png) | ![](capturas/26-barra2-2-pedido.png) |
| Pago | ![](capturas/25-barra1-3-pago.png) | ![](capturas/26-barra2-3-pago.png) |

El ticket que se manda a la impresora (con la cabecera y el pie configurados):

| Ticket de Barra 1 | Ticket de Barra 2 |
|---|---|
| ![](capturas/25-barra1-4-ticket.png) | ![](capturas/26-barra2-4-ticket.png) |

Resultado visto por el **Gerente**:

![Los dos pedidos, cada uno en su TPV](capturas/27-pedidos-tpv.png)

![Las dos facturas creadas y publicadas solas](capturas/28-facturas-publicadas.png)

![Factura INV/2026/00001 publicada y pagada, con IVA 10 %](capturas/29-factura-con-correo.png)

![El stock ha bajado en lo vendido](capturas/30-stock-despues-de-vender.png)

![Correos de las facturas con el PDF adjunto, en la cola de salida](capturas/33-cola-de-correos.png)

### 7. Copia de seguridad de Odoo (E11)

Script [`scripts/copia-odoo.sh`](scripts/copia-odoo.sh) en `/usr/local/bin/`, todos los días a las **02:30** con cron de root. Guarda la base de datos (`pg_dump` en formato propio), los adjuntos (`filestore`), las huellas SHA-256, borra las copias de más de 7 días y lo manda todo a **ALMI-BD** por SSH con una clave que solo sirve para eso (ver [07-bd-raid-copias](../07-bd-raid-copias/README.md#copias-cruzadas)).

![Copia hecha, guardada en local y en ALMI-BD, y programada en cron](capturas/34-copia-odoo.png)

Prueba de restauración en una base nueva `almichain_restaurada`: tiene el mismo número de pedidos que la original.

![Restauración de la copia de Odoo](capturas/35-restauracion-odoo.png)

### 8. Máquina virtual exportada

ALMI-ODOO está exportada como `ALMI-ODOO.ova` (ver [docs/maquinas-virtuales.md](../docs/maquinas-virtuales.md)). Se probó arrancándola desde cero: en el primer arranque carga las imágenes de Docker que lleva dentro (no necesita Internet), restaura la base `almichain` con los datos de este bloque, arranca Odoo y aplica el cortafuegos. Al terminar, Odoo responde por HTTPS con los 2 pedidos de la prueba.

![VM importada: primer arranque terminado, contenedores en marcha, HTTPS 200, los pedidos restaurados y el cortafuegos](capturas/36-vm-ova-primer-arranque.png)

## Seguridad aplicada

- **Solo HTTPS**: nginx redirige el 80 al 443; Odoo solo escucha en 127.0.0.1. Certificado propio instalado como de confianza en los Windows.
- **Cortafuegos** ufw: entrada denegada salvo 22, 80 y 443 desde 192.168.0.0/16.
- **Gestor de bases de datos oculto** (`list_db = False`) y contraseña maestra larga.
- **Mínimo privilegio** en Odoo: los camareros solo usan el TPV; el gerente no tiene Ajustes; solo el administrador configura.
- **Secretos fuera del repositorio**: `.env`, `odoo.conf` real, clave del certificado y contraseñas en KeePassXC.
- `almiadmin` sin grupo `docker`; `/opt/odoo` y las copias con permisos 700.
- Copias diarias en otra máquina (regla 3-2-1 junto con las de la BD).

## Pruebas

| Nº | Qué se prueba | Cómo | Resultado esperado | Resultado obtenido | Captura |
|---|---|---|---|---|---|
| 1 | Odoo solo por HTTPS | `curl -I http://192.168.10.30/` | 301 a https y candado | 301 Moved Permanently → https | [04](capturas/04-nginx-https.png) |
| 2 | Puerto 8069 cerrado desde fuera | `nc -zv 192.168.10.30 8069` (en Windows: `Test-NetConnection`) | Conexión rechazada | Connection refused | [05](capturas/05-certificado.png) |
| 3 | Gestor de bases de datos oculto | Abrir `/web/database/manager` | No se abre | "The database manager has been disabled" | [08](capturas/08-gestor-bd-oculto.png) |
| 4 | Camareros sin facturación | Entrar como Camarero Barra 1 | Sin menús de Facturación, Inventario ni CRM | Solo Punto de venta (y apps comunes: Conversaciones, Calendario, Contactos, Empleados) | [31](capturas/31-camarero-solo-tpv.png) |
| 5 | Caso real completo | Venta con cliente en Barra 1 y Barra 2 | Pedido facturado, factura publicada, correo con PDF y stock bajado | Correcto. Los correos quedan en cola hasta poner la contraseña de Gmail | [27](capturas/27-pedidos-tpv.png) [28](capturas/28-facturas-publicadas.png) [30](capturas/30-stock-despues-de-vender.png) [33](capturas/33-cola-de-correos.png) |
| 6 | Ticket impreso | Cobrar en cada barra | Ticket con cabecera y pie | Ticket generado con cabecera y pie (impresora física: ver bloque 01) | [ticket 1](capturas/25-barra1-4-ticket.png) [ticket 2](capturas/26-barra2-4-ticket.png) |
| 7 | Copia y restauración | Restaurar en `almichain_restaurada` | Mismo número de pedidos | 2 y 2 | [35](capturas/35-restauracion-odoo.png) |
| 8 | VM exportada | Arrancar `ALMI-ODOO.ova` desde cero | Odoo por HTTPS con los datos del reto | HTTPS 200 y 2 pedidos | [36](capturas/36-vm-ova-primer-arranque.png) |

## Problemas encontrados y solución

| Problema | Causa | Solución |
|---|---|---|
| `cd /opt/odoo` da *Permission denied* | La carpeta tiene permisos 700 (solo root) a propósito | Usar `sudo docker compose --project-directory /opt/odoo …` |
| El cliente recibía **dos correos** por factura (uno sin PDF y con "Ref n/a") | En Odoo 18, al facturar un pedido del TPV a un cliente con correo, Odoo ya envía la factura en PDF. La regla 2 de la guía ("enviar al publicar") lo duplicaba, y además saltaba antes de que la factura tuviera número | Se quitó la regla 2. Queda solo la regla 1 (facturar) y el envío lo hace Odoo |
| Al abrir caja salía "configure la dirección de correo del remitente" | Los usuarios de los camareros no tenían correo en su contacto | Poner correo a cada usuario (gerente@, barra1@, barra2@almichain.local) |
| Los PDF de las facturas tardaban un minuto | wkhtmltopdf, dentro del contenedor, pedía los estilos a `https://192.168.10.30` | Parámetro del sistema `report.url = http://127.0.0.1:8069` |
| No se podía compartir el efectivo entre Barra 1 y Barra 2 | Odoo exige un método de efectivo por TPV | Un diario de caja por barra: "Efectivo Barra 1" y "Efectivo Barra 2" |
| La ACL de Packet Tracer de la guía solo dejaba el puerto 80 a los TPV | Odoo se usa por HTTPS | Se añade `eq 443` en la ACL `TPV-SOLO-ODOO` (bloque 04) |
| El camarero puede abrir la lista de facturas si escribe la dirección a mano | El grupo "Punto de venta: Usuario" necesita leer facturas para reimprimirlas | No tiene menú de Facturación ni puede modificarlas. Se documenta como riesgo aceptado |

## Fuentes

- Documentación de Odoo 18: Punto de venta, Facturación y Reglas de automatización — https://www.odoo.com/documentation/18.0/
- Imagen oficial de Odoo en Docker Hub — https://hub.docker.com/_/odoo
- nginx como proxy inverso de Odoo — https://www.odoo.com/documentation/18.0/administration/on_premise/deploy.html
- Guías paso a paso del equipo: [`00-gestion/Guias-paso-a-paso-Reto1-Almi-Chain.docx`](../00-gestion/Guias-paso-a-paso-Reto1-Almi-Chain.docx), parte 6
