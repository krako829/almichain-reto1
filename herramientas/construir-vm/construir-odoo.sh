#!/bin/bash
# Almi-Chain · ALMI-ODOO: Ubuntu Server 24.04 + Docker (Odoo 18 + PostgreSQL 16) + nginx HTTPS + copias
#
#   sudo CREDENCIALES=... CLAVES=... ./construir-odoo.sh <carpeta-de-datos>
#
# <carpeta-de-datos> la crea sacar-datos-odoo.sh a partir de un Odoo ya configurado con
# 05-erp-odoo/scripts/configurar_odoo.py: almichain.dump, filestore.tar.gz y odoo-imagenes.tar.
# La VM se entrega SIN secretos de Odoo: la contraseña de PostgreSQL, la maestra y el
# certificado HTTPS se generan en su primer arranque (05-erp-odoo/scripts/primer-arranque-odoo.sh).
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"
DATOS=${1:?Uso: construir-odoo.sh <carpeta con almichain.dump, filestore.tar.gz y odoo-imagenes.tar>}
for f in almichain.dump filestore.tar.gz odoo-imagenes.tar; do [ -s "$DATOS/$f" ] || { echo "Falta $DATOS/$f"; exit 1; }; done
B=$REPO/05-erp-odoo

crear_disco "$SALIDA/ALMI-ODOO.raw" 25
base_ubuntu almi-odoo 192.168.10.30/24
apt_chroot docker.io docker-compose-v2 nginx

# --- Odoo con Docker (README 05, apartado 2). Sin .env: lo crea el primer arranque ---
mkdir -p "$R/opt/odoo/config" "$R/opt/odoo/primer-arranque"
install -m 644 "$B/config/docker-compose.yml" "$R/opt/odoo/docker-compose.yml"
install -m 644 "$B/config/odoo.conf" "$R/opt/odoo/config/odoo.conf"
chmod 700 "$R/opt/odoo"; chmod 755 "$R/opt/odoo/config"
cp "$DATOS/almichain.dump" "$DATOS/filestore.tar.gz" "$DATOS/odoo-imagenes.tar" "$R/opt/odoo/primer-arranque/"
chmod 700 "$R/opt/odoo/primer-arranque"

# --- HTTPS con nginx (README 05, apartado 3). El certificado lo crea el primer arranque ---
install -m 644 "$B/config/nginx-odoo.conf" "$R/etc/nginx/sites-available/odoo"
ln -sf /etc/nginx/sites-available/odoo "$R/etc/nginx/sites-enabled/odoo"
rm -f "$R/etc/nginx/sites-enabled/default"

# --- Copias (README 05, apartado 7, y README 07) ---
install -m 700 "$B/scripts/copia-odoo.sh" "$R/usr/local/bin/copia-odoo.sh"
copias_receptor bd 192.168.10.20       # recibe las copias de la base de datos
clave_envio odoo                       # envía sus copias a ALMI-BD
cron_root "30 2 * * * /usr/local/bin/copia-odoo.sh" "$LIMPIAR_RECIBIDAS"

# --- Primer arranque: secretos nuevos, imágenes, base de datos, adjuntos y cortafuegos ---
install -m 700 "$B/scripts/primer-arranque-odoo.sh" "$R/usr/local/sbin/almi-primer-arranque.sh"
cat > "$R/etc/systemd/system/almi-primer-arranque.service" <<'EOF'
[Unit]
Description=Almi-Chain: poner en marcha Odoo con los datos del reto (solo la primera vez)
After=docker.service network-online.target
Requires=docker.service
ConditionPathExists=/opt/odoo/primer-arranque/PENDIENTE

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/almi-primer-arranque.sh
RemainAfterExit=yes
TimeoutStartSec=3600

[Install]
WantedBy=multi-user.target
EOF
touch "$R/opt/odoo/primer-arranque/PENDIENTE"
cortafuegos_al_arrancar "$B/scripts/cortafuegos-odoo.sh"
en_chroot "systemctl enable docker nginx almi-primer-arranque.service >/dev/null 2>&1"

instalar_grub ""
limpiar
desmontar_todo
echo "ALMI-ODOO listo: $SALIDA/ALMI-ODOO.raw"
