#!/bin/bash
# Almi-Chain · Copias cruzadas entre ALMI-ODOO y ALMI-BD, con las dos VM encendidas en QEMU
# (después de pruebas-odoo.sh y pruebas-bd.sh, con sesión iniciada y sudo activo en las dos)
#
#   ./pruebas-copias.sh <capturas de 05-erp-odoo> <capturas de 07-bd-raid-copias>
set -euo pipefail
AQUI=$(cd "$(dirname "$0")" && pwd)
CO=${1:?}; CB=${2:?}
TRABAJO=${TRABAJO:-/var/tmp/almi-qemu}
O="python3 $AQUI/consola.py $TRABAJO/odoo/serie.sock"
B="python3 $AQUI/consola.py $TRABAJO/bd/serie.sock"
limpia() { grep -v '^\[ *[0-9]' || true; }
CLAVE="sudo ssh -i /root/.ssh/copias_ed25519 -o BatchMode=yes"

# ALMI-ODOO -> ALMI-BD
$O transcribir "$CO/39-vm-copia-a-almi-bd.txt" 600 \
  "sudo /usr/local/bin/copia-odoo.sh && sudo tail -1 /var/log/copia-odoo.log" \
  "sudo ls /var/backups/odoo" "sudo crontab -l | grep -v '^#'" | limpia
$B transcribir "$CB/24-vm-copias-recibidas-de-odoo.txt" 120 \
  "hostname; sudo ls -l /srv/copias-remotas/odoo" | limpia
# ALMI-BD -> ALMI-ODOO
$B transcribir "$CB/25-vm-copia-a-almi-odoo.txt" 600 \
  "sudo /usr/local/bin/copia-bd.sh && sudo tail -1 /var/log/copia-bd.log" \
  "sudo ls /var/backups/mariadb" "sudo crontab -l | grep -v '^#'" | limpia
$O transcribir "$CO/40-vm-copias-recibidas-de-bd.txt" 120 \
  "hostname; sudo ls -l /srv/copias-remotas/bd" | limpia
# Lo que la clave de copias NO puede hacer (desde ALMI-ODOO contra ALMI-BD)
$B transcribir "$CB/26-vm-clave-copias-en-almi-bd.txt" 60 \
  "hostname; sudo cat /home/copias/.ssh/authorized_keys | cut -c1-95" | limpia
$O transcribir "$CO/41-vm-clave-copias-restringida.txt" 300 \
  "$CLAVE copias@192.168.10.20 'ls /'; echo \"código \$?\"" \
  "sudo rsync -a --delete -e '$CLAVE' /var/backups/odoo/ copias@192.168.10.20: 2>&1 | head -2" \
  "sudo rsync -a -e '$CLAVE' copias@192.168.10.20:. /tmp/leer-copias 2>&1 | head -2" \
  "sudo rsync -a -e '$CLAVE' /etc/hostname copias@192.168.10.20:../ 2>&1 | head -2" | limpia
echo "Copias cruzadas probadas"
