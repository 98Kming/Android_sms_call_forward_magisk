#!/system/bin/sh

# 等待系统初始化完成
until [ "$(getprop sys.boot_completed)" -eq 1 ] ; do
  sleep 5
done

log() {
  echo "$(date +%F_%T)_service_$$: $1" >> "$MODDIR/log.log"
}

MODDIR=${0%/*}

chmod -R 755 $MODDIR

echo $$ >> $MODDIR/pid

sh $MODDIR/开启转发.sh 1>/dev/null 2>> $MODDIR/log.log

inotifyd - "/data/data/com.android.providers.telephony/databases/mmssms.db:aoce" | while read -r event; do
  log "$event"
  inotifyd - "/data/data/com.android.providers.telephony/databases/mmssms.db:x"
done
