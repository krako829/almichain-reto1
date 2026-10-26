# 2. Recreativa con MAME (1 núcleo, 1 GB, sin swap)

## Objetivo

Una máquina recreativa con **MAME** para la sala del restaurante, en un equipo muy limitado: **1 núcleo y 1 GB de RAM, sin usar el disco como memoria (swap)**. Al encenderla entra sola en MAME, sin pedir contraseña, con un usuario sin privilegios. Se mide el rendimiento antes y después de optimizar y se monitoriza mientras se juega.

Tareas del tablero: A01 a A10.

## Requisitos

| Elemento | Valor |
|---|---|
| VM | **ALMI-ARCADE** · 1 CPU · 1024 MB · disco de 8 GB · **sin swap** · gráficos VMSVGA · Red NAT ALMICHAIN (DHCP) · USB activado (arcade stick) |
| Sistema | Ubuntu 24.04 LTS mínimo (sin escritorio) |
| Software | Servidor X mínimo (`xserver-xorg-core`, `xinit`), MAME 0.264, `alsa-utils` |
| Usuarios | `almiadmin` (administrador) y `arcade` (sin sudo, entra solo y abre MAME) |

> **Decisiones del equipo.** No se hace doble arranque con el equipo del gerente: la recreativa es una VM aparte con exactamente 1 núcleo y 1 GB. Se usa **Ubuntu 24.04 mínimo** en lugar de Debian: el resultado es el mismo (sistema sin escritorio, solo X y MAME) y comparte paquetes y comandos con los servidores del reto. Como la VM tiene ya 1 núcleo y 1 GB, en GRUB se deja además `mem=1024M nr_cpus=1` para que el límite no dependa de la configuración de VirtualBox.

## Arquitectura

```mermaid
flowchart LR
  ON["Encender"] --> GRUB["GRUB<br/>mem=1024M nr_cpus=1"]
  GRUB --> SYS["Ubuntu mínimo<br/>sin swap · journald en RAM"]
  SYS --> TTY["getty tty1<br/>autologin arcade"]
  TTY --> BP[".bash_profile<br/>startx"]
  BP --> X[".xinitrc<br/>vmstat cada 5 s"]
  X --> MAME["MAME a pantalla completa"]
  STK[["Arcade stick USB"]] --> MAME
  MAME -- "al salir" --> TTY
```

## Instalación y configuración paso a paso

Los archivos están en [`config/`](config/) y [`scripts/`](scripts/).

### 1. VM e instalación (A01-A02)

1. VirtualBox → **Nueva** → ALMI-ARCADE, Ubuntu (64-bit), **1024 MB y 1 CPU**, disco de 8 GB. Pantalla: VMSVGA. Red NAT ALMICHAIN. USB activado.
2. Instalar **Ubuntu Server 24.04** en modo **minimized**, disco entero **sin swap** (en *Storage*: editar la partición y borrar el swap, o usar `swapoff -a` y quitar la línea de `/etc/fstab` al terminar), nombre `almi-arcade`, usuario `almiadmin`, **sin** OpenSSH.

### 2. 1 núcleo y 1 GB (A03)

`/etc/default/grub`:

```
GRUB_TIMEOUT=3
GRUB_CMDLINE_LINUX_DEFAULT="quiet mem=1024M nr_cpus=1"
```

`sudo update-grub` y reiniciar.

![1 núcleo, 961 MB de memoria total, swap 0 y los parámetros del núcleo](capturas/02-nucleo-memoria-swap.png)

### 3. Usuarios y seguridad (A04)

```bash
sudo useradd -m -s /bin/bash -c "Recreativa" -G audio,video,input arcade
sudo passwd arcade
sudo chmod 700 /home/arcade /home/almiadmin
sudo apt install -y libpam-pwquality      # minlen = 12 en /etc/security/pwquality.conf
sudo ufw default deny incoming && sudo ufw default allow outgoing && sudo ufw enable
```

`arcade` no está en el grupo `sudo`: no puede administrar nada.

