#!/bin/bash
# Almi-Chain · ALMI-BD: Ubuntu Server 24.04 + MariaDB + RAID 1 (dos discos de 10 GB) + copias automáticas
#
#   sudo CREDENCIALES=... CLAVES=... ./construir-bd.sh
#
# Deja tres discos: ALMI-BD.raw (sistema, 15 GB) y ALMI-BD-raid1.raw / ALMI-BD-raid2.raw (vacíos, 10 GB).
# En el primer arranque: almi-crear-raid crea el RAID 1 y mueve encima los datos de MariaDB, y
# almi-primer-arranque-bd crea los 3 usuarios con contraseñas nuevas y pone el cortafuegos.
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"
B=$REPO/07-bd-raid-copias

crear_disco "$SALIDA/ALMI-BD.raw" 15
base_ubuntu almi-bd 192.168.10.20/24
apt_chroot mariadb-server mariadb-client mdadm

# --- MariaDB segura con el esquema y los datos (README 07, apartados 2 y 4) ---
mkdir -p "$R/run/mysqld"; en_chroot "chown mysql:mysql /run/mysqld"
en_chroot "(/usr/sbin/mariadbd --user=mysql --skip-networking --socket=/run/mysqld/mysqld.sock > /tmp/mariadbd.log 2>&1 &) ; for i in \$(seq 1 30); do mariadb -e 'select 1' >/dev/null 2>&1 && break; sleep 1; done"
mkdir -p "$R/home/almiadmin/sql" "$R/home/almiadmin/scripts"
cp "$B"/sql/*.sql "$R/home/almiadmin/sql/"
install -m 755 "$B/scripts/crear-usuarios-bd.sh" "$R/home/almiadmin/scripts/crear-usuarios-bd.sh"
en_chroot "chown -R almiadmin:almiadmin /home/almiadmin/sql /home/almiadmin/scripts"
# Lo mismo que mariadb-secure-installation: sin anónimos, sin root remoto, sin base test
en_chroot "mariadb -e \"DELETE FROM mysql.global_priv WHERE User=''; DELETE FROM mysql.global_priv WHERE User='root' AND Host NOT IN ('localhost','127.0.0.1','::1'); DROP DATABASE IF EXISTS test; DELETE FROM mysql.db WHERE Db='test' OR Db='test\\\\_%'; FLUSH PRIVILEGES;\""
en_chroot "cd /home/almiadmin/sql && mariadb < 01-esquema.sql && mariadb < 02-datos.sql"
en_chroot "mariadb -e 'SELECT COUNT(*) AS facturas FROM almichain.factura;'"
en_chroot "mariadb-admin shutdown"
sleep 3

# --- Copias (README 07, apartados 6 y 7). /root/.my.cnf lo crea el primer arranque ---
install -m 700 "$B/scripts/copia-bd.sh" "$R/usr/local/bin/copia-bd.sh"
copias_receptor odoo 192.168.10.30     # recibe las copias de Odoo
clave_envio bd                         # envía sus copias a ALMI-ODOO
cron_root "0 2 * * * /usr/local/bin/copia-bd.sh" "$LIMPIAR_RECIBIDAS"

# --- RAID 1 en el primer arranque (los discos se entregan vacíos) ---
install -m 700 "$B/scripts/crear-raid.sh" "$R/usr/local/sbin/almi-crear-raid.sh"
cat > "$R/etc/systemd/system/almi-crear-raid.service" <<'EOF'
[Unit]
Description=Almi-Chain: crear el RAID 1 de la base de datos (solo la primera vez)
After=local-fs.target systemd-udev-settle.service
Before=mariadb.service
ConditionPathExists=!/etc/almichain/raid-creado

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/almi-crear-raid.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# --- Usuarios de MariaDB con contraseñas nuevas y cortafuegos, después del RAID ---
install -m 700 "$B/scripts/primer-arranque-bd.sh" "$R/usr/local/sbin/almi-primer-arranque-bd.sh"
cat > "$R/etc/systemd/system/almi-primer-arranque-bd.service" <<'EOF'
[Unit]
Description=Almi-Chain: usuarios de MariaDB con contraseñas nuevas y cortafuegos (solo la primera vez)
After=almi-crear-raid.service mariadb.service
Wants=mariadb.service
ConditionPathExists=!/etc/almichain/primer-arranque-hecho

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/almi-primer-arranque-bd.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
cortafuegos_al_arrancar "$B/scripts/cortafuegos-bd.sh"
en_chroot "systemctl enable almi-crear-raid.service almi-primer-arranque-bd.service mariadb >/dev/null 2>&1"

instalar_grub ""
limpiar
desmontar_todo
# Los dos discos del RAID: vacíos
rm -f "$SALIDA/ALMI-BD-raid1.raw" "$SALIDA/ALMI-BD-raid2.raw"
truncate -s 10G "$SALIDA/ALMI-BD-raid1.raw"; truncate -s 10G "$SALIDA/ALMI-BD-raid2.raw"
echo "ALMI-BD listo: $SALIDA/ALMI-BD.raw + 2 discos de 10 GB"
