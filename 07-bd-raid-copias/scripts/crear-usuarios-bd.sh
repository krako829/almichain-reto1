#!/bin/bash
# Almi-Chain · Crea (o cambia la contraseña de) los 3 usuarios de MariaDB con sql/03-usuarios.sql
#
#   sudo ./crear-usuarios-bd.sh [ruta/a/03-usuarios.sql]
#
# Pide las tres contraseñas sin enseñarlas (read -s) y se las pasa a MariaDB por la entrada
# estándar: no quedan en el historial de bash ni se ven con "ps" mientras se ejecuta.
# Después deja la del usuario "copias" en /root/.my.cnf (600), que es la que usa copia-bd.sh.
set -euo pipefail
SQL=${1:-$(dirname "$0")/../sql/03-usuarios.sql}
[ "$(id -u)" = 0 ] || { echo "Ejecútalo con sudo"; exit 1; }
[ -r "$SQL" ] || { echo "No encuentro $SQL"; exit 1; }

pedir() {  # pedir <variable> <texto>
  local a b
  while :; do
    read -rsp "$2: " a; echo
    read -rsp "Repite la contraseña: " b; echo
    if [ -z "$a" ]; then echo "  No puede estar vacía."; continue; fi
    if [ "${#a}" -lt 12 ]; then echo "  Mínimo 12 caracteres."; continue; fi
    if [ "$a" != "$b" ]; then echo "  No coinciden."; continue; fi
    printf -v "$1" '%s' "$a"; return
  done
}
sql_texto() { local s=${1//\\/\\\\}; printf "'%s'" "${s//\'/\'\'}"; }   # 'texto' con \ y ' escapados

pedir P_APP      "Contraseña de app_almichain"
pedir P_CONSULTA "Contraseña de consulta"
pedir P_COPIAS   "Contraseña de copias"

{
  printf 'SET @p_app = %s;\n'      "$(sql_texto "$P_APP")"
  printf 'SET @p_consulta = %s;\n' "$(sql_texto "$P_CONSULTA")"
  printf 'SET @p_copias = %s;\n'   "$(sql_texto "$P_COPIAS")"
  cat "$SQL"
} | mariadb

# Contraseña de copias para mariadb-dump (copia-bd.sh)
umask 077
printf '[mariadb-dump]\nuser=copias\npassword=%s\n' "$P_COPIAS" > /root/.my.cnf
chmod 600 /root/.my.cnf
unset P_APP P_CONSULTA P_COPIAS

mariadb -e "SELECT User, Host FROM mysql.user WHERE User IN ('app_almichain','consulta','copias')"
echo "Usuarios listos. Guarda las tres contraseñas en KeePassXC."
