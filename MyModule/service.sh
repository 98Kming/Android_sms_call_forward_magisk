MODDIR=${0%/*}
# 等待系统初始化完成
until [ "$(getprop sys.boot_completed)" -eq 1 ] ; do
  sleep 5
done
while [ -s "$MODDIR/pid" ]; do
  pid=$(head -n 1 "$MODDIR/pid")
  pkill -9 -P "$pid" -f 'inotifyd'
  sed -i '1d' "$MODDIR/pid"
  log "stop pid:$pid"
done
. "$MODDIR/config.ini"
chmod -R 755 "$MODDIR"
echo $$ >> "$MODDIR/pid"

. "$MODDIR/log.sh"
cleanup() {
  log "程序关闭"
  logCmd "pgrep -P $$ -f 'inotifyd'"
}

trap cleanup EXIT

#/data/adb/ksu/bin/busybox sh -o standalone script -q -c "$MODDIR/test.sh" /dev/null | awk -v ts="$timestamp" 'BEGIN{RS="^$"} {printf "[%s] %s\n", ts, $0; fflush()}' | tee -a $MODDIR/log.log
logSh "$MODDIR/forward.sh"
#/system/bin/sh $MODDIR/test.sh 2>&1 2>&1 | awk -v ts="$timestamp" 'BEGIN{RS="^$"} {printf "[%s] %s\n", ts, $0}' | tee $MODDIR/log.log

