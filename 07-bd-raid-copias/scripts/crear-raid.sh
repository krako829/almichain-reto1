#!/bin/bash
# Almi-Chain · Crea el RAID 1 de ALMI-BD y pone los datos de MariaDB encima (guía 8.5)
#
# Hace lo mismo que los pasos a mano de la guía:
#   mdadm --create  ->  mkfs.ext4  ->  copiar /var/lib/mysql  ->  fstab  ->  mdadm.conf  ->  initramfs
# En la VM exportada se ejecuta solo una vez, en el primer arranque (servicio almi-crear-raid).
# Si el RAID ya existe, no hace nada.
set -euo pipefail
LOG=/var/log/almi-crear-raid.log
exec > >(tee -a "$LOG") 2>&1
MARCA=/etc/almichain/raid-creado
DISCO1=${1:-/dev/sdb}
DISCO2=${2:-/dev/sdc}

echo "== $(date '+%F %T') Creación del RAID 1 =="
if [ -e "$MARCA" ] || grep -q '^md0' /proc/mdstat 2>/dev/null; then
  echo "El RAID ya existe. Nada que hacer."; exit 0
fi
for d in "$DISCO1" "$DISCO2"; do
  [ -b "$d" ] || { echo "ERROR: no existe el disco $d (¿has añadido los dos discos de 10 GB?)"; exit 1; }
  if blkid "$d" >/dev/null 2>&1 || [ -n "$(lsblk -no NAME "$d" | sed 1d)" ]; then
    echo "ERROR: $d no está vacío. No se toca para no borrar datos."; exit 1
  fi
done

# 1. RAID 1 con los dos discos (espejo)
mdadm --create /dev/md0 --level=1 --raid-devices=2 --metadata=1.2 --run "$DISCO1" "$DISCO2"

# 2. Sistema de archivos
mkfs.ext4 -q -L datos-bd /dev/md0

# 3. Copiar los datos de MariaDB al RAID (con el servicio parado)
systemctl stop mariadb 2>/dev/null || true
mkdir -p /mnt/raid
mount /dev/md0 /mnt/raid
rsync -aAX /var/lib/mysql/ /mnt/raid/
rm -rf /mnt/raid/lost+found
umount /mnt/raid

# 4. Montaje permanente por UUID (nofail: si falla el RAID, el sistema arranca igual)
UUID=$(blkid -s UUID -o value /dev/md0)
sed -i '\#/var/lib/mysql#d' /etc/fstab
echo "UUID=$UUID /var/lib/mysql ext4 defaults,nofail 0 2" >> /etc/fstab
systemctl daemon-reload
mount /var/lib/mysql
chown mysql:mysql /var/lib/mysql

# 5. Que el RAID se llame siempre md0 y arranque con el sistema
sed -i '/^ARRAY /d' /etc/mdadm/mdadm.conf
mdadm --detail --scan >> /etc/mdadm/mdadm.conf
update-initramfs -u

systemctl start mariadb 2>/dev/null || true
mkdir -p /etc/almichain && date '+%F %T' > "$MARCA"
cat /proc/mdstat
df -h /var/lib/mysql
echo "== RAID 1 creado. La sincronización inicial sigue en segundo plano (cat /proc/mdstat) =="
