#!/bin/bash
# Almi-Chain · Parte una .ova en trozos de 380 MB (para enviarla por sitios con límite de tamaño)
# y guarda su huella SHA-256 con el nombre del archivo, sin ruta.
#   ./partir-ova.sh ruta/ALMI-ODOO.ova [carpeta de salida]
# Para unirla: docs/unir-ova-linux.sh o docs/unir-ova-windows.bat
set -euo pipefail
OVA=${1:?Uso: partir-ova.sh ruta/NOMBRE.ova [carpeta]}
O=${2:-$(dirname "$OVA")/entrega}
N=$(basename "$OVA")
mkdir -p "$O"
rm -f "$O/$N".parte*
if [ "$(stat -c %s "$OVA")" -gt $((380 * 1024 * 1024)) ]; then
  split -b 380M -d -a 1 --numeric-suffixes=1 "$OVA" "$O/$N.parte"
else
  cp "$OVA" "$O/$N"
fi
(cd "$(dirname "$OVA")" && sha256sum "$N") > "$O/$N.sha256"
ls -lh "$O/$N"*
