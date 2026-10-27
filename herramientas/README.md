# Herramientas: cómo se han hecho las máquinas virtuales, las pruebas y la memoria

Esta carpeta no es un bloque del reto. Está para que cualquiera pueda **comprobar y repetir** cómo se han hecho las tres máquinas virtuales exportadas (`.ova`), sus pruebas y las capturas de terminal. Sin ella, las OVA serían una caja negra.

## Qué hay

| Carpeta | Para qué |
|---|---|
| [`construir-vm/`](construir-vm/) | Scripts que construyen los discos de ALMI-ODOO, ALMI-BD y ALMI-ARCADE y los empaquetan en `.ova` |
| [`probar-vm/`](probar-vm/) | Scripts para arrancar esos discos en QEMU, manejarlos por consola serie, guardar la transcripción de cada prueba y dibujar la captura de terminal a partir de ella |
| [`memoria/`](memoria/) | Generador de la memoria en Word/PDF a partir de los README |

## Cómo se construyen las VM (y en qué se diferencia de los README)

Los README de los bloques 02, 05 y 07 explican la instalación **como la haríamos en clase**: VirtualBox, ISO de Ubuntu Server 24.04 y el instalador. Las OVA **no** se hicieron así, porque donde se preparó el repositorio no había VirtualBox (es un servidor Linux sin entorno gráfico). Se hicieron así:

1. `debootstrap` instala Ubuntu 24.04 (noble) en un disco `.raw` montado con un dispositivo *loop*.
2. Dentro (con `chroot`) se instalan los mismos paquetes y se copian **los mismos archivos del repositorio** que usan los README: `docker-compose.yml`, `odoo.conf`, `nginx-odoo.conf`, los scripts de copias, del RAID y de primer arranque, el SQL, la configuración de la recreativa…
3. GRUB para arranque por BIOS, con un `grub.cfg` escrito a mano (por UUID).
4. [`hacer-ova.py`](construir-vm/hacer-ova.py) convierte los discos a VMDK y escribe el `.ovf` y el manifiesto `.mf` con las huellas SHA-256.

Diferencias con una instalación hecha con el instalador: **no hay LVM** (una sola partición ext4), no se instala nada que el instalador ponga y aquí no haga falta (por eso es más pequeña), y la imagen no lleva **claves de servidor ni contraseñas de servicio**: cada VM importada pone el cortafuegos antes de que haya red y genera en su primer arranque sus claves de host SSH, su certificado HTTPS, sus contraseñas de PostgreSQL, la maestra de Odoo, las de los usuarios de Odoo y el secreto de sesiones de Odoo (ODOO), y las de los usuarios de MariaDB (BD). La contraseña de `almiadmin` es una inicial que **obliga a cambiarla** la primera vez que se entra (`chage -d 0`).

Lo que comparten todas las copias de las OVA es la contraseña inicial de `almiadmin` (obligatorio cambiarla) y la pareja de claves de las **copias cruzadas** (para que funcionen nada más importar las dos VM). Esa clave solo puede escribir en la carpeta de copias del otro servidor y solo desde su IP (`rrsync -wo -no-del`, `from=`). Para cambiarla, ver [docs/maquinas-virtuales.md](../docs/maquinas-virtuales.md).

### Construirlas

En un Ubuntu 24.04 con `debootstrap`, `qemu-utils`, `grub-pc-bin` y `docker` (para sacar los datos de Odoo), como root:

```bash
cd herramientas/construir-vm
# Contraseñas iniciales (FUERA del repositorio): ALMIADMIN_PASS=... y ARCADE_PASS=...
export CREDENCIALES=/root/credenciales-vm.txt CLAVES=/root/claves-copias SALIDA=/var/tmp/almi-vm

./sacar-datos-odoo.sh /var/tmp/datos-odoo /opt/odoo   # de un Odoo ya configurado (configurar_odoo.py)
./construir-odoo.sh /var/tmp/datos-odoo
./construir-bd.sh
./construir-arcade.sh

./hacer-ova.py ALMI-ODOO 3072 2 "Servidor Odoo 18" $SALIDA/ALMI-ODOO.raw
./hacer-ova.py ALMI-BD 2048 2 "Servidor MariaDB con RAID 1" $SALIDA/ALMI-BD.raw $SALIDA/ALMI-BD-raid1.raw $SALIDA/ALMI-BD-raid2.raw
./hacer-ova.py --audio ALMI-ARCADE 1024 1 "Recreativa MAME" $SALIDA/ALMI-ARCADE.raw
./partir-ova.sh $SALIDA/ALMI-ODOO.ova      # trozos de 380 MB + huella
```

