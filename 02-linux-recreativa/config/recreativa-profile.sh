# shellcheck shell=sh
# /etc/profile.d/recreativa.sh  (de root, fuera de la carpeta de arcade)
# Al entrar arcade en tty1 arranca el servidor gráfico con la sesión de la recreativa.
# Está aquí y no en /home/arcade/.bash_profile porque arcade es dueño de su carpeta y podría
# borrar o cambiar cualquier archivo que esté dentro, aunque sea de root.
if [ "$(id -un)" = "arcade" ] && [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
  exec startx /usr/local/bin/recreativa-sesion -- -nocursor > /dev/null 2>&1
fi
