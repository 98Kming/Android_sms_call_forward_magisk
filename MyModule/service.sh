MODDIR=${0%/*}
# 等待系统初始化完成
until [ "$(getprop sys.boot_completed)" -eq 1 ] ; do
  sleep 5
done
chmod -R 755 "$MODDIR"

rm "$MODDIR/log.log"
. "$MODDIR/log.sh"

#/data/adb/ksu/bin/busybox sh -o standalone script -q -c "$MODDIR/test.sh" /dev/null | awk -v ts="$timestamp" 'BEGIN{RS="^$"} {printf "[%s] %s\n", ts, $0; fflush()}' | tee -a $MODDIR/log.log
logSh "$MODDIR/start_docker.sh" $1
#/system/bin/sh $MODDIR/test.sh 2>&1 2>&1 | awk -v ts="$timestamp" 'BEGIN{RS="^$"} {printf "[%s] %s\n", ts, $0}' | tee $MODDIR/log.log

