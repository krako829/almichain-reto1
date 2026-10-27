#!/bin/bash
# Almi-Chain · Pruebas de ALMI-ODOO en QEMU, desde cero, guardando las transcripciones
#
#   CLAVE_INICIAL=... CLAVE_NUEVA=... ./pruebas-odoo.sh <carpeta con ALMI-ODOO.raw> <carpeta de capturas> [MB de RAM]
#
# Primer arranque (secretos nuevos, Docker, base de datos, nginx, cortafuegos) y comprobaciones
# de HTTPS, certificado, secretos y cortafuegos. La VM queda encendida para pruebas-copias.sh.
set -euo pipefail
AQUI=$(cd "$(dirname "$0")" && pwd)
RAW=${1:?Carpeta con ALMI-ODOO.raw}
CAP=${2:?Carpeta donde guardar las transcripciones}
MEM=${3:-3072}
: "${CLAVE_INICIAL:?}" "${CLAVE_NUEVA:?}"
TRABAJO=${TRABAJO:-/var/tmp/almi-qemu}; D=$TRABAJO/odoo; S=$D/serie.sock
C="python3 $AQUI/consola.py $S"
limpia() { grep -v '^\[ *[0-9]' || true; }
DC="sudo docker compose --project-directory /opt/odoo"

"$AQUI/qemu-vm.sh" arrancar odoo "$MEM" 2 serie "$RAW/ALMI-ODOO.raw"
timeout 1500 python3 "$AQUI/consola.py" "$S" entrar almiadmin "$CLAVE_INICIAL" "$CLAVE_NUEVA"
$C escribir "sudo -v"; $C escribir "$CLAVE_NUEVA"
for _ in $(seq 1 120); do
  e=$($C orden 90 "systemctl is-active almi-primer-arranque" 2>/dev/null | grep -E '^(active|failed)$' | tail -1 || true)
  [ -n "$e" ] && break; sleep 30
done
echo "almi-primer-arranque: ${e:-no termina}"
# Odoo tarda en responder la primera vez (sin aceleración): se espera a que dé 200
$C orden 900 "for i in \$(seq 1 80); do [ \"\$(curl -s -o /dev/null -w '%{http_code}' --cacert /etc/ssl/almichain/odoo.crt https://192.168.10.30/web/login)\" = 200 ] && break; sleep 10; done" >/dev/null || true
$C escribir "sudo -v"; $C escribir "$CLAVE_NUEVA"

$C transcribir "$CAP/36-vm-primer-arranque.txt" 300 \
  "sudo grep -E '^== ' /var/log/almi-primer-arranque.log" \
  "$DC ps --format 'table {{.Name}}\t{{.Image}}\t{{.Status}}'" \
  "curl -s -o /dev/null -w 'HTTPS %{http_code}\n' --cacert /etc/ssl/almichain/odoo.crt https://192.168.10.30/web/login" \
  "$DC exec -T db psql -U odoo -d almichain -c 'SELECT name, state, amount_total FROM pos_order ORDER BY id'" \
  "$DC exec -T db psql -U odoo -d almichain -c \"SELECT key, value FROM ir_config_parameter WHERE key IN ('web.base.url','web.base.url.freeze','report.url') ORDER BY key\"" | limpia
$C transcribir "$CAP/37-vm-certificado-servidor.txt" 120 \
  "openssl x509 -in /etc/ssl/almichain/odoo.crt -noout -subject -ext basicConstraints,keyUsage,extendedKeyUsage,subjectAltName" \
  "openssl x509 -in /etc/ssl/almichain/odoo.crt -noout -fingerprint -sha256" \
  "curl -s http://192.168.10.30/almichain-odoo.crt | openssl x509 -noout -fingerprint -sha256" \
  "curl -s -o /dev/null -w 'odoo.key por HTTP: %{http_code} (redirige, no se publica)\n' http://192.168.10.30/odoo.key" \
  "curl -sI http://192.168.10.30/web | head -3" \
  "sudo ls -l /etc/ssl/almichain/" "cat /etc/issue.d/almichain-odoo.issue" | limpia
$C transcribir "$CAP/38-vm-secretos-cortafuegos.txt" 120 \
  "sudo ufw status" "ss -ltn | grep -E ':(22|80|443|8069) '" \
  "sudo stat -c '%a %U %n' /opt/odoo/.env /root/credenciales-primer-arranque.txt" \
  "sudo grep -c 'contraseña maestra larga' /opt/odoo/config/odoo.conf" \
  "ls /etc/ssh/ssh_host_*_key.pub; systemctl is-active ssh nginx docker" \
  "sudo chage -l almiadmin | head -1" | limpia
echo "Pruebas de ALMI-ODOO terminadas: $CAP"
