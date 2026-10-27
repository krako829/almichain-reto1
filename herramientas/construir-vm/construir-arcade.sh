#!/bin/bash
# Almi-Chain · ALMI-ARCADE: recreativa con MAME (1 núcleo, 1 GB, sin swap, arranque directo a MAME)
#
#   sudo CREDENCIALES=... CLAVES=... ./construir-arcade.sh      (CREDENCIALES con ARCADE_PASS)
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"
: "${ARCADE_PASS:?Falta ARCADE_PASS en $CREDENCIALES}"
B=$REPO/02-linux-recreativa

crear_disco "$SALIDA/ALMI-ARCADE.raw" 8
base_ubuntu almi-arcade dhcp
# Núcleo con los módulos de vídeo de VirtualBox (VMSVGA = vmwgfx) y sonido
KVER=$(cd "$R/boot" && find . -maxdepth 1 -name 'vmlinuz-*' -printf '%f\n' | sort -V | tail -1 | sed 's/vmlinuz-//')
apt_chroot "linux-modules-extra-$KVER" xserver-xorg-core xserver-xorg-input-libinput xinit x11-xserver-utils \
  alsa-utils mame libpam-pwquality cracklib-runtime xserver-xorg-video-fbdev xserver-xorg-video-vesa

# --- Usuarios y seguridad (README 02, apartado 3) ---
en_chroot "useradd -m -s /bin/bash -c 'Recreativa' -G audio,video,input arcade && chmod 700 /home/arcade"
printf 'arcade:%s\n' "$ARCADE_PASS" | chroot "$R" chpasswd
sed -i 's/^# *minlen.*/minlen = 12/' "$R/etc/security/pwquality.conf"
# Cortafuegos: todo lo que entra bloqueado (se activa al arrancar)
sed -i 's/^ENABLED=.*/ENABLED=yes/' "$R/etc/ufw/ufw.conf"
sed -i 's/^DEFAULT_INPUT_POLICY=.*/DEFAULT_INPUT_POLICY="DROP"/; s/^DEFAULT_OUTPUT_POLICY=.*/DEFAULT_OUTPUT_POLICY="ACCEPT"/' "$R/etc/default/ufw"
en_chroot "systemctl enable ufw >/dev/null 2>&1; systemctl disable ssh ssh.socket >/dev/null 2>&1 || true"   # recreativa sin SSH

# --- Arranque automático en MAME (README 02, apartado 5): todo de root y fuera de /home/arcade ---
mkdir -p "$R/etc/systemd/system/getty@tty1.service.d"
install -m 644 "$B/config/autologin.conf" "$R/etc/systemd/system/getty@tty1.service.d/override.conf"
install -o 0 -g 0 -m 644 "$B/config/recreativa-profile.sh" "$R/etc/profile.d/recreativa.sh"
install -o 0 -g 0 -m 755 "$B/config/recreativa-sesion" "$R/usr/local/bin/recreativa-sesion"
mkdir -p "$R/home/arcade/.mame" "$R/home/arcade/rendimiento"
install -m 644 "$B/config/mame.ini" "$B/config/ui.ini" "$R/home/arcade/.mame/"
en_chroot "chown -R arcade:arcade /home/arcade/.mame /home/arcade/rendimiento"
mkdir -p "$R/usr/local/share/games/mame/roms"
install -m 644 "$B/config/LEEME-roms.txt" "$R/usr/local/share/games/mame/roms/"

# --- Optimización (README 02, apartado 6) ---
mkdir -p "$R/etc/systemd/journald.conf.d"
printf '[Journal]\nStorage=volatile\nRuntimeMaxUse=20M\n' > "$R/etc/systemd/journald.conf.d/arcade.conf"
sed -i 's/^#NAutoVTs=.*/NAutoVTs=2/' "$R/etc/systemd/logind.conf"
for u in apt-daily.timer apt-daily-upgrade.timer man-db.timer e2scrub_all.timer fstrim.timer motd-news.timer unattended-upgrades.service; do
  en_chroot "systemctl disable $u >/dev/null 2>&1 || true"
done
en_chroot "systemctl mask systemd-networkd-wait-online.service >/dev/null 2>&1 || true"
install -m 755 "$B/scripts/benchmark.sh" "$R/usr/local/bin/benchmark-recreativa"

# Sin swap: no hay partición de intercambio ni archivo swap; el núcleo solo ve 1 núcleo y 1 GB
instalar_grub "quiet mem=1024M nr_cpus=1"
limpiar
desmontar_todo
echo "ALMI-ARCADE listo: $SALIDA/ALMI-ARCADE.raw"
