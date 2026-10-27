#!/bin/bash
# Almi-Chain · Primer arranque de ALMI-BD importada desde la OVA
# Se ejecuta una sola vez (servicio almi-primer-arranque-bd), DESPUÉS de crear el RAID
# (almi-crear-raid) y con MariaDB ya en marcha:
#   1. Contraseñas nuevas para app_almichain, consulta y copias (distintas en cada copia de la OVA)
#   2. Cortafuegos: solo SSH desde las VLAN 10 y 99
set -euo pipefail
LOG=/var/log/almi-primer-arranque-bd.log
CRED=/root/credenciales-primer-arranque.txt
MARCA=/etc/almichain/primer-arranque-hecho
SQL=/home/almiadmin/sql/03-usuarios.sql
umask 077
exec > >(tee -a "$LOG") 2>&1
echo "== $(date '+%F %T') Primer arranque de ALMI-BD =="

for _ in $(seq 1 60); do mariadb -e 'SELECT 1' >/dev/null 2>&1 && break; sleep 2; done

# 1. Contraseñas nuevas (128 bits en hexadecimal: no hace falta escaparlas)
nueva() { openssl rand -hex 16; }
P_APP=$(nueva); P_CONSULTA=$(nueva); P_COPIAS=$(nueva)
{
  printf "SET @p_app = '%s';\nSET @p_consulta = '%s';\nSET @p_copias = '%s';\n" "$P_APP" "$P_CONSULTA" "$P_COPIAS"
  cat "$SQL"
} | mariadb
printf '[mariadb-dump]\nuser=copias\npassword=%s\n' "$P_COPIAS" > /root/.my.cnf
chmod 600 /root/.my.cnf
printf '[client]\nuser=consulta\npassword=%s\n' "$P_CONSULTA" > /home/almiadmin/.consulta.cnf
chown almiadmin:almiadmin /home/almiadmin/.consulta.cnf
chmod 600 /home/almiadmin/.consulta.cnf

cat > "$CRED" <<EOF
Almi-Chain · ALMI-BD · secretos generados en el primer arranque ($(date '+%F %T'))
Pásalos a KeePassXC y BORRA este archivo:  sudo shred -u $CRED
Para cambiarlas por otras: sudo ~/scripts/crear-usuarios-bd.sh ~/sql/03-usuarios.sql

MariaDB app_almichain: $P_APP
MariaDB consulta:      $P_CONSULTA   (también en /home/almiadmin/.consulta.cnf)
MariaDB copias:        $P_COPIAS   (también en /root/.my.cnf, la usa copia-bd.sh)
EOF
chmod 600 "$CRED"
unset P_APP P_CONSULTA P_COPIAS
mariadb -e "SELECT User, Host FROM mysql.user WHERE User IN ('app_almichain','consulta','copias')"

# 2. Cortafuegos: este servidor no tiene web; SSH solo desde gestión (VLAN 10) y administración (VLAN 99)
ufw --force reset >/dev/null
ufw default deny incoming
ufw default allow outgoing
for red in 192.168.10.0/24 192.168.99.0/24; do ufw allow from "$red" to any port 22 proto tcp; done
ufw --force enable

mkdir -p /etc/almichain && date '+%F %T' > "$MARCA"
echo "== $(date '+%F %T') Listo. Contraseñas nuevas en $CRED (solo root) =="
