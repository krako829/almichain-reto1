#!/bin/bash
# Almi-Chain · Crea el RAID 1 de ALMI-BD y pone los datos de MariaDB encima (guía 8.5)
#
# Hace lo mismo que los pasos a mano de la guía:
#   mdadm --create  ->  mkfs.ext4  ->  copiar /var/lib/mysql  ->  vaciar el original  ->  fstab
#   ->  MariaDB depende del montaje  ->  mdadm.conf  ->  initramfs
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
# Comprobar que la copia es idéntica antes de borrar nada (si no, set -e para el script aquí)
diff -r --brief /var/lib/mysql/ /mnt/raid/
umount /mnt/raid

# 4. Vaciar la carpeta original: los datos ya están en el RAID. Si se dejaran, quedarían
#    ocultos debajo del montaje y, si un día el RAID no se montara, MariaDB arrancaría
#    sin avisar con esa copia vieja.
find /var/lib/mysql -mindepth 1 -delete

# 5. Montaje permanente por UUID. nofail: si falla el RAID, el sistema arranca igual y se
#    puede reparar por SSH; pero MariaDB NO arranca sin el RAID (RequiresMountsFor)
UUID=$(blkid -s UUID -o value /dev/md0)
sed -i '\#/var/lib/mysql#d' /etc/fstab
echo "UUID=$UUID /var/lib/mysql ext4 defaults,nofail 0 2" >> /etc/fstab
mkdir -p /etc/systemd/system/mariadb.service.d
printf '[Unit]\nRequiresMountsFor=/var/lib/mysql\n' > /etc/systemd/system/mariadb.service.d/raid.conf
systemctl daemon-reload
mount /var/lib/mysql
chown mysql:mysql /var/lib/mysql

# 6. Que el RAID se llame siempre md0 y arranque con el sistema
sed -i '/^ARRAY /d' /etc/mdadm/mdadm.conf
mdadm --detail --scan >> /etc/mdadm/mdadm.conf
update-initramfs -u

# --no-block: este script corre como servicio ordenado ANTES de mariadb; un start normal
# esperaría a que este mismo servicio termine y se quedaría bloqueado para siempre
systemctl start --no-block mariadb 2>/dev/null || true
mkdir -p /etc/almichain && date '+%F %T' > "$MARCA"
cat /proc/mdstat
df -h /var/lib/mysql
echo "== RAID 1 creado. La sincronización inicial sigue en segundo plano (cat /proc/mdstat) =="
