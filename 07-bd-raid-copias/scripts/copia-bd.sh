#!/bin/bash
# Almi-Chain · Copia diaria de la base de datos almichain (ALMI-BD)
# Se instala en /usr/local/bin/copia-bd.sh y la lanza cron a las 02:00
set -euo pipefail

DEST=/var/backups/mariadb
FECHA=$(date +%F_%H%M)
ARCHIVO="$DEST/almichain-$FECHA.sql.gz"
REMOTO=copias@192.168.10.30:/srv/copias-remotas/bd/

mkdir -p "$DEST"
chmod 700 "$DEST"

# Volcado completo y coherente sin parar el servicio (usuario "copias", contraseña en /root/.my.cnf)
mariadb-dump --defaults-file=/root/.my.cnf --single-transaction \
  --routines --triggers --events --databases almichain | gzip > "$ARCHIVO"

# Comprobar que el comprimido está bien y guardar su huella
gzip -t "$ARCHIVO"
sha256sum "$ARCHIVO" > "$ARCHIVO.sha256"

# Los domingos se guarda también como copia semanal
if [ "$(date +%u)" = "7" ]; then
  cp "$ARCHIVO" "$DEST/semanal-almichain-$FECHA.sql.gz"
fi

# Retención: 7 días las diarias y 28 las semanales
find "$DEST" -name 'almichain-*' -mtime +7 -delete
find "$DEST" -name 'semanal-*' -mtime +28 -delete

# Copia fuera de este servidor (regla 3-2-1): a ALMI-ODOO
rsync -a -e "ssh -i /root/.ssh/copias_ed25519" "$DEST/" "$REMOTO"

echo "$(date '+%F %T') copia OK: $ARCHIVO" >> /var/log/copia-bd.log
