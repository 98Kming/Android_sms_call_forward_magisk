#!/system/bin/sh

# 等待系统初始化完成
until [ "$(getprop sys.boot_completed)" -eq 1 ] ; do
  sleep 5
done

MODDIR=${0%/*}

chmod -R 755 $MODDIR

. $MODDIR/global.sh
pkill inotifyd
webhook="$(getAttr webhook)"
sms_enable="$(getAttr sms_enable)"
sms_format="$(getAttr sms_format)"
sms_db="$(getAttr sms_db)"
call_enable=$(getAttr call_enable)
call_format=$(getAttr call_format)
call_db="$(getAttr call_db)"

chmod 666 "$sms_db"
chmod 666 "$call_db"
if [ -z $webhook ]; then
  log "webhook 未配置，请到 config.conf 中配置webhook地址"
  exit 0
fi

if [ "$sms_enable" != 1 -a "$call_enable" != 1 ]; then
  log "短信及未接来电转发功能全部关闭，程序退出。请检查配置"
  exit 0
fi

if [ "$sms_enable" == 1 ];then
  init $sms_enable $sms_db "SELECT _id FROM sms ORDER BY _id DESC LIMIT 1;" "last_sms_id" "sendSms"
fi

if [ "$call_enable" == 1 ];then
  init $call_enable $call_db "SELECT _id FROM calls ORDER BY _id DESC LIMIT 1;" "last_call_id" "sendCall"
fi

listen() {
  inotifyd - "$CALL_DB_PATH:c" "$SMS_DB_PATH:c" "$MODDIR:ndm" "$MODDIR/config.conf:cw" | while read -r event; do
    # 监听目录时数组为(操作,路径,文件名) 监听文件时数组为(操作,路径+文件名)
    arr=($(echo "$event" | awk -F'	' '{print}'))
    if [[ "${arr[1]}" == "$SMS_DB_PATH" && "$sms_enable" == 1  ]]; then
      # 短信数据库修改
      sendSms "$last_sms_id"
    fi
    if [[ "${arr[1]}" == "$CALL_DB_PATH" && "$call_enable" == "1"  ]]; then
       # 电话数据库修改
      sendCall "$last_call_id"
    fi
    if [ "${arr[0]}" == "m" -a "${arr[2]}" == "config.conf" ] || [ "${arr[0]}" == "w" -a "${arr[1]}" == "$MODDIR/config.conf" ]; then
      # 配置文件修改检查
      checkConfigMod
    fi
    if [ "${arr[0]}" = "n" -a "${arr[2]}" = "disable" ]; then
      log "模块被关闭"
      log "$event"
    fi
    if [ "${arr[0]}" = "d" -a "${arr[2]}" = "disable" ]; then
      log "模块被开启"
      log "$event"
    fi
  done
}



#listen

log "启动成功"