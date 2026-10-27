#!/bin/bash
# Almi-Chain · Probar las VM construidas con QEMU (sin VirtualBox), sin tocar los discos .raw
#
#   qemu-vm.sh arrancar NOMBRE MEM_MB CPUS serie|grub disco1.raw [disco2.raw ...]
#   qemu-vm.sh parar    NOMBRE
#   qemu-vm.sh pantalla NOMBRE captura.png      (lo que se ve en el monitor de la VM)
#
# - Cada .raw se usa a través de una capa qcow2 nueva en $TRABAJO/NOMBRE/: lo que pase en la prueba
#   (primer arranque, RAID, contraseñas...) NO cambia el .raw que se empaqueta en la OVA.
#   En vez de un .raw se puede dar una capa .qcow2 de antes, para seguir una prueba (por ejemplo,
#   arrancar ALMI-BD sin uno de los discos del RAID).
# - serie: arranca el núcleo de la propia imagen directamente, añadiendo console=ttyS0, para poder
#   manejarla por la consola serie ($TRABAJO/NOMBRE/serie.sock, con qser.py). La imagen entregada
#   no tiene consola serie (en VirtualBox no hace falta).
# - grub:  arranca como lo haría VirtualBox (BIOS → GRUB del disco), sin consola serie; se ve con
#   "pantalla".
# - Red: todas las VM arrancadas así comparten una red (multidifusión de QEMU), como la Red NAT
#   ALMICHAIN, con tarjeta e1000 (la misma que pone la OVA). No tiene salida a Internet.
# - detect-zeroes=unmap: lo que la VM escribe a ceros (p. ej. la sincronización inicial del RAID
#   con discos vacíos) no ocupa sitio en la capa qcow2.
# - Sin KVM (TCG): todo el procesador se emula; es lento y no sirve para medir rendimiento.
set -euo pipefail
TRABAJO=${TRABAJO:-/var/tmp/almi-qemu}
accion=${1:?Uso: qemu-vm.sh arrancar|parar|pantalla ...}; nombre=${2:?Falta el nombre}
D=$TRABAJO/$nombre
monitor() { python3 -c 'import socket,sys,time; s=socket.socket(socket.AF_UNIX); s.connect(sys.argv[1]); time.sleep(0.3); s.recv(65536); s.send((sys.argv[2]+"\n").encode()); time.sleep(1.5); print(s.recv(65536).decode(errors="replace"))' "$D/monitor.sock" "$1"; }

case "$accion" in
  arrancar)
    mem=$3; cpus=$4; modo=$5; shift 5
    [ $# -ge 1 ] || { echo "Falta al menos un disco"; exit 1; }
    mkdir -p "$D"; rm -f "$D"/*.sock
    discos=(); n=0; primero=""
    for disco in "$@"; do
      n=$((n + 1))
      case "$disco" in
        *.raw)   # capa nueva sobre el .raw (empieza "de cero")
          capa="$D/$(basename "$disco" .raw).qcow2"
          qemu-img create -q -f qcow2 -F raw -b "$(realpath "$disco")" "$capa" ;;
        *.qcow2) # capa de una prueba anterior: sigue donde se quedó (p. ej. tras quitar un disco)
          capa=$disco ;;
        *) echo "Disco no válido: $disco"; exit 1 ;;
      esac
      [ -n "$primero" ] || primero=$(qemu-img info --backing-chain "$capa" | awk '/^image:/{i=$2} END{print i}')
      discos+=(-drive "file=$capa,if=none,id=d$n,format=qcow2,discard=unmap,detect-zeroes=unmap" -device "ide-hd,drive=d$n,bus=ide.$((n - 1))")   # SATA (AHCI) de q35
    done
    arranque=()
    if [ "$modo" = serie ]; then
      # Núcleo, initrd y opciones del grub.cfg de la imagen, más la consola serie
      L=$(losetup -fP --show -r "$primero"); partx -a "$L" 2>/dev/null || true
      M=$(mktemp -d); mount -o ro "${L}p1" "$M"
      linea=$(grep -m1 '^ *linux ' "$M/boot/grub/grub.cfg")
      k=$(awk '{print $2}' <<< "$linea"); opciones=$(cut -d' ' -f3- <<< "${linea#"${linea%%[![:space:]]*}"}")
      i=$(grep -m1 '^ *initrd ' "$M/boot/grub/grub.cfg" | awk '{print $2}')
      cp "$M$k" "$D/vmlinuz"; cp "$M$i" "$D/initrd"
      umount "$M"; rmdir "$M"; losetup -d "$L"
      arranque=(-kernel "$D/vmlinuz" -initrd "$D/initrd" -append "$opciones console=tty0 console=ttyS0,115200")
    fi
    qemu-system-x86_64 -name "$nombre" -machine q35 -m "$mem" -smp "$cpus" \
      "${discos[@]}" "${arranque[@]}" \
      -netdev socket,id=red,mcast=230.0.0.10:12310 -device "e1000,netdev=red,mac=52:54:00:00:10:$(printf '%02x' $((RANDOM % 200 + 16)))" \
      -serial "unix:$D/serie.sock,server,nowait" -monitor "unix:$D/monitor.sock,server,nowait" \
      -display none -vga std -daemonize -pidfile "$D/qemu.pid"
    echo "$nombre arrancada ($modo). Consola serie: $D/serie.sock"
    ;;
  parar)
    if [ -f "$D/qemu.pid" ]; then kill "$(cat "$D/qemu.pid")" 2>/dev/null || true; fi
    rm -f "$D/qemu.pid"; echo "$nombre parada"
    ;;
  pantalla)
    out=${3:?Falta el archivo .png}
    monitor "screendump $D/pantalla.ppm" >/dev/null
    python3 -c 'import sys; from PIL import Image; Image.open(sys.argv[1]).save(sys.argv[2])' "$D/pantalla.ppm" "$out"
    echo "$out"
    ;;
  *) echo "Acción desconocida: $accion"; exit 1 ;;
esac