Si hace falta un proxy con certificado propio para descargar paquetes: `APT_CA=/ruta/ca.crt`.

## Cómo se prueban

[`probar-vm/qemu-vm.sh`](probar-vm/qemu-vm.sh) arranca un disco en QEMU **a través de una capa qcow2**, así la prueba (primer arranque, RAID, cambio de contraseña…) no toca el disco que se empaqueta. Dos modos:

- `grub`: arranca como VirtualBox (BIOS → GRUB del disco). Sirve para ver que la imagen entregada arranca sola; se mira la pantalla con `qemu-vm.sh pantalla`.
- `serie`: arranca el núcleo de la propia imagen añadiendo `console=ttyS0`, para manejarla por consola serie con [`consola.py`](probar-vm/consola.py).

Todas las VM arrancadas así comparten una red (como la Red NAT ALMICHAIN), así que ALMI-ODOO y ALMI-BD pueden hacerse las copias cruzadas.

Los guiones de prueba se ejecutan en este orden (cada uno deja su transcripción en la carpeta `capturas/` del bloque):

```bash
cd herramientas/probar-vm
export CLAVE_INICIAL=... CLAVE_NUEVA=...          # contraseña inicial de almiadmin y la nueva
./pruebas-odoo.sh  $SALIDA ../../05-erp-odoo/capturas 2560    # deja ALMI-ODOO encendida
./pruebas-bd.sh    $SALIDA ../../07-bd-raid-copias/capturas   # deja ALMI-BD encendida
./pruebas-copias.sh ../../05-erp-odoo/capturas ../../07-bd-raid-copias/capturas
./pruebas-arcade.sh $SALIDA ../../02-linux-recreativa/capturas
```

**Límites de estas pruebas** (dichos también en cada README):

- Es **QEMU sin KVM**, no VirtualBox: el procesador está emulado (lento; no sirve para medir rendimiento) y no se prueba el importador de VirtualBox, su controlador gráfico ni su audio.
- No hay Internet dentro de la red de pruebas: el envío de correo de Odoo y las actualizaciones no se prueban.

## Cómo se hacen las capturas de terminal

1. [`consola.py`](probar-vm/consola.py) `transcribir` ejecuta las órdenes en la VM y guarda **la salida real** en un `.txt` (`$ orden` y debajo lo que sale). Solo se le quitan dos cosas, y siempre a propósito: los mensajes del núcleo que salen mezclados por la consola serie (líneas `[ 123.45…]`) y los *hash* de contraseñas, que se sustituyen por `…(hash recortado)…`.
2. [`pintar-terminal.py`](probar-vm/pintar-terminal.py) dibuja ese `.txt` como una ventana de terminal (`.png`). Añade solo el *prompt* (`usuario@host:~$`, siempre con `~`) y el título de la ventana; el resto es el texto del `.txt`.

Por eso las capturas de terminal hechas así tienen al lado un `.txt` con el mismo nombre. Las capturas del navegador (Odoo) se hicieron con Chromium sin interfaz y la barra de dirección está dibujada. Las capturas de las carpetas `05-erp-odoo/capturas/01`–`35` y `07-bd-raid-copias/capturas/01`–`12` son de un **servidor de pruebas** (ver "Origen de las evidencias" en el [README principal](../README.md)), no de las VM.

## Cómo se genera la memoria

`herramientas/memoria/generar.sh` junta los README en `docs/Documentacion-Reto1-Almi-Chain.docx` y `.pdf`. Necesita pandoc 3, `python3-docx`, Pillow, `mmdc` (la CLI de Mermaid) y LibreOffice. Los enlaces a archivos del repositorio salen como su ruta (el repositorio es privado), las figuras se numeran solas y los diagramas Mermaid se convierten en imágenes.

Las capturas no son correlativas en algunos bloques (en 05 faltan la 20 y la 24; en 07, de la 13 a la 17) porque se quitaron capturas repetidas o de una versión anterior de la VM; se mantiene la numeración para no romper referencias.