![arcade sin sudo, carpetas privadas y cortafuegos](capturas/03-usuarios-seguridad.png)

### 4. Servidor gráfico mínimo y MAME (A05)

```bash
sudo apt install -y --no-install-recommends xserver-xorg-core xserver-xorg-input-libinput \
  xserver-xorg-video-fbdev xserver-xorg-video-vesa xinit x11-xserver-utils alsa-utils mame
mame -version
sudo mkdir -p /usr/local/share/games/mame/roms
```

**Juegos**: *Pong* y *Breakout* funcionan **sin ROMs** (MAME los emula a partir del esquema del circuito original). Para más juegos se descargan ROMs legales de mamedev.org (robby, gridlee, supertnk) a `/usr/local/share/games/mame/roms/` y se comprueban con `mame -verifyroms`. Las ROMs no se suben al repositorio.

### 5. Arranque directo a MAME (A06)

| Archivo | Dónde | Qué hace |
|---|---|---|
| [`config/autologin.conf`](config/autologin.conf) | `/etc/systemd/system/getty@tty1.service.d/override.conf` | `arcade` entra solo en la consola 1 |
| [`config/bash_profile`](config/bash_profile) | `/home/arcade/.bash_profile` (propiedad de root) | Al entrar en tty1 arranca X sin cursor |
| [`config/xinitrc`](config/xinitrc) | `/home/arcade/.xinitrc` | Desactiva el salvapantallas, guarda `vmstat` cada 5 s y abre MAME (sin sonido si la máquina no tiene tarjeta de sonido) |
| [`config/ui.ini`](config/ui.ini) | `/home/arcade/.mame/ui.ini` | El menú de MAME se abre con Pong seleccionado |

Para administrar con MAME abierto: **Ctrl + Alt + F2** y entrar como `almiadmin`.

![arcade entra solo, sin contraseña](capturas/01a-autologin-arcade.png)

![Y se abre MAME a pantalla completa con Pong seleccionado](capturas/01-arranque-mame.png)

### 6. Optimización (A08)

| Cambio | Para qué |
|---|---|
| Sin swap y `mem=1024M nr_cpus=1` | Lo pide el reto: no usar el disco como memoria |
| `journald` en memoria, máximo 20 MB | No escribir en disco mientras se juega |
| Solo 2 consolas de texto (`NAutoVTs=2`) | Menos procesos |
| Desactivados `apt-daily`, `unattended-upgrades`, `man-db`, `e2scrub`, `fstrim`, `motd-news` y SSH | Nada trabajando en segundo plano durante la partida. Las actualizaciones las hace `almiadmin` a mano una vez por semana |
| Sin `systemd-networkd-wait-online` | Arranque más rápido |
| [`config/mame.ini`](config/mame.ini) del usuario arcade | `video soft`, `waitvsync 0`, `autoframeskip 1`, `samplerate 22050`, `skip_gameinfo 1`, `joystick 1` |


### 7. Benchmark y monitorización (A07, A09)

[`scripts/benchmark.sh`](scripts/benchmark.sh) (instalado como `benchmark-recreativa`) ejecuta `mame -bench 60` tres veces por juego como el usuario `arcade` y da la media. 100 % es la velocidad real de la máquina original; más de 100 % es que sobra potencia.

Resultados con MAME 0.264 limitado a **1 núcleo**, con la configuración por defecto (antes) y con el `mame.ini` optimizado (después):

| Medida | Antes de optimizar | Después de optimizar |
|---|---|---|
| Pong (`-bench 60`, media de 3) | 297,3 % (307,95 · 298,59 · 285,23) | 315,0 % (311,16 · 317,15 · 316,58) |
| Breakout (`-bench 60`, media de 3) | 97,6 % (93,54 · 88,63 · 110,77) | 114,3 % (114,05 · 114,59 · 109,14) |
| Memoria total visible | 961 MB | 961 MB |
| Swap | 0 | 0 |

