#!/system/bin/sh
MODDIR=${0%/*}
log() {
 echo "$(date +%F_%T)_PID_$$ $1"
 echo "$(date +%F_%T)_PID_$$ $1" >> "$MODDIR/log.log"
}
"$MODDIR/关闭转发.sh"  > /dev/null 2>&1
if [ -f "$MODDIR/disable" ]; then
  log "模块已关闭，请开启"
  exit 0
fi

getAttr() {
  config_file="${MODDIR}/config.conf"
 value=$(grep "^$1=" "$config_file" | cut -d '=' -f 2-)
  echo "$value" | tr -d '"'
}

sms_enable=$(getAttr sms_enable)
sms_format=$(getAttr sms_format)
call_enable=$(getAttr call_enable)
call_format=$(getAttr call_format)
webhook=$(getAttr webhook)

if [[ "$sms_enable" != 1 && "$call_enable" != 1 ]]; then
  log "短信及未接来电转发已关闭，程序退出。请检查配置"
  exit 0
fi

waitLoadFile() {
 # 最大尝试次数
  local max_attempts=30
  local attempt=0
  until [ -f "$1" ] || [ $attempt == $max_attempts ]; do
    log "文件 $1 未找到，第 $((++attempt)) 次尝试，等待 10 秒后再次尝试"
    sleep 10

  done
  if [ -f "$1" ]; then
    log "文件 $1 已找到，开始执行后续操作"
  else
    log "达到最大尝试次数，文件 $1 未找到，程序退出"
    exit 0
  fi
}

SMS_DB_PATH="/data/data/com.android.providers.telephony/databases/mmssms.db"
CALL_DB_PATH="/data/data/com.android.providers.contacts/databases/calllog.db"

sendWebhook() {
  local data="{\"msgtype\":\"text\",\"text\":{\"content\":\"$1\"}}"
  #log "$data"
  curl "$webhook" -H 'Content-Type: application/json' -d "$data"
}

exeSql() {
 $MODDIR/bin/sqlite3 $1 "$2"
}

saveId() {
  echo $2 > "$MODDIR/$1"
  eval $1=$2
}

sendSms() {
  while true; do
    local sql="SELECT _id, address, body, sub_id FROM sms WHERE _id > $last_sms_id ORDER BY _id  LIMIT 1;"
    local sms=$(exeSql $SMS_DB_PATH "$sql")
    if [[ ! -n "$sms" ]]; then
      break;
    fi
    sms=$(echo "$sms" | tr '\n' '\\\n')
    id=$(echo "$sms" | awk -F'|' '{print $1}')
    send_number=$(echo "$sms" | awk -F'|' '{print $2}')
    body=$(echo "$sms" | awk -F'|' '{print $3}')
    sub_id=$(echo "$sms" | awk -F'|' '{print $4}')
    content=$(echo "$sms_format" | awk -v b="$body" -v s="$sub_id" -v n="$send_number" '{
        gsub(/{body}/, b);
        gsub(/{sub_id}/, s);
        gsub(/{send_number}/, n);
        print
    }')
    sendWebhook "$content"
    saveId "last_sms_id" $id
    sleep 2
  done
}

sendCall() {
  while true; do
    local sql="SELECT _id, phone_account_address, number FROM calls where type=3 and _id > $last_call_id ORDER BY _id LIMIT 1;"
    local call=$(exeSql $CALL_DB_PATH "$sql")
    if [[ ! -n "$call" ]]; then
      break;
    fi
    id=$(echo "$call" | awk -F'|' '{print $1}')
    my_number=$(echo "$call" | awk -F'|' '{print $2}')
    call_number=$(echo "$call" | awk -F'|' '{print $3}')
    content=$(echo "$call_format" | awk -v b="$my_number" -v s="$call_number" '{
        gsub(/{my_number}/, b);
        gsub(/{call_number}/, s);
        print
    }')
    sendWebhook "$content"
    saveId "last_call_id" $id
    sleep 2
  done
}

pid=$$
echo $pid >> $MODDIR/pid
log "start pid:$pid"

init() {
  if [[ $1 == 1 ]]; then
    waitLoadFile $2
    local id=$(exeSql $2 "$3")
    if [ ! -f "$MODDIR/$4" ] || [ ! -s "$MODDIR/$4" ]; then
      log "$4:$id"
      saveId "$4" "$id"
    else
      eval $4=$(head -n 1 $MODDIR/$4)
      if [ $id -lt $4 ]; then
        log  "$4:数据库值较小，同步为数据库值"
        saveId "$4" "$id"
      else
        eval $5
      fi
    fi
  fi
}
init $sms_enable $SMS_DB_PATH "SELECT _id FROM sms ORDER BY _id DESC LIMIT 1;" "last_sms_id" "sendSms"
init $call_enable $CALL_DB_PATH "SELECT _id FROM calls ORDER BY _id DESC LIMIT 1;" "last_call_id" "sendCall"

inotifyd - "$CALL_DB_PATH:c" "$SMS_DB_PATH:c" | while read -r event; do
  if [[ "$event" == *"$SMS_DB_PATH" && "$sms_enable" == "1"  ]]; then
    sendSms
  fi
  if [[ "$event" == *"$CALL_DB_PATH" && "$call_enable" == "1"  ]]; then
    sendCall
  fi
done
