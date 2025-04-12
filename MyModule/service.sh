MODDIR=${0%/*}
# 等待系统初始化完成
until [ "$(getprop sys.boot_completed)" -eq 1 ] ; do
  sleep 5
done
chmod -R 755 "$MODDIR"

rm "$MODDIR/log.log"
. "$MODDIR/log.sh"

while [ -s "$MODDIR/pid" ]; do
  _pid=$(tail -n 1 "$MODDIR/pid")
  pkill -9 -P "$_pid" -f 'inotifyd'
  sed -i '1d' "$MODDIR/pid"
  log "stop pid:$_pid"
done

echo $$ >> "$MODDIR/pid"
. "$MODDIR/config.ini"

if [ -f "$MODDIR/disable" ]; then
  rm "$MODDIR/disable"
fi

cleanup() {
  logCmd "pgrep -P $$ -f 'inotifyd'"
#  # 检查子进程 PID 是否存在
#  if [ -n "$child_pid" ]; then
#    # 向子进程发送终止信号
#    kill "$child_pid"
#    # 等待子进程结束
#    log "结束子进程:$child_pid"
#    sed -i "/^$child_pid$/d" "$MODDIR/pid"
#    wait "$child_pid"
#  fi
#  sed -i "/^$pid$/d" "$MODDIR/pid"
  log "程序退出"
#  # 退出父进程
#  exit 0
}

trap cleanup EXIT

#/data/adb/ksu/bin/busybox sh -o standalone script -q -c "$MODDIR/test.sh" /dev/null | awk -v ts="$timestamp" 'BEGIN{RS="^$"} {printf "[%s] %s\n", ts, $0; fflush()}' | tee -a $MODDIR/log.log
logSh "$MODDIR/forward.sh"
#/system/bin/sh $MODDIR/test.sh 2>&1 2>&1 | awk -v ts="$timestamp" 'BEGIN{RS="^$"} {printf "[%s] %s\n", ts, $0}' | tee $MODDIR/log.log

