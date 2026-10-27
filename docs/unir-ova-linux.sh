#!/bin/bash
# Almi-Chain: une los trozos de las .ova (si vienen partidas) y comprueba la huella de TODAS.
# Uso (en la carpeta donde están los trozos y los .sha256): bash unir-ova-linux.sh
set -u
mal=0
for sum in *.ova.sha256; do
  [ -e "$sum" ] || { echo "No hay archivos .ova.sha256 en esta carpeta"; exit 1; }
  ova=${sum%.sha256}
  if [ -e "$ova.parte1" ]; then
    echo "Uniendo $ova ..."
    mapfile -t partes < <(printf "%s\n" "$ova".parte* | sort -V)
    cat "${partes[@]}" > "$ova"
  fi
  if [ ! -e "$ova" ]; then echo "FALTA $ova"; mal=1; continue; fi
  if sha256sum -c "$sum"; then
    rm -f "$ova".parte*
  else
    echo "  $ova está dañada: vuelve a descargarla (no se borran los trozos)"; mal=1
  fi
done
[ "$mal" = 0 ] && echo "Todo correcto: ya se pueden importar en VirtualBox." || exit 1
