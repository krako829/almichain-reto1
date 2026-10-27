#!/bin/bash
# Almi-Chain · Saca de un Odoo ya configurado lo que necesita construir-odoo.sh
#
#   sudo ./sacar-datos-odoo.sh <carpeta-de-salida> [carpeta del docker-compose, por defecto /opt/odoo]
#
# Deja en la carpeta: almichain.dump (pg_dump), filestore.tar.gz (adjuntos) y
# odoo-imagenes.tar (docker save de odoo:18.0 y postgres:16), para que la VM no necesite Internet.
set -euo pipefail
OUT=${1:?Uso: sacar-datos-odoo.sh <carpeta-de-salida> [/opt/odoo]}
DC="docker compose --project-directory ${2:-/opt/odoo}"
mkdir -p "$OUT"
$DC exec -T db pg_dump -U odoo -Fc almichain > "$OUT/almichain.dump"
$DC exec -T odoo tar czf - -C /var/lib/odoo filestore/almichain > "$OUT/filestore.tar.gz"
docker save -o "$OUT/odoo-imagenes.tar" postgres:16 odoo:18.0
ls -lh "$OUT"
