# Anexo. Máquinas virtuales exportadas

Las tres máquinas Linux del reto están exportadas en formato **OVA** (Open Virtualization Format, OVF 1.0) para importarlas en VirtualBox ya configuradas. Las .ova no están dentro del repositorio (GitHub no admite archivos de ese tamaño): se entregan aparte, partidas en trozos de menos de 400 MB (`ALMI-ODOO.ova.parte1`, `parte2`…) cuando hace falta, cada una con su huella `.sha256`. Las huellas también están en [`ova-sha256.txt`](ova-sha256.txt) para comprobar que lo descargado es lo entregado.

> **Cómo se han hecho y probado.** Las OVA no se crearon con el instalador de Ubuntu en VirtualBox, sino con los scripts de [`herramientas/construir-vm`](../herramientas/README.md) (Ubuntu instalado con `debootstrap`, con los mismos paquetes y archivos que los README). Se han probado arrancando sus discos en **QEMU**, no en VirtualBox, que no estaba disponible donde se prepararon. **La importación en VirtualBox está pendiente de comprobar en clase** (prueba 1 de la tabla de abajo).

## Unir los trozos

Descargar todos los trozos, el `.sha256` de cada .ova y los scripts en **la misma carpeta**:

- **Zorin / Linux**: `bash unir-ova-linux.sh` → une los trozos, comprueba la huella de **todas** las .ova (también las que no van partidas) y borra los trozos si está bien.
- **Windows**: doble clic en `unir-ova-windows.bat` → une los trozos y comprueba las huellas con PowerShell (`OK` o `HUELLA DISTINTA`).

A mano en Linux: `cat ALMI-ODOO.ova.parte1 ALMI-ODOO.ova.parte2 ALMI-ODOO.ova.parte3 > ALMI-ODOO.ova` y `sha256sum -c ALMI-ODOO.ova.sha256`.

| Archivo | Máquina | Hardware | Red | Qué hace la primera vez que arranca |
|---|---|---|---|---|
| `ALMI-ODOO.ova` | Servidor del ERP | 3 GB · 2 CPU · disco de 25 GB | IP fija 192.168.10.30 | Genera sus secretos (certificado HTTPS, contraseñas de PostgreSQL y maestra de Odoo, claves SSH), carga Odoo 18 y PostgreSQL 16 en Docker, restaura la base `almichain` con los datos del reto y aplica el cortafuegos. Tarda unos minutos. Después: `https://192.168.10.30` |
| `ALMI-BD.ova` | Servidor de base de datos | 2 GB · 2 CPU · disco de 15 GB + **2 discos de 10 GB** | IP fija 192.168.10.20 | Crea el **RAID 1** con los dos discos vacíos y mueve encima los datos de MariaDB; crea los 3 usuarios de MariaDB con contraseñas nuevas; cortafuegos; claves SSH |
| `ALMI-ARCADE.ova` | Recreativa | **1 GB · 1 CPU** · disco de 8 GB · sin swap · tarjeta de sonido | DHCP | Entra sola como `arcade` y abre MAME |

Los dos Windows (ALMI-GERENTE y ALMI-TPV) no se exportan: necesitan la ISO y la licencia de Windows de clase. Se preparan con los scripts de [`01-windows-gerente-tpv`](../01-windows-gerente-tpv/README.md).

## Importar

