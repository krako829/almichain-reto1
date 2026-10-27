#!/bin/bash
# Almi-Chain · Cortafuegos de ALMI-ODOO con las redes del diseño (bloque 04)
#   SSH desde gestión (VLAN 10) y administración (VLAN 99); HTTP y HTTPS desde gestión y TPV (VLAN 20).
#   En el laboratorio todas las VM están en 192.168.10.0/24.
# En la VM exportada lo ejecuta el servicio almi-cortafuegos en el PRIMER arranque, antes de que
# haya red, así el servidor nunca está en la red sin cortafuegos.
set -euo pipefail
ufw --force reset >/dev/null
ufw default deny incoming
ufw default allow outgoing
for red in 192.168.10.0/24 192.168.99.0/24; do ufw allow from "$red" to any port 22 proto tcp; done
for red in 192.168.10.0/24 192.168.20.0/24; do ufw allow from "$red" to any port 80,443 proto tcp; done
ufw --force enable
mkdir -p /etc/almichain && date '+%F %T' > /etc/almichain/cortafuegos-hecho
