MODDIR=${0%/*}
. $MODDIR/log.sh
if [ -f "$MODDIR/disable" ]; then
  rm "$MODDIR/disable"
fi
"$MODDIR/service.sh" &