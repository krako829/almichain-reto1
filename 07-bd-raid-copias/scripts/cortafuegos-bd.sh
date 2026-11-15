#!/bin/bash
# Almi-Chain · Cortafuegos de ALMI-BD: este servidor no tiene web; solo SSH desde gestión (VLAN 10)
# y administración (VLAN 99). MariaDB solo escucha en 127.0.0.1.
set -euo pipefail
ufw --force reset >/dev/null
ufw default deny incoming
ufw default allow outgoing
for red in 192.168.10.0/24 192.168.99.0/24; do ufw allow from "$red" to any port 22 proto tcp; done
ufw --force enable
mkdir -p /etc/almichain && date '+%F %T' > /etc/almichain/cortafuegos-hecho