1. Crear la **Red NAT ALMICHAIN** si no existe ([00-gestion](../00-gestion/README.md#red-nat-almichain)), con el reenvío de puertos en **127.0.0.1**.
2. **Archivo → Importar servicio virtualizado** → elegir la `.ova` → **Siguiente**.
3. En la lista de ajustes, en **Política de dirección MAC** elegir *Generar nuevas direcciones MAC para todos los adaptadores de red* → **Terminar**.
4. Con la VM importada y apagada: **Configuración → Red → Adaptador 1 → Conectado a: Red NAT → Nombre: ALMICHAIN**.
5. Solo en ALMI-ARCADE: comprobar **Configuración → Pantalla → Controlador gráfico: VMSVGA** y **Audio: habilitado** (el archivo OVF estándar no guarda el controlador gráfico; VirtualBox pone el de Ubuntu de 64 bits). Para el stick, **USB → filtro** con el Arduino.
6. Arrancar. ALMI-ODOO y ALMI-BD tienen que estar en el **mismo PC** y en la misma Red NAT para que funcionen las copias cruzadas.

## Primer acceso y secretos

**Ninguna VM lleva secretos propios de serie**: cada copia importada genera los suyos la primera vez que arranca, así dos equipos que importen la misma OVA no comparten contraseñas ni certificados.

| Máquina | Qué se genera | Dónde queda |
|---|---|---|
| ALMI-ODOO y ALMI-BD | Claves de host SSH (`ssh-keygen -A` justo antes de arrancar el servidor SSH) | `/etc/ssh/ssh_host_*` |
| ALMI-ODOO | Contraseña de PostgreSQL | `/opt/odoo/.env` (solo root) |
| ALMI-ODOO | Contraseña maestra de Odoo y certificado HTTPS (`CA:FALSE`) | `/root/credenciales-primer-arranque.txt` (solo root) y `/etc/ssl/almichain/`. La **huella del certificado** sale también en la consola, encima de `login:`, para comprobarla en los Windows |
| ALMI-BD | Contraseñas de `app_almichain`, `consulta` y `copias` | `/root/credenciales-primer-arranque.txt` (solo root); la de `copias` en `/root/.my.cnf` y la de `consulta` en `~almiadmin/.consulta.cnf` |

Pasos la primera vez:

1. Entrar como `almiadmin` con la **contraseña inicial**, que el equipo entrega aparte (no está en el repositorio). El sistema **obliga a cambiarla** en ese momento (`chage -d 0`).
2. `sudo cat /root/credenciales-primer-arranque.txt` → pasar los secretos a KeePassXC → `sudo shred -u /root/credenciales-primer-arranque.txt`.
3. En ALMI-ODOO: los usuarios web de Odoo (administrador, gerente y los dos camareros) vienen con las contraseñas de la base de datos de ejemplo: cambiarlas en Odoo (**Preferencias → Seguridad de la cuenta**).

**Lo que sí comparten todas las copias**: la pareja de claves de las copias cruzadas (`/root/.ssh/copias_ed25519`), para que funcionen nada más importar las dos VM. Esa clave solo sirve desde la IP del otro servidor y solo para escribir en su carpeta de copias (`rrsync -wo -no-del`). Para cambiarla:

```bash
# En ALMI-ODOO (y lo mismo al revés en ALMI-BD, con sus IP y carpetas)
sudo ssh-keygen -t ed25519 -N '' -C copias-odoo -f /root/.ssh/copias_ed25519   # sobrescribir: y
sudo cat /root/.ssh/copias_ed25519.pub
# En ALMI-BD, sustituir la clave de la línea de /home/copias/.ssh/authorized_keys, sin tocar el principio:
# command="/usr/bin/rrsync -wo -no-del /srv/copias-remotas/odoo/",from="192.168.10.30",restrict ssh-ed25519 <clave nueva>
```

## Usuarios

| Máquina | Usuarios |
|---|---|
| Las tres | `almiadmin` (administrador, sudo; cambia la contraseña inicial al entrar) |
| ALMI-ARCADE | `arcade` (sin privilegios, entra solo) |
| Odoo (web) | administrador `almichain.reto@gmail.com`, `gerente@almichain.local`, `barra1@almichain.local`, `barra2@almichain.local` |
| MariaDB | `app_almichain`, `consulta`, `copias` (root solo por `sudo mariadb`) |

## Acceso desde el PC de clase

Con el reenvío de puertos de la red ALMICHAIN (ver [00-gestion](../00-gestion/README.md#red-nat-almichain)):

```bash
ssh -p 2230 almiadmin@localhost     # ALMI-ODOO
ssh -p 2220 almiadmin@localhost     # ALMI-BD
# Odoo en el navegador del PC: https://localhost:8443 (el certificado incluye localhost)
```

## Pruebas de las OVA

| Nº | Qué se prueba | Dónde | Resultado |
|---|---|---|---|
| 1 | Importar cada .ova en VirtualBox 7 y arrancarla | VirtualBox en clase | **Pendiente — en clase** |
| 2 | Huellas y formato | `sha256sum -c` y lectura del `.ovf` | Ver informe de auditoría |
| 3 | Primer arranque de cada VM desde cero | QEMU | Ver los apartados "VM exportada" de los bloques [02](../02-linux-recreativa/README.md), [05](../05-erp-odoo/README.md) y [07](../07-bd-raid-copias/README.md) |

## Si algo no va

| Síntoma | Solución |
|---|---|
| La VM no tiene red | Comprobar que el adaptador está en *Red NAT → ALMICHAIN* y `ip -br a` dentro de la VM. La red se configura para cualquier interfaz `en*` |
| Odoo no responde tras 15 minutos | `sudo systemctl status almi-primer-arranque` y `sudo tail -50 /var/log/almi-primer-arranque.log` |
| nginx sale como fallido justo después del primer arranque | Es normal mientras el primer arranque no ha creado el certificado; al terminar lo reinicia. Si sigue: `sudo systemctl restart nginx` |
| ALMI-BD no crea el RAID | Comprobar que tiene los dos discos de 10 GB en el controlador SATA (`lsblk`). Registro: `/var/log/almi-crear-raid.log`. Se puede lanzar a mano: `sudo /usr/local/sbin/almi-crear-raid.sh` |
| MariaDB no arranca en ALMI-BD | A propósito no arranca si el RAID no está montado: `cat /proc/mdstat`, `findmnt /var/lib/mysql` |
| La recreativa se queda en negro | Controlador gráfico VMSVGA. Para entrar a administrar: Ctrl + Alt + F2 |
