#!/bin/bash
# Almi-Chain · Primer arranque de ALMI-ODOO importada desde la OVA
# Carga las imágenes de Docker, restaura la base de datos "almichain" y los adjuntos,
# arranca Odoo y aplica el cortafuegos. Se ejecuta una sola vez (servicio almi-primer-arranque).
set -euo pipefail
DIR=/opt/odoo/primer-arranque
LOG=/var/log/almi-primer-arranque.log
exec > >(tee -a "$LOG") 2>&1
DC="docker compose --project-directory /opt/odoo"
echo "== $(date '+%F %T') Primer arranque de ALMI-ODOO =="

# 1. Imágenes de Odoo 18 y PostgreSQL 16 (vienen dentro de la VM: no hace falta Internet)
docker load -i "$DIR/odoo-imagenes.tar"

# 2. Base de datos
$DC up -d db
for i in $(seq 1 60); do $DC exec -T db pg_isready -U odoo >/dev/null 2>&1 && break; sleep 2; done
if ! $DC exec -T db psql -U odoo -lqt | cut -d'|' -f1 | grep -qw almichain; then
  $DC exec -T db createdb -U odoo almichain
  $DC exec -T db pg_restore -U odoo -d almichain < "$DIR/almichain.dump"
fi

# 3. Adjuntos (logotipo, imágenes de productos, PDF de facturas)
$DC run --rm --no-deps --entrypoint "" -v "$DIR:/restaurar:ro" odoo \
  bash -c "mkdir -p /var/lib/odoo/filestore && tar xzf /restaurar/filestore.tar.gz -C /var/lib/odoo && chown -R odoo:odoo /var/lib/odoo"

# 4. Odoo en marcha
$DC up -d
$DC ps

# 5. Cortafuegos: SSH, HTTP y HTTPS solo desde las redes internas (guía 6.2)
ufw --force reset >/dev/null
ufw default deny incoming
ufw default allow outgoing
for p in 22 80 443; do ufw allow from 192.168.0.0/16 to any port $p proto tcp; done
ufw --force enable

# 6. Limpiar: los archivos grandes ya no hacen falta
rm -f "$DIR/odoo-imagenes.tar" "$DIR/PENDIENTE"
echo "== $(date '+%F %T') Listo: https://192.168.10.30 =="
