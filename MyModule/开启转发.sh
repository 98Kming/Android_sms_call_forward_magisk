MODDIR=${0%/*}
. $MODDIR/log.sh
if [ ! -f "$MODDIR/disable" ]; then
  "$MODDIR/service.sh" &
else
  log "模块被禁用"
  exit 1
fi