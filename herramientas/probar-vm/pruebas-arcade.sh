#!/bin/bash
# Almi-Chain · Pruebas de ALMI-ARCADE en QEMU, desde cero, guardando las transcripciones
#
#   CLAVE_INICIAL=... CLAVE_NUEVA=... ./pruebas-arcade.sh <carpeta con ALMI-ARCADE.raw> <carpeta de capturas>
#
# 1. Arranque como en VirtualBox (BIOS → GRUB, sin consola serie): captura de la pantalla con MAME.
# 2. Arranque por consola serie: núcleo, memoria y swap; usuarios y seguridad; MAME; servicios;
#    registro de vmstat con MAME abierto (al menos 60 muestras); benchmark (funcional: sin KVM
#    los porcentajes no dicen nada de la velocidad real).
set -euo pipefail
AQUI=$(cd "$(dirname "$0")" && pwd)
RAW=${1:?Carpeta con ALMI-ARCADE.raw}
CAP=${2:?Carpeta donde guardar las transcripciones}
: "${CLAVE_INICIAL:?}" "${CLAVE_NUEVA:?}"
TRABAJO=${TRABAJO:-/var/tmp/almi-qemu}
VM="$AQUI/qemu-vm.sh"
limpia() { grep -v '^\[ *[0-9]' || true; }

# --- 1. Pantalla al arrancar por GRUB ---
"$VM" arrancar arcade-grub 1024 1 grub "$RAW/ALMI-ARCADE.raw"
for _ in $(seq 1 60); do
  sleep 20; "$VM" pantalla arcade-grub "$CAP/01-arranque-mame.png" >/dev/null 2>&1 || continue
  [ "$(stat -c %s "$CAP/01-arranque-mame.png")" -gt 15000 ] && break   # ya no es la consola negra
done
sleep 30; "$VM" pantalla arcade-grub "$CAP/01-arranque-mame.png" >/dev/null
"$VM" parar arcade-grub

# --- 2. Consola serie ---
S=$TRABAJO/arcade/serie.sock; C="python3 $AQUI/consola.py $S"
"$VM" arrancar arcade 1024 1 serie "$RAW/ALMI-ARCADE.raw"
timeout 1500 python3 "$AQUI/consola.py" "$S" entrar almiadmin "$CLAVE_INICIAL" "$CLAVE_NUEVA"
sudo_v() { $C escribir "sudo -v"; $C escribir "$CLAVE_NUEVA"; }
sudo_v
$C transcribir "$CAP/02-nucleo-memoria-swap.txt" 120 "nproc" "free -m" "swapon --show" "ls -l /swap.img" "cat /proc/cmdline" | limpia
$C transcribir "$CAP/03-usuarios-seguridad.txt" 120 "groups arcade; groups almiadmin" "sudo -l -U arcade" "ls -ld /home/*" \
  "ls -l /etc/profile.d/recreativa.sh /usr/local/bin/recreativa-sesion" \
  "grep '^minlen' /etc/security/pwquality.conf; dpkg-query -W -f='\${Package} \${Status}\n' cracklib-runtime libpam-pwquality" \
  "sudo ufw status verbose" "systemctl is-enabled ssh ssh.socket" | limpia
$C transcribir "$CAP/04-mame-version-juegos.txt" 300 "/usr/games/mame -version" "/usr/games/mame -listroms pong breakout" \
  "ps -o user,pid,args -u arcade | grep -E 'Xorg|mame|vmstat' | grep -v grep" | limpia
$C transcribir "$CAP/05-servicios-optimizados.txt" 120 \
  "systemctl list-units --type=service --state=running --no-legend --plain | awk '{print \$1}'" \
  "systemctl list-timers --no-legend | awk '{print \$NF, \$(NF-1)}'" "cat /etc/systemd/journald.conf.d/arcade.conf" \
  "systemctl is-enabled apt-daily.timer unattended-upgrades motd-news.timer 2>&1" | limpia
# vmstat guarda una muestra cada 5 s mientras MAME está abierto
until $C orden 60 "sudo sh -c 'cat /home/arcade/rendimiento/vmstat-*.log 2>/dev/null' | grep -c '^ *[0-9]'" 2>/dev/null | tail -1 | awk '{exit !($1>=60)}'; do sleep 30; done
sudo_v
$C transcribir "$CAP/06-vmstat.txt" 120 "sudo ls -l /home/arcade/rendimiento/" \
  "sudo sh -c 'tail -n 12 /home/arcade/rendimiento/vmstat-*.log'" \
  "sudo sh -c 'cat /home/arcade/rendimiento/vmstat-*.log' | awk '\$1 ~ /^[0-9]+\$/ {n++; if (\$3>s) s=\$3; if (\$7>a) a=\$7; if (\$8>b) b=\$8} END {print n \" muestras; máximo de swpd=\" s+0 \", si=\" a+0 \", so=\" b+0}'" | limpia
sudo_v
$C transcribir "$CAP/07-benchmark-en-qemu.txt" 3600 "sudo benchmark-recreativa pong" | limpia
"$VM" parar arcade
echo "Pruebas de ALMI-ARCADE terminadas: $CAP"
