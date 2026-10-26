#!/bin/bash
# Almi-Chain · Copia de la base de datos y los adjuntos de Odoo (ALMI-ODOO)
# Se instala en /usr/local/bin/copia-odoo.sh y la lanza cron a las 02:30
set -euo pipefail

DEST=/var/backups/odoo
FECHA=$(date +%F_%H%M)
DC="docker compose --project-directory /opt/odoo"
REMOTO=copias@192.168.10.20:/srv/copias-remotas/odoo/

mkdir -p "$DEST"
chmod 700 "$DEST"

# Base de datos (formato propio de PostgreSQL, comprimido)
$DC exec -T db pg_dump -U odoo -Fc almichain > "$DEST/almichain-$FECHA.dump"

# Adjuntos (PDF de facturas, imágenes de productos...)
$DC exec -T odoo tar czf - -C /var/lib/odoo filestore/almichain > "$DEST/filestore-$FECHA.tar.gz"

# Huellas para comprobar las copias
sha256sum "$DEST/almichain-$FECHA.dump" "$DEST/filestore-$FECHA.tar.gz" > "$DEST/huellas-$FECHA.sha256"

# Borrar copias de más de 7 días
find "$DEST" -type f -mtime +7 -delete

# Copia fuera de esta máquina: a ALMI-BD
rsync -a -e "ssh -i /root/.ssh/copias_ed25519" "$DEST/" "$REMOTO"

echo "$(date '+%F %T') copia OK" >> /var/log/copia-odoo.log
