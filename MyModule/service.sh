#!/system/bin/sh
MODDIR=${0%/*}

# 指定日志文件路径
log() {
 echo "$(date +%F_%T) $1" >> "$MODDIR/log.log"
}


# 等待系统初始化完成
until [ "$(getprop sys.boot_completed)" -eq 1 ] ; do
  sleep 5
done

chmod -R 777 $MODDIR
chmod -R 777 /data/data/com.android.providers.telephony/databases
chmod -R 777 /data/data/com.android.providers.contacts/databases

run=2
while true
do
  if [ -f $MODDIR/disable ] ;then
    if [ $run -eq 1 ] ;then
      sh $MODDIR/关闭转发.sh
      run=0
      log "模块已关闭，停止运行"
    fi
  else
    if [ $run -eq 0 ] || [ $run -eq 2 ] ;then
      sh $MODDIR/开启转发.sh
      run=1
      log "模块启动，运行中"
    fi
  fi
  sleep 5
done