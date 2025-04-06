#!/system/bin/sh

# 等待系统初始化完成
until [ "$(getprop sys.boot_completed)" -eq 1 ] ; do
  sleep 5
done

MODDIR=${0%/*}

chomd 0755 $MODDIR

. $MODDIR/global.sh
pkill inotifyd
webhook="$(getAttr webhook)"
sms_enable="$(getAttr sms_enable)"
sms_format="$(getAttr sms_format)"
sms_db="$(getAttr sms_db)"
call_enable=$(getAttr call_enable)
call_format=$(getAttr call_format)
call_db="$(getAttr call_db)"

if [ -n $a ]; then
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
  init $call_enable $CALL_DB_PATH "SELECT _id FROM calls ORDER BY _id DESC LIMIT 1;" "last_call_id" "sendCall"
fi

listen

log "启动成功"