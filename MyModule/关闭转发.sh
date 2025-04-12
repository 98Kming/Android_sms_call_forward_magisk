MODDIR=${0%/*}
. "$MODDIR/log.sh"
while [ -s "$MODDIR/pid" ]; do
  pid=$(tail -n 1 "$MODDIR/pid")
  pkill -9 -P "$pid" -f 'inotifyd'
  sed -i '1d' "$MODDIR/pid"
  log "stop pid:$pid"
done
if [ ! -f "$MODDIR/disable" ]; then
  touch "$MODDIR/disable"
fi