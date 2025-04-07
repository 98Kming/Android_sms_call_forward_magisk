#!/system/bin/sh
MODDIR=${0%/*}

$MODDIR/关闭转发.sh 1>/dev/null 2>>"$MODDIR/log.log"
log() {
  printf "%s\n" "$(date +%F_%T)_forward_$$: $1"
  printf "%s\n" "$(date +%F_%T)_forward_$$: $1" >> "$MODDIR/log.log"
}

getAttr() {
  local config_file="${MODDIR}/config.conf"
  local value=$(grep "^$1=" "$config_file" | cut -d '=' -f 2-)
  #echo "$value" | tr -d '"'
  printf "%s\n" "$value"
}


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
    local _id=$(eval echo "\$$1")
    local sql="SELECT _id, address, body, sub_id FROM sms WHERE _id > $_id ORDER BY _id  LIMIT 1;"
    local sms=$(exeSql $2 "$sql")
    if [ -z "$sms" ]; then
      break;
    fi
    id=$(echo "$sms" | awk -v RS='^$' -F'|' '{print $1}')
    send_number=$(echo "$sms" | awk -v RS='^$' -F'|' '{print $2}')
    body=$(echo "$sms" | awk -v RS='^$' -F'|' '{print $3}')
    sub_id=$(echo "$sms" | awk -v RS='^$' -F'|' '{print $4}')
    content="${sms_format//\{body\}/$body}"
    content="${content//\{send_number\}/$send_number}"
    content="${content//\{sub_id\}/$sub_id}"
    sendWebhook "$content"
    saveId "$1" $id
    sleep 2
  done
}

sendCall() {
  while true; do
    local _id=$(eval echo "\$$1")
    local sql="SELECT _id, phone_account_address, number FROM calls where type=3 and _id > $_id ORDER BY _id LIMIT 1;"
    local call=$(exeSql $2 "$sql")
    if [ -z "$call" ]; then
      break;
    fi
    id=$(echo "$call" | awk -v RS='^$' -F'|' '{print $1}')
    my_number=$(echo "$call" | awk -v RS='^$' -F'|' '{print $2}')
    call_number=$(echo "$call" | awk -v RS='^$' -F'|' '{print $}')
    content="${call_format//\{my_number\}/$my_number}"
    content="${content//\{call_number\}/$call_number}"
    content=$(echo "$content" | tr '\\\n' '\n')
    sendWebhook "$content"
    saveId "$1" $id
    sleep 2
  done
}

init() {
  if [[ $1 == 1 ]]; then
    waitLoadFile $2
    local id=$(exeSql $2 "$3")
    if [ ! -f "$MODDIR/$4" ] || [ -z $(head -n 1 $MODDIR/$4) ]; then
      log "$4:$id"
      saveId "$4" "$id"
    else
      local old_id=$(head -n 1 $MODDIR/$4)
      if [ $id -lt $old_id ]; then
        log  "$4:数据库值较小，同步为数据库值"
        saveId "$4" "$id"
      elif [ $id -gt $old_id ]; then
        eval $4=$old_id
        eval "$5 $4 $2"
      fi
    fi
  fi
}

isMod() {
  local val=$(eval "printf \"%s\" \"\$$1\"")
  local tmp="$(getAttr $1)"
  if [ "${val}x" = "${tmp}x" ]; then
    return 0
  else
    eval $1=$tmp
    log "检测到$1值被改变，旧值为$val，新值为$tmp"
    return 1
  fi
}

checkConfigMod() {
  local mod=0
  isMod "sms_enable"
  if [ $? == 1 ]; then
    mod=1
  fi
  isMod "sms_format"
  if [ $? == 1 ]; then
    mod=1
  fi
  isMod "sms_db"
  if [ $? == 1 ]; then
    chmod 666 "$sms_db"
    mod=1
  fi
  isMod "call_enable"
  if [ $? == 1 ]; then
    mod=1
  fi
  isMod "call_format"
  if [ $? == 1 ]; then
    mod=1
  fi
  isMod "call_db"
  if [ $? == 1 ]; then
    chmod 666 "$call_db"
    mod=1
  fi
  isMod "webhook"
  if [ $? == 1 ]; then
    mod=1
  fi
  return $mod
}

echo $$ >> $MODDIR/pid
log "启动转发"
if [ "$sms_enable" == 1 ];then
  init $sms_enable $sms_db "SELECT _id FROM sms ORDER BY _id DESC LIMIT 1;" "last_sms_id" "sendSms"
fi

if [ "$call_enable" == 1 ];then
  init $call_enable $call_db "SELECT _id FROM calls ORDER BY _id DESC LIMIT 1;" "last_call_id" "sendCall"
fi



inotifyd - "$sms_db:c" "$call_db:c" "$MODDIR:m" "$MODDIR/config.conf:w" | while read -r event; do
  # 监听目录时数组为(操作,路径,文件名) 监听文件时数组为(操作,路径+文件名)
  if [[ $(echo "$event" | awk -v RS='^$' -F'|' '{print $2}') == "$sms_db" && "$sms_enable" == 1  ]]; then
    # 短信数据库修改
    sendSms "last_sms_id" $sms_db
  fi
  if [[ $(echo "$event" | awk -v RS='^$' -F'|' '{print $2}') == "$call_db" && "$call_enable" == "1"  ]]; then
    # 电话数据库修改
    sendCall "last_call_id" $call_db
  fi
  if [ $(echo "$event" | awk -v RS='^$' -F' ' '{print $3}') == "config.conf" ] ||  [ "${arr[1]}" == "$MODDIR/config.conf" ]; then
    # 配置文件修改检查
    checkConfigMod
  fi
done