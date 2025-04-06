#!/system/bin/sh

# 等待系统初始化完成
until [ "$(getprop sys.boot_completed)" -eq 1 ] ; do
  sleep 5
done

MODDIR=${0%/*}

chmod -R 755 $MODDIR

sh $MODDIR/开启转发.sh 1>/dev/null 2>>"$MODDIR"/log.log
