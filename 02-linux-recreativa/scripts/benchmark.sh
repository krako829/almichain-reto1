#!/bin/bash
# Almi-Chain · Benchmark de la recreativa (guía 3.6 y 3.8)
# Uso: benchmark-recreativa [juego ...]   (por defecto: pong breakout)
# Ejecuta "mame -bench 60" 3 veces por juego como el usuario arcade y saca la media.
JUEGOS=${*:-pong breakout}
echo "== Sistema =="
echo "Núcleos: $(nproc)"
free -m | awk 'NR<=3'
echo "Swap activa: $(swapon --show --noheadings | wc -l) dispositivos"
systemd-analyze 2>/dev/null | head -n 1
echo "Servicios en ejecución: $(systemctl list-units --type=service --state=running --no-legend 2>/dev/null | wc -l)"
echo
echo "== MAME $(mame -version 2>/dev/null) =="
for j in $JUEGOS; do
  suma=0
  for i in 1 2 3; do
    v=$(sudo -u arcade mame -bench 60 "$j" 2>/dev/null | grep -o 'Average speed: *[0-9.]*' | grep -o '[0-9.]*$')
    echo "$j · pasada $i: ${v:-error} %"
    suma=$(echo "$suma + ${v:-0}" | bc -l)
  done
  printf '%s · media: %.2f %%\n' "$j" "$(echo "$suma / 3" | bc -l)"
done
