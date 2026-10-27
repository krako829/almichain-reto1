#!/bin/bash
# Almi-Chain · Copia de la base de datos y los adjuntos de Odoo (ALMI-ODOO)
# Se instala en /usr/local/bin/copia-odoo.sh y la lanza cron a las 02:30
set -euo pipefail

DEST=/var/backups/odoo
FECHA=$(date +%F_%H%M)
DC="docker compose --project-directory /opt/odoo"
# En ALMI-BD la clave solo puede ESCRIBIR en su carpeta de copias (rrsync -wo -no-del):
# no puede leer, borrar, salir de la carpeta ni ejecutar órdenes. Por eso el destino es "copias@IP:".
REMOTO=copias@192.168.10.20:

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
# accept-new: la primera vez se guarda la clave de host del otro servidor (se genera en su primer arranque);
# si luego cambia, ssh se niega a conectar.
rsync -a -e "ssh -i /root/.ssh/copias_ed25519 -o BatchMode=yes -o StrictHostKeyChecking=accept-new" "$DEST/" "$REMOTO"

echo "$(date '+%F %T') copia OK" >> /var/log/copia-odoo.log
