#!/system/bin/sh

MODDIR=${0%/*}
log() {
  echo "$(date +%F_%T)_关闭转发_$$: $1" >> "$MODDIR/log.log"
}

while [ -s $MODDIR/pid ]; do
  pid=$(head -n 1 $MODDIR/pid)
  for child in $(ps -ef --ppid $pid | awk '{if(NR>1)print $2}'); do
    kill -9 $child 1>/dev/null 2>>"$MODDIR/log.log"
    log "stop child pid:$child"
  done
  kill -9 $pid 1>/dev/null 2>>"$MODDIR/log.log"
  sed -i '1d' $MODDIR/pid
  log "stop pid:$pid"
done