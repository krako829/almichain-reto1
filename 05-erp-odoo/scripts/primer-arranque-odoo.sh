#!/bin/bash
# Almi-Chain · Primer arranque de ALMI-ODOO importada desde la OVA
# Genera los secretos propios de ESTA máquina, carga las imágenes de Docker, restaura la base
# de datos "almichain" y los adjuntos, cambia las contraseñas de los usuarios de Odoo y arranca Odoo.
# (El cortafuegos lo pone antes el servicio almi-cortafuegos: scripts/cortafuegos-odoo.sh.)
# Se ejecuta una sola vez (servicio almi-primer-arranque).
set -euo pipefail
DIR=/opt/odoo/primer-arranque
LOG=/var/log/almi-primer-arranque.log
CRED=/root/credenciales-primer-arranque.txt
umask 077
exec > >(tee -a "$LOG") 2>&1
DC="docker compose --project-directory /opt/odoo"
echo "== $(date '+%F %T') Primer arranque de ALMI-ODOO =="

# 1. Secretos nuevos, distintos en cada copia de la OVA (la OVA no lleva ninguno de estos)
#    - Contraseña de PostgreSQL: se usa al crear la base vacía en el paso 3
#    - Contraseña maestra de Odoo
#    - Certificado HTTPS de servidor (CA:FALSE) con su clave privada
DB_PASS=$(openssl rand -base64 24)
MAESTRA=$(openssl rand -base64 24)
printf 'DB_PASSWORD=%s\n' "$DB_PASS" > /opt/odoo/.env
chmod 600 /opt/odoo/.env
sed -i "s|^admin_passwd = .*|admin_passwd = $MAESTRA|" /opt/odoo/config/odoo.conf

mkdir -p /etc/ssl/almichain
chmod 755 /etc/ssl/almichain   # nginx (www-data) sirve la parte pública; la clave es 600
openssl req -x509 -nodes -newkey rsa:2048 -days 825 \
  -keyout /etc/ssl/almichain/odoo.key -out /etc/ssl/almichain/odoo.crt \
  -subj "/C=ES/ST=Bizkaia/L=Bilbao/O=Almi-Chain/CN=192.168.10.30" \
  -addext "basicConstraints=critical,CA:FALSE" \
  -addext "keyUsage=critical,digitalSignature,keyEncipherment" \
  -addext "extendedKeyUsage=serverAuth" \
  -addext "subjectAltName=IP:192.168.10.30,DNS:almi-odoo,DNS:localhost,IP:127.0.0.1" 2>/dev/null
chmod 600 /etc/ssl/almichain/odoo.key
chmod 644 /etc/ssl/almichain/odoo.crt
HUELLA=$(openssl x509 -in /etc/ssl/almichain/odoo.crt -noout -fingerprint -sha256 | cut -d= -f2)

# La huella se ve en la consola, antes de iniciar sesión, para comprobarla en los Windows
mkdir -p /etc/issue.d && chmod 755 /etc/issue.d
printf 'Certificado HTTPS de Odoo (SHA-256):\n%s\n\n' "$HUELLA" > /etc/issue.d/almichain-odoo.issue
chmod 644 /etc/issue.d/almichain-odoo.issue

cat > "$CRED" <<EOF
Almi-Chain · ALMI-ODOO · secretos generados en el primer arranque ($(date '+%F %T'))
Pásalos a KeePassXC y BORRA este archivo:  sudo shred -u $CRED

Contraseña maestra de Odoo (gestor de bases de datos): $MAESTRA
Huella SHA-256 del certificado HTTPS:                    $HUELLA
(La contraseña de PostgreSQL está en /opt/odoo/.env y no hace falta saberla.)
EOF
chmod 600 "$CRED"

# 2. Imágenes de Odoo 18 y PostgreSQL 16 (vienen dentro de la VM: no hace falta Internet)
docker load -i "$DIR/odoo-imagenes.tar"

# 3. Base de datos
$DC up -d db
for _ in $(seq 1 60); do $DC exec -T db pg_isready -U odoo >/dev/null 2>&1 && break; sleep 2; done
if ! $DC exec -T db psql -U odoo -lqt | cut -d'|' -f1 | grep -qw almichain; then
  $DC exec -T db createdb -U odoo almichain
  $DC exec -T db pg_restore -U odoo -d almichain < "$DIR/almichain.dump"
fi
# El volcado trae el secreto con el que Odoo firma las sesiones y los enlaces (database.secret)
# y el identificador de la base: se cambian, para que no sean iguales en todas las copias
$DC exec -T db psql -U odoo -d almichain -q -c \
  "UPDATE ir_config_parameter SET value = gen_random_uuid()::text WHERE key IN ('database.secret', 'database.uuid')"

# 4. Adjuntos (logotipo, imágenes de productos, PDF de facturas)
$DC run --rm --no-deps --entrypoint "" -v "$DIR:/restaurar:ro" odoo \
  bash -c "mkdir -p /var/lib/odoo/filestore && tar xzf /restaurar/filestore.tar.gz -C /var/lib/odoo && chown -R odoo:odoo /var/lib/odoo"

# 4b. Contraseñas nuevas para los usuarios de Odoo (administrador, gerente y camareros): el volcado
#     trae las de la base de ejemplo. Se generan aquí y se guardan en $CRED
#     (odoo shell con los datos de conexión del contenedor; sirve con la imagen oficial y con la de la VM)
# shellcheck disable=SC2016  # $PASSWORD y $B se expanden dentro del contenedor
$DC run --rm --no-deps -T --entrypoint /bin/sh odoo -c '
  B=$(command -v odoo || echo /opt/odoo/odoo-bin)
  set -- shell -c /etc/odoo/odoo.conf --db_host db --db_user odoo --db_password "$PASSWORD" -d almichain --no-http --log-level=warn
  if command -v gosu >/dev/null; then exec gosu odoo python3 "$B" "$@"; else exec "$B" "$@"; fi' <<'PY' | grep -v '^Warn' >> "$CRED"
import secrets
print("\nUsuarios de Odoo (https://192.168.10.30) con contraseña nueva:")
for u in env["res.users"].search([("share", "=", False), ("id", "!=", 1)]):
    clave = secrets.token_urlsafe(12)
    u.password = clave
    print(f"  {u.login}: {clave}")
env.cr.commit()
PY
chmod 600 "$CRED"

# 5. Odoo y nginx en marcha (nginx no podía arrancar antes: no había certificado)
$DC up -d
$DC ps
systemctl restart nginx

# 6. El cortafuegos ya está puesto: lo pone el servicio almi-cortafuegos antes de que haya red
#    (scripts/cortafuegos-odoo.sh)
ufw status | head -1

# 7. Limpiar: los archivos grandes ya no hacen falta
rm -f "$DIR/odoo-imagenes.tar" "$DIR/PENDIENTE"
echo "== $(date '+%F %T') Listo: https://192.168.10.30 · huella del certificado: $HUELLA =="
echo "   Secretos nuevos en $CRED (solo root)"
