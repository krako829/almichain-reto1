#!/bin/bash
# Almi-Chain · Genera la memoria (docs/Documentacion-Reto1-Almi-Chain.docx y .pdf) desde los README
# Necesita: pandoc 3, python3-docx, Pillow, mmdc (Mermaid CLI) y LibreOffice (para el índice y el PDF).
set -euo pipefail
AQUI=$(cd "$(dirname "$0")" && pwd); REPO=$(cd "$AQUI/../.." && pwd)
W=${TRABAJO:-$AQUI/trabajo}; mkdir -p "$W"
python3 "$AQUI/juntar.py" "$W"
pandoc -o "$W/ref-base.docx" --print-default-data-file reference.docx
python3 "$AQUI/estilos.py" "$W"
pandoc "$W/documentacion.md" -f markdown-implicit_header_references+pipe_tables -o "$W/cuerpo.docx" \
  --reference-doc "$W/ref.docx" --toc --toc-depth=2 --resource-path "$REPO" -M lang=es-ES -M title=" "
python3 "$AQUI/portada.py" "$W"
# LibreOffice sin pantalla, escuchando para que indice.py le pida actualizar el índice
soffice --headless --invisible --norestore --accept="socket,host=localhost,port=2002;urp;" >/dev/null 2>&1 &
SO=$!
for _ in $(seq 1 30); do python3 -c 'import socket; socket.create_connection(("localhost",2002),1)' 2>/dev/null && break; sleep 1; done
python3 "$AQUI/indice.py" "$W/con-portada.docx" "$REPO/docs/Documentacion-Reto1-Almi-Chain.docx" "$REPO/docs/Documentacion-Reto1-Almi-Chain.pdf"
kill "$SO" 2>/dev/null || true
pdfinfo "$REPO/docs/Documentacion-Reto1-Almi-Chain.pdf" | grep Pages
