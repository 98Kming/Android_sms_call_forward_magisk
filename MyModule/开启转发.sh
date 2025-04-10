#!/system/bin/sh
MODDIR=${0%/*}
log() {
  printf "%s\n" "$(date +%F_%T)_PID_$$: $1"
  printf "%s\n" "$(date +%F_%T)_PID_$$: $1" >> "$MODDIR/log.log"
}
if [ ! -f "$MODDIR/disable" ]; then
  sh $MODDIR/forward.sh 1>/dev/null 2>>"$MODDIR/log.log"
else
  log "模块被禁用"
fi
$MODDIR/关闭转发.sh
. $MODDIR/config.ini
echo $$ >> $MODDIR/pid
inotifyd - "$MODDIR:nd" | while read -r event; do
  # 监听目录时数组为(操作,路径,文件名) 监听文件时数组为(操作,路径+文件名)
  eval "arr=($event)"
  if [ "${arr[0]}" = "n" -a "${arr[2]}" = "disable" ]; then
    log "模块被关闭"
    sh $MODDIR/关闭转发.sh 1>/dev/null 2>>"$MODDIR/log.log"
  fi
  if [ "${arr[0]}" = "d" -a "${arr[2]}" = "disable" ]; then
    log "模块被开启"
    sh $MODDIR/forward.sh 1>/dev/null 2>>"$MODDIR/log.log"
  fi
done