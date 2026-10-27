#!/bin/bash
# Almi-Chain · Pruebas de ALMI-BD en QEMU, desde cero, guardando las transcripciones
#
#   CLAVE_INICIAL=... CLAVE_NUEVA=... ./pruebas-bd.sh <carpeta con los .raw> <carpeta de capturas>
#
# 1. Primer arranque con los 3 discos: RAID, MariaDB, usuarios con contraseñas nuevas, cortafuegos.
# 2. Prueba A: un disco falla con el servidor en marcha (aviso incluido) y se reconstruye.
# 3. Prueba B: se apaga, se quita un disco, se arranca con uno solo; después se pone un disco
#    nuevo vacío y se reconstruye.
# Las transcripciones (.txt) se convierten en capturas con pintar-terminal.py.
set -euo pipefail
AQUI=$(cd "$(dirname "$0")" && pwd)
RAW=${1:?Carpeta con ALMI-BD.raw, ALMI-BD-raid1.raw y ALMI-BD-raid2.raw}
CAP=${2:?Carpeta donde guardar las transcripciones}
: "${CLAVE_INICIAL:?}" "${CLAVE_NUEVA:?}"
TRABAJO=${TRABAJO:-/var/tmp/almi-qemu}; D=$TRABAJO/bd; S=$D/serie.sock
VM="$AQUI/qemu-vm.sh"; C="python3 $AQUI/consola.py $S"
limpia() { grep -v '^\[ *[0-9]' || true; }   # quita los mensajes del núcleo que salen por la consola

entrar() {  # entrar <clave> [clave nueva]
  timeout 1500 python3 "$AQUI/consola.py" "$S" entrar almiadmin "$@"
  $C escribir "sudo -v"; $C escribir "${2:-$1}"
}
esperar_servicio() {  # esperar_servicio <unidad>
  for _ in $(seq 1 60); do
    e=$($C orden 90 "systemctl is-active $1" 2>/dev/null | grep -E '^(active|failed)$' | tail -1 || true)
    [ -n "$e" ] && { echo "$1: $e"; return; }
    sleep 30
  done
  echo "$1: no termina"; exit 1
}
apagar() {
  $C escribir "sudo poweroff"
  p=$(cat "$D/qemu.pid"); for _ in $(seq 1 120); do kill -0 "$p" 2>/dev/null || return 0; sleep 5; done
}

# --- 1. Primer arranque ---
"$VM" arrancar bd 2048 2 serie "$RAW/ALMI-BD.raw" "$RAW/ALMI-BD-raid1.raw" "$RAW/ALMI-BD-raid2.raw"
entrar "$CLAVE_INICIAL" "$CLAVE_NUEVA"
esperar_servicio almi-primer-arranque-bd
$C transcribir "$CAP/18-vm-primer-arranque-raid.txt" 200 \
  "sudo tail -4 /var/log/almi-crear-raid.log" "cat /proc/mdstat" "findmnt /var/lib/mysql" \
  "systemctl show mariadb -p RequiresMountsFor; systemctl is-active mariadb" \
  "sudo mount --bind / /mnt && sudo ls -A /mnt/var/lib/mysql | wc -l; sudo umount /mnt" \
  "grep -E '^(ARRAY|PROGRAM)' /etc/mdadm/mdadm.conf; grep INITRDSTART /etc/default/mdadm" \
  "systemctl is-enabled almi-raid-degradado; systemctl is-active mdmonitor" | limpia
$C transcribir "$CAP/19-vm-usuarios-secretos-cortafuegos.txt" 200 \
  "sudo tail -3 /var/log/almi-primer-arranque-bd.log" \
  "sudo mariadb -e \"SHOW GRANTS FOR 'copias'@'localhost'\"" \
  "sudo stat -c '%a %U %n' /root/credenciales-primer-arranque.txt /root/.my.cnf /home/almiadmin/.consulta.cnf" \
  "mariadb --defaults-file=\$HOME/.consulta.cnf -e 'SELECT CURRENT_USER(), COUNT(*) AS facturas FROM almichain.factura'" \
  "mariadb --defaults-file=\$HOME/.consulta.cnf -e 'DELETE FROM almichain.factura'" \
  "sudo ufw status" "ls /etc/ssh/ssh_host_*_key.pub; systemctl is-active ssh" \
  "sudo chage -l almiadmin | head -1" | limpia
