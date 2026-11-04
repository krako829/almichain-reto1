#!/bin/bash
# Copia de seguridad del equipo ALMI-GERENTE (Win10 / Debian13 en arranque dual)
# Se instala en el servidor de copias en /usr/local/bin/backup_gerente.sh
# y lo lanza el cron del usuario "copia" (ver ../config/crontab.txt).
set -o pipefail
FECHA=$(date +%F_%H%M)
BASE=/backups/gerente
LOG=/backups/backup.log
OPC="-o ConnectTimeout=5 -o BatchMode=yes"
GUARDAR=4

log(){ echo "$(date '+%F %T') $1" >> "$LOG"; }

# 1. Detectar qué sistema está encendido y copiarlo
if ssh $OPC win10 "ver" >/dev/null 2>&1; then
    SO=win10
    mkdir -p "$BASE/$SO/$FECHA"
    # Copia completa con tar por SSH (Windows no trae rsync).
    # Se excluyen los accesos de compatibilidad "Mi música", "Mis imágenes"
    # y "Mis vídeos", que deniegan la lectura a propósito.
    if ssh $OPC win10 'tar -cf - --exclude "Documents/Mi*" Documents Desktop' \
         | tar -xf - --warning=no-unknown-keyword -C "$BASE/$SO/$FECHA"; then
        log "OK    local  win10    $FECHA"
    else
        log "ERROR local  win10    $FECHA"
    fi
elif ssh $OPC debian13 "uname" >/dev/null 2>&1; then
    SO=debian13
    # Incremental: lo que no cambia se enlaza (enlace duro) con la copia anterior
    ULTIMA=$(ls -1d $BASE/$SO/20* 2>/dev/null | tail -n1)
    if rsync -a ${ULTIMA:+--link-dest="$ULTIMA"} -e "ssh $OPC" \
         debian13:/home/almiadmin/ "$BASE/$SO/$FECHA/"; then
        log "OK    local  debian13 $FECHA"
    else
        log "ERROR local  debian13 $FECHA"
    fi
else
    # Aunque el Gerente esté apagado, se sigue para replicar lo que ya hay
    log "AVISO ALMI-GERENTE apagado, no se copia nada"
fi

# 2. Retención: dejar solo las últimas $GUARDAR copias del sistema copiado
ls -1d $BASE/$SO/20* 2>/dev/null | head -n -$GUARDAR | while read -r VIEJA; do
    chmod -R u+w "$VIEJA"
    rm -rf "$VIEJA"
done

# 3. Réplica remota en AWS (espejo de /backups/gerente)
if rsync -aH --delete -e "ssh $OPC" /backups/gerente/ remoto:/backups_remoto/gerente/; then
    log "OK    remoto $SO      $FECHA"
else
    log "ERROR remoto $SO      $FECHA"
fi
