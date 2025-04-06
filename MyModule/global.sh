#!/system/bin/sh

log() {
  printf "%s\n" "$(date +%F_%T)_PID_$$: $1"
  printf "%s\n" "$(date +%F_%T)_PID_$$: $1" >> "$MODDIR/log.log"
}

getAttr() {
  local config_file="${MODDIR}/config.conf"
  local value=$(grep "^$1=" "$config_file" | cut -d '=' -f 2-)
  #echo "$value" | tr -d '"'
  printf "%s\n" "$value"
}

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
    if [[ ! -n "$sms" ]]; then
      break;
    fi
    IFS='|'
    arr=($sms)
    unset IFS
    id="${arr[0]}"
    send_number="${arr[1]}"
    body="${arr[2]}"
    sub_id="${arr[3]}"
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
    if [[ ! -n "$call" ]]; then
      break;
    fi
    IFS='|'
    arr=($call)
    unset IFS
    id="${arr[0]}"
    my_number="${arr[1]}"
    call_number="${arr[2]}"
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
    if [ ! -f "$MODDIR/$4" ] || [ ! -s "$MODDIR/$4" ]; then
      log "$4:$id"
      saveId "$4" "$id"
    else
      local old_id=$(head -n 1 $MODDIR/$4)
      if [ $id -lt old_id ]; then
        log  "$4:数据库值较小，同步为数据库值"
        saveId "$4" "$id"
      elif [ $id -gt old_id ]; then
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

