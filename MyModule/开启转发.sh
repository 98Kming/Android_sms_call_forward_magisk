#!/system/bin/sh
MODDIR=${0%/*}
sh $MODDIR/forward.sh
inotifyd - "$MODDIR:nd" | while read -r event; do
    # 监听目录时数组为(操作,路径,文件名) 监听文件时数组为(操作,路径+文件名)
    arr=($(echo "$event" | awk -F'	' '{print}'))
    if [ "${arr[0]}" = "n" -a "${arr[2]}" = "disable" ]; then
      log "模块被关闭"
      sh $MODDIR/关闭转发.sh
    fi
    if [ "${arr[0]}" = "d" -a "${arr[2]}" = "disable" ]; then
      log "模块被开启"
      sh $MODDIR/forward.sh
    fi
  done