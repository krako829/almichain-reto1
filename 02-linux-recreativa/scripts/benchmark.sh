#!/bin/bash
# Almi-Chain · Benchmark de la recreativa (guía 3.6 y 3.8)
# Uso: benchmark-recreativa [juego ...]   (por defecto: pong breakout)
# Ejecuta "mame -bench 60" 3 veces por juego como el usuario arcade y saca la media.
# Se lanza con sudo (para hacerse pasar por arcade): sudo benchmark-recreativa
JUEGOS=${*:-pong breakout}
# Ruta completa: sudo no busca en /usr/games (no está en su secure_path)
MAME=$(command -v mame || echo /usr/games/mame)
echo "== Sistema =="
echo "Núcleos: $(nproc)"
free -m | awk 'NR<=3'
echo "Swap activa: $(swapon --show --noheadings | wc -l) dispositivos"
systemd-analyze 2>/dev/null | head -n 1
echo "Servicios en ejecución: $(systemctl list-units --type=service --state=running --no-legend 2>/dev/null | wc -l)"
echo
echo "== MAME $("$MAME" -version 2>/dev/null) =="
for j in $JUEGOS; do
  valores=""
  for i in 1 2 3; do
    v=$(sudo -u arcade "$MAME" -bench 60 "$j" 2>/dev/null | grep -o 'Average speed: *[0-9.]*' | grep -o '[0-9.]*$')
    echo "$j · pasada $i: ${v:-error} %"
    valores="$valores ${v:-}"
  done
  # Media de las pasadas que han funcionado (awk: no hace falta instalar bc)
  echo "$valores" | awk -v j="$j" '{ for (k = 1; k <= NF; k++) s += $k }
    NF { printf "%s · media: %.2f %% (%d pasadas)\n", j, s / NF, NF; next } { print j " · media: sin datos" }'
done
