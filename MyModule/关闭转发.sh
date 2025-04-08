#!/system/bin/sh

MODDIR=${0%/*}
log() {
  echo "$(date +%F_%T)_PID_$$: $1" >> "$MODDIR/log.log"
}

while [ -s $MODDIR/pid ]; do
  pid=$(head -n 1 $MODDIR/pid)
  pkill -9 -P $pid -f 'inotifyd'
  sed -i '1d' $MODDIR/pid
  log "stop pid:$pid"
done