# El hash de la contraseña (de esta prueba) no se deja en la transcripción
sed -i "s/IDENTIFIED BY PASSWORD '\*[0-9A-F]\{40\}'/IDENTIFIED BY PASSWORD '*…(hash recortado)…'/" "$CAP/19-vm-usuarios-secretos-cortafuegos.txt"

# --- 2. Prueba A: fallo de un disco en marcha, aviso y reconstrucción ---
$C transcribir "$CAP/20-vm-raid-fallo-y-aviso.txt" 300 \
  "sudo mdadm /dev/md0 --fail /dev/sdc 2>&1" "cat /proc/mdstat | sed -n 2,3p" \
  "sudo mariadb -e \"INSERT INTO almichain.cliente (nombre, apellidos, telefono) VALUES ('Prueba', 'RAID', '699999999'); SELECT COUNT(*) AS clientes FROM almichain.cliente\"" \
  "sleep 70; sudo tail -3 /var/log/aviso-raid.log" | limpia
$C transcribir "$CAP/21-vm-raid-reconstruccion.txt" 900 \
  "sudo mdadm /dev/md0 --remove /dev/sdc && sudo mdadm /dev/md0 --add /dev/sdc" \
  "sleep 5; cat /proc/mdstat | sed -n 2,4p" "sudo mdadm --wait /dev/md0; cat /proc/mdstat | sed -n 2,3p" \
  "sudo mdadm --detail /dev/md0 | grep -E 'State :|Failed Devices|Active Devices'" \
  "sudo mariadb -e \"SELECT nombre, apellidos FROM almichain.cliente WHERE apellidos='RAID'\"" | limpia

# --- 3. Prueba B: arrancar sin un disco ---
# La imagen no tiene consola serie (en VirtualBox no hace falta): para seguir manejándola por la
# consola serie al arrancar con GRUB se añade SOLO en la capa de pruebas
$C orden 60 "sudo sed -i 's#^\(  linux .* ro\) *\$#\1 console=tty0 console=ttyS0,115200#' /boot/grub/grub.cfg" >/dev/null
apagar
"$VM" arrancar bd 2048 2 grub "$D/ALMI-BD.qcow2" "$D/ALMI-BD-raid1.qcow2"
entrar "$CLAVE_NUEVA"; sleep 60
$C transcribir "$CAP/22-vm-raid-sin-un-disco.txt" 200 \
  "lsblk -d -o NAME,SIZE" "cat /proc/mdstat | sed -n 2,3p" "findmnt -n /var/lib/mysql; systemctl is-active mariadb" \
  "sudo mariadb -e \"SELECT COUNT(*) AS clientes FROM almichain.cliente; INSERT INTO almichain.cliente (nombre, apellidos, telefono) VALUES ('Prueba', 'Un disco', '677777777')\"" \
  "sudo tail -4 /var/log/aviso-raid.log" | limpia
apagar
# Disco nuevo y vacío en el lugar del que se quitó
rm -f "$D/disco-nuevo.raw"; truncate -s 10G "$D/disco-nuevo.raw"
"$VM" arrancar bd 2048 2 grub "$D/ALMI-BD.qcow2" "$D/ALMI-BD-raid1.qcow2" "$D/disco-nuevo.raw"
entrar "$CLAVE_NUEVA"; sleep 60
$C transcribir "$CAP/23-vm-raid-disco-nuevo.txt" 900 \
  "lsblk -d -o NAME,SIZE" "cat /proc/mdstat | sed -n 2,3p" \
  "sudo mdadm /dev/md0 --add /dev/sdc" "sudo mdadm --wait /dev/md0; cat /proc/mdstat | sed -n 2,3p" \
  "sudo mariadb -e \"SELECT nombre, apellidos FROM almichain.cliente WHERE nombre='Prueba'\"" | limpia
echo "Pruebas de ALMI-BD terminadas: $CAP"
