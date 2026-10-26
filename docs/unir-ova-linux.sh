#!/bin/bash
# Almi-Chain: une los trozos de las .ova y comprueba que han llegado bien.
# Uso (en la carpeta donde están los trozos): bash unir-ova-linux.sh
for sum in *.ova.sha256; do
  ova=${sum%.sha256}
  [ -e "$ova.parte1" ] || continue
  echo "Uniendo $ova ..."
  cat $(ls "$ova".parte* | sort -V) > "$ova"
  sha256sum -c "$sum" && rm -f "$ova".parte*
done