*Breakout* es el juego más exigente (simula el circuito discreto componente a componente) y es el que más nota la optimización: pasa de ir justo (por debajo de 100 % en alguna pasada) a ir sobrado en todas.

El `.xinitrc` guarda un registro de `vmstat` en `/home/arcade/rendimiento/` mientras se juega. Las columnas `si` y `so` (memoria que entra y sale del swap) tienen que estar siempre a 0.


## Seguridad aplicada

- `arcade` sin sudo, contraseña de 12 caracteres, carpeta privada; su `.bash_profile` es de root para que no pueda cambiar lo que arranca.
- Cortafuegos con toda la entrada bloqueada y **sin servidor SSH**.
- Las ROMs, solo lectura para `arcade` en una carpeta del sistema.

## Pruebas

| Nº | Qué se prueba | Cómo | Resultado esperado | Resultado obtenido | Captura |
|---|---|---|---|---|---|
| 1 | 1 núcleo | `nproc` | 1 | 1 | [02](capturas/02-nucleo-memoria-swap.png) |
| 2 | 1 GB de RAM | `free -m` | Total menor de 1024 MB | 961 MB | [02](capturas/02-nucleo-memoria-swap.png) |
| 3 | Sin swap | `swapon --show` | Sin salida | Sin salida; Swap 0 | [02](capturas/02-nucleo-memoria-swap.png) |
| 4 | No se usa swap al jugar | Registro de vmstat | `si` y `so` siempre 0 | Pendiente de captura | — |
| 5 | Arranque directo a MAME | Encender | MAME sin pedir contraseña | Autologin de arcade y MAME abierto | [01a](capturas/01a-autologin-arcade.png) [01](capturas/01-arranque-mame.png) |
| 6 | arcade sin privilegios | `groups arcade`; `sudo -l` como arcade | Sin sudo | No está en sudo | [03](capturas/03-usuarios-seguridad.png) |
| 7 | Juegos disponibles | `mame -listroms pong breakout` | No necesitan ROMs | "No ROMs required" | Pendiente de captura |
| 8 | Mejora de rendimiento | Tabla del benchmark | Igual o mayor velocidad después | Pong +6 %, Breakout +17 % | — |
| 9 | Stick en MAME | Ver bloque 03 | Se juega con el stick | | |

## Problemas encontrados y solución

| Problema | Causa | Solución |
|---|---|---|
| MAME se quedaba colgado al arrancar, con la CPU al 100 % y sin abrir ventana | El `mame.ini` tenía comentarios con tildes delante de la marca BOM que pone `mame -createconfig`, y el lector de MAME entra en un bucle | Comentarios del `mame.ini` solo en ASCII y sin BOM |
| MAME se cerraba al momento con *Segmentation fault* y la sesión se reiniciaba en bucle | MAME 0.264 falla al abrir el sonido si la VM no tiene tarjeta de sonido | El `.xinitrc` comprueba `/proc/asound/cards` y, si no hay tarjeta, arranca MAME con `-sound none`. En VirtualBox conviene activar el audio (Intel HD Audio) |
| X arrancaba solo la primera vez ("drmSetMaster failed: Permission denied") | Faltaba `libpam-systemd`: la sesión de arcade no se registraba en logind y X sin root no podía usar la pantalla | Instalar `libpam-systemd` (viene en una instalación normal de Ubuntu) |
| X no arranca con "Failed to load module fbdev/vesa" | Sin aceleración gráfica disponible, X no tenía controlador de respaldo | Instalar `xserver-xorg-video-fbdev` y `xserver-xorg-video-vesa`; en VirtualBox usar VMSVGA |
| No había ROMs legales descargables desde clase en el primer momento | | Pong y Breakout no necesitan ROMs; el resto se añade desde mamedev.org |

## Fuentes

- Documentación de MAME: opciones de línea de órdenes y `-bench` — https://docs.mamedev.org/
- ROMs gratuitas para uso no comercial — https://www.mamedev.org/roms/
- `man systemd-journald.conf`, `man agetty`, `man vmstat`
- Guías paso a paso del equipo, parte 3.
