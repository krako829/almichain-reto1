#!/bin/bash
# Almi-Chain · Funciones comunes para construir las VM (Ubuntu 24.04, BIOS + GRUB, disco SATA)
#
# Las imágenes se construyen con debootstrap en un disco .raw montado con un dispositivo loop,
# NO con el instalador de Ubuntu Server que describen los README. El resultado es el mismo
# sistema (Ubuntu 24.04 con los mismos paquetes y la misma configuración de los README), pero
# sin LVM y sin pasar por las pantallas del instalador. Ver herramientas/README.md.
#
# Variables que hay que dar (nunca se guardan en el repositorio):
#   CREDENCIALES  archivo con ALMIADMIN_PASS=... y, para la recreativa, ARCADE_PASS=...
#   CLAVES        carpeta donde se crean (la primera vez) las claves de las copias cruzadas
#   SALIDA        carpeta donde se dejan los discos .raw (por defecto ./salida)
# Opcional:
#   APT_CA        certificado de un proxy que haya que usar durante la construcción
set -euo pipefail
AQUI=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC2034  # REPO y LIMPIAR_RECIBIDAS se usan en los construir-*.sh
REPO=$(cd "$AQUI/../.." && pwd)
MIRROR=${MIRROR:-https://archive.ubuntu.com/ubuntu}
SALIDA=${SALIDA:-$AQUI/salida}
: "${CREDENCIALES:?Indica el archivo de contraseñas: CREDENCIALES=/ruta/credenciales-vm.txt}"
: "${CLAVES:?Indica la carpeta de claves de copias: CLAVES=/ruta/claves}"
# shellcheck disable=SC1090
source "$CREDENCIALES"
: "${ALMIADMIN_PASS:?Falta ALMIADMIN_PASS en $CREDENCIALES}"
mkdir -p "$SALIDA"
[ "$(id -u)" = 0 ] || { echo "Hay que ejecutarlo como root (debootstrap, losetup, mount)"; exit 1; }

# crear_disco <archivo.raw> <tamaño en GB>  -> deja montado en $R y el loop en $LOOP
crear_disco() {
  local img=$1 gb=$2
  rm -f "$img"; truncate -s "${gb}G" "$img"
  printf 'label: dos\n,,L,*\n' | sfdisk -q "$img"
  LOOP=$(losetup -fP --show "$img")
  sleep 1; partx -u "$LOOP" 2>/dev/null || true
  mkfs.ext4 -q -L raiz "${LOOP}p1"
  R=/mnt/vm-$(basename "$img" .raw); mkdir -p "$R"; mount "${LOOP}p1" "$R"
  export R LOOP
}

montar_sistemas() {
  for d in proc sys dev dev/pts; do mkdir -p "$R/$d"; mount --bind "/$d" "$R/$d"; done
  mkdir -p "$R/run"; mount -t tmpfs tmpfs "$R/run"
}

desmontar_todo() {
  for d in run dev/pts dev sys proc; do umount -l "$R/$d" 2>/dev/null || true; done
  sync; umount "$R"; losetup -d "$LOOP"
}

# en_chroot "comando"  (el proxy, si lo hay, solo durante la construcción: no queda en la VM)
en_chroot() {
  chroot "$R" /usr/bin/env -i PATH=/usr/sbin:/usr/bin:/sbin:/bin HOME=/root LANG=C.UTF-8 \
    DEBIAN_FRONTEND=noninteractive https_proxy="${HTTPS_PROXY:-${https_proxy:-}}" /bin/bash -c "$1"
}

apt_chroot() {  # apt_chroot paquete1 paquete2 ...
  local ca=""
  if [ -n "${APT_CA:-}" ]; then cp "$APT_CA" "$R/tmp/ca.crt"; ca="-o Acquire::https::CAInfo=/tmp/ca.crt"; fi
  en_chroot "apt-get $ca update -qq && apt-get $ca install -y -q --no-install-recommends $* && apt-get clean"
}

base_ubuntu() {  # base_ubuntu <hostname> <ip/24 o dhcp>
  local host=$1 ip=$2 red uuid
  debootstrap --variant=minbase --components=main,universe \
    --include=systemd-sysv,udev,dbus,dbus-user-session,libpam-systemd,sudo,apt-utils,locales,tzdata,console-setup,keyboard-configuration,kbd,netplan.io,systemd-resolved,iproute2,iputils-ping,nano,less,ca-certificates,curl,cron,rsync,openssh-server,ufw,bash-completion,htop,procps,initramfs-tools,e2fsprogs,unattended-upgrades,openssl \
    noble "$R" "$MIRROR" > "$SALIDA/debootstrap-$host.log" 2>&1
  montar_sistemas
  cat > "$R/etc/apt/sources.list" <<EOF
deb https://archive.ubuntu.com/ubuntu noble main restricted universe multiverse
deb https://archive.ubuntu.com/ubuntu noble-updates main restricted universe multiverse
deb https://security.ubuntu.com/ubuntu noble-security main restricted universe multiverse
EOF
  apt_chroot linux-image-virtual
  # fstab, nombre, red, idioma y zona horaria
  uuid=$(blkid -s UUID -o value "${LOOP}p1")
  echo "UUID=$uuid / ext4 errors=remount-ro 0 1" > "$R/etc/fstab"
  echo "$host" > "$R/etc/hostname"
  printf '127.0.0.1 localhost\n127.0.1.1 %s\n192.168.10.20 almi-bd\n192.168.10.30 almi-odoo\n' "$host" > "$R/etc/hosts"
  if [ "$ip" = dhcp ]; then
    red="      dhcp4: true"
  else
    red="      dhcp4: false
      addresses: [$ip]
      routes:
        - to: default
          via: 192.168.10.1
      nameservers:
        addresses: [1.1.1.1, 9.9.9.9]"
  fi
  cat > "$R/etc/netplan/50-almichain.yaml" <<EOF
# Red de Almi-Chain: Red NAT ALMICHAIN de VirtualBox (192.168.10.0/24)
network:
  version: 2
  ethernets:
    lan:
      match:
        name: "en*"
$red
EOF
  chmod 600 "$R/etc/netplan/50-almichain.yaml"
  en_chroot "systemctl enable systemd-networkd systemd-resolved ssh cron >/dev/null 2>&1; ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf"
  sed -i 's/^# *es_ES.UTF-8/es_ES.UTF-8/' "$R/etc/locale.gen"; grep -q '^es_ES.UTF-8' "$R/etc/locale.gen" || echo 'es_ES.UTF-8 UTF-8' >> "$R/etc/locale.gen"
  en_chroot "locale-gen >/dev/null && update-locale LANG=es_ES.UTF-8 && ln -sf /usr/share/zoneinfo/Europe/Madrid /etc/localtime && echo Europe/Madrid > /etc/timezone"
  printf 'XKBMODEL="pc105"\nXKBLAYOUT="es"\nXKBVARIANT=""\nXKBOPTIONS=""\nBACKSPACE="guess"\n' > "$R/etc/default/keyboard"
  # Usuario administrador con la contraseña inicial; tiene que cambiarla al entrar la primera vez
  en_chroot "useradd -m -s /bin/bash -c 'Administrador Almi' -G sudo,adm almiadmin && chmod 700 /home/almiadmin"
  printf 'almiadmin:%s\n' "$ALMIADMIN_PASS" | chroot "$R" chpasswd
  en_chroot "chage -d 0 almiadmin"
  # SSH: sin root; con contraseña para el primer acceso (luego se puede pasar a solo clave)
  printf 'PermitRootLogin no\nPasswordAuthentication yes\nX11Forwarding no\nMaxAuthTries 4\n' > "$R/etc/ssh/sshd_config.d/50-almichain.conf"
  # Claves de host SSH: la imagen NO lleva ninguna; cada VM importada crea las suyas al arrancar
  rm -f "$R"/etc/ssh/ssh_host_*
  # ssh-keygen -A justo antes de sshd: crea solo las que falten. (Un servicio aparte "antes de
  # ssh.socket" forma un ciclo con sockets.target y systemd lo descarta.)
  mkdir -p "$R/etc/systemd/system/ssh.service.d"
  printf '[Service]\nExecStartPre=\nExecStartPre=/usr/bin/ssh-keygen -A\nExecStartPre=/usr/sbin/sshd -t\n' \
    > "$R/etc/systemd/system/ssh.service.d/almi-claves.conf"
  # machine-id vacío: se genera en el primer arranque (cada VM importada tiene el suyo)
  : > "$R/etc/machine-id"; rm -f "$R/var/lib/dbus/machine-id"
}

instalar_grub() {  # instalar_grub "<opciones extra del núcleo>"
  local extra=${1:-}
  # Primero los paquetes (su postinst regenera grub.cfg); después se escribe el grub.cfg bueno
  echo "grub-pc grub-pc/install_devices multiselect /dev/sda" | chroot "$R" debconf-set-selections
  apt_chroot grub-pc-bin grub2-common grub-pc >/dev/null 2>&1 || true
  sed -i "s#^GRUB_CMDLINE_LINUX_DEFAULT=.*#GRUB_CMDLINE_LINUX_DEFAULT=\"$extra\"#; s#^GRUB_CMDLINE_LINUX=.*#GRUB_CMDLINE_LINUX=\"\"#; s#^GRUB_TIMEOUT=.*#GRUB_TIMEOUT=3#" "$R/etc/default/grub" 2>/dev/null || true
  grub-install --target=i386-pc --boot-directory="$R/boot" --modules="part_msdos ext2" "$LOOP" >/dev/null 2>&1
  escribir_grub_cfg "$extra"
}

# grub.cfg escrito a mano: update-grub dentro del chroot pondría root=/dev/loopXp1 (el disco de
# la construcción) y la VM no arrancaría. Se usa el UUID del sistema de archivos.
escribir_grub_cfg() {
  local extra=${1:-} uuid k i host
  uuid=$(blkid -s UUID -o value "${LOOP}p1")
  k=$(cd "$R/boot" && find . -maxdepth 1 -name 'vmlinuz-*' -printf '%f\n' | sort -V | tail -1); i=${k/vmlinuz/initrd.img}
  host=$(cat "$R/etc/hostname")
  {
    echo "set timeout=3"
    echo "set default=0"
    echo "insmod part_msdos"
    echo "insmod ext2"
    echo "search --no-floppy --fs-uuid --set=root $uuid"
    echo "menuentry \"Ubuntu 24.04 LTS - $host\" {"
    echo "  linux /boot/$k root=UUID=$uuid ro $extra"
    echo "  initrd /boot/$i"
    echo "}"
  } > "$R/boot/grub/grub.cfg"
}

limpiar() {
  rm -f "$R/tmp/ca.crt"
  rm -rf "$R/var/lib/apt/lists/"* "$R/var/cache/apt/archives/"*.deb "$R/root/.bash_history"
  : > "$R/var/log/lastlog" 2>/dev/null || true
  find "$R/var/log" -type f -name '*.log' -size +0 -exec truncate -s 0 {} \; 2>/dev/null || true
  # Rellenar con ceros el espacio libre para que la OVA comprima bien
  fstrim "$R" 2>/dev/null || { dd if=/dev/zero of="$R/zero" bs=4M status=none 2>/dev/null || true; rm -f "$R/zero"; }
}

# Claves de las copias cruzadas (las mismas en las dos VM: así funcionan nada más importarlas).
# Se crean una vez en $CLAVES y se reutilizan al construir la otra VM.
claves_copias() {
  local q
  for q in bd odoo; do
    mkdir -p "$CLAVES/$q"; chmod 700 "$CLAVES" "$CLAVES/$q"
    [ -f "$CLAVES/$q/copias_ed25519" ] || ssh-keygen -q -t ed25519 -N '' -C "copias-$q" -f "$CLAVES/$q/copias_ed25519"
  done
}
# copias_receptor <origen bd|odoo> <ip origen>: usuario copias que solo acepta la clave del otro
# servidor y solo para ESCRIBIR en su carpeta (rrsync -wo -no-del)
copias_receptor() {
  local origen=$1 ip=$2
  claves_copias
  en_chroot "id copias >/dev/null 2>&1 || useradd -m -s /bin/bash -c 'Copias de seguridad' copias; passwd -l copias >/dev/null"
  mkdir -p "$R/srv/copias-remotas/$origen" "$R/home/copias/.ssh"
  echo "command=\"/usr/bin/rrsync -wo -no-del /srv/copias-remotas/$origen/\",from=\"$ip\",restrict $(cat "$CLAVES/$origen/copias_ed25519.pub")" > "$R/home/copias/.ssh/authorized_keys"
  en_chroot "chown -R copias:copias /srv/copias-remotas /home/copias/.ssh && chmod 700 /srv/copias-remotas /home/copias/.ssh && chmod 600 /home/copias/.ssh/authorized_keys"
}
# clave_envio <bd|odoo>: clave privada de root para enviar las copias al otro servidor
clave_envio() {
  claves_copias
  mkdir -p "$R/root/.ssh"; chmod 700 "$R/root/.ssh"
  install -m 600 "$CLAVES/$1/copias_ed25519" "$R/root/.ssh/copias_ed25519"
  install -m 644 "$CLAVES/$1/copias_ed25519.pub" "$R/root/.ssh/copias_ed25519.pub"
}
# cron_root "línea1" ["línea2" ...]
cron_root() {
  mkdir -p "$R/var/spool/cron/crontabs"
  { echo '# Copias de seguridad de Almi-Chain'; printf '%s\n' "$@"; } > "$R/var/spool/cron/crontabs/root"
  en_chroot "chown root:crontab /var/spool/cron/crontabs/root && chmod 600 /var/spool/cron/crontabs/root"
}
# Las copias que llegan del otro servidor las borra quien las recibe (el que envía no puede)
# shellcheck disable=SC2034
LIMPIAR_RECIBIDAS='15 3 * * * find /srv/copias-remotas -type f -mtime +30 -delete'
