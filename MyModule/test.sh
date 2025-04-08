#!/system/bin/sh
MODDIR=${0%/*}

. $MODDIR/config.ini

if [ -z $webhook ]; then
  echo "webhook 未配置，请到 config.conf 中配置webhook地址"
  exit 0
fi

if [ "$sms_enable" != 1 -a "$call_enable" != 1 ]; then
  echo "短信及未接来电转发功能全部关闭，程序退出。请检查配置"
  exit 0
fi

echo $$ >> $MODDIR/pid
echo "启动转发"

waitLoadFile() {
 # 最大尝试次数
  local max_attempts=30
  local attempt=0
  until [ -f "$1" ] || [ $attempt == $max_attempts ]; do
    echo "文件 $1 未找到，第 $((++attempt)) 次尝试，等待 10 秒后再次尝试"
    sleep 10
  done
  if [ -f "$1" ]; then
    echo "文件 $1 已找到，开始执行后续操作"
  else
    echo "达到最大尝试次数，文件 $1 未找到，程序退出"
    exit 0
  fi
}

sendWebhook() {
  local data="{\"msgtype\":\"text\",\"text\":{\"content\":\"$1\"}}"
  #log "$data"
  curl -q "$webhook" -H 'Content-Type: application/json' -d "$data"
}

exeSql() {
 $MODDIR/bin/sqlite3 $1 "$2"
 echo "$?"
     
}

saveId() {
  echo $2 > "$MODDIR/$1"
  eval $1=$2
}

sendSms() {
  #while true; do
    local sql="SELECT _id, address, sub_id FROM sms WHERE _id > $last_sms_id ORDER BY _id  LIMIT 1;"
    local sms=$(exeSql $sms_db "$sql")
    if [ -z "$sms" ]; then
      break;
    fi
    id=$(echo "$sms" | cut -d'|' -f1)
    send_number=$(echo "$sms" | cut -d'|' -f2)
    sub_id=$(echo "$sms" | cut -d'|' -f3)
    sql="SELECT body FROM sms WHERE _id = $id ORDER BY _id LIMIT 1;"
    body=$(exeSql $sms_db "$sql")
    echo "$body"
    content="${sms_format//\{body\}/$body}"
    content="${content//\{send_number\}/$send_number}"
    content="${content//\{sub_id\}/$sub_id}"
    sendWebhook "$content"
    saveId "last_sms_id" $id
    sleep 60
  #done
}

sendCall() {
  #while true; do
    local sql="SELECT _id, phone_account_address, number FROM calls where type=3 and _id > $last_call_id ORDER BY _id LIMIT 1;"
    local call=$(exeSql $call_db "$sql")
    if [ -z "$call" ]; then
      break;
    fi
    id=$(echo "$call" | cut -d'|' -f1)
    my_number=$(echo "$call" | cut -d'|' -f2)
    call_number=$(echo "$call" | cut -d'|' -f3)
    content="${call_format//\{my_number\}/$my_number}"
    content="${content//\{call_number\}/$call_number}"
    #content=$(echo "$content" | tr '\\\n' '\n')
    sendWebhook "$content"
    saveId "last_call_id" $id
    sleep 2
  #done
}

init() {
  waitLoadFile $2
  local id=$(exeSql $2 "$3")
  if [ ! -f "$MODDIR/$4" ] || [ -z $(head -n 1 $MODDIR/$4) ]; then
    echo "$4:$id"
    saveId "$4" "$id"
  else
    local old_id=$(head -n 1 $MODDIR/$4)
    if [ $id -lt $old_id ]; then
      echo  "$4:数据库值较小，同步为数据库值"
      saveId "$4" "$id"
    elif [ $id -gt $old_id ]; then
      eval $4=$old_id
      eval "$5 $4 $2"
    fi
  fi

}

if [ "$sms_enable" == 1 ];then
  init $sms_enable $sms_db "SELECT _id FROM sms ORDER BY _id DESC LIMIT 1;" "last_sms_id" "sendSms"
fi

if [ "$call_enable" == 1 ];then
  init $call_enable $call_db "SELECT _id FROM calls ORDER BY _id DESC LIMIT 1;" "last_call_id" "sendCall"
fi

listen() {
  inotifyd - "$sms_db:cw" "$call_db:c" "$MODDIR:m" "$MODDIR/config.ini:w" | while read -r event; do
    # 监听目录时数组为(操作,路径,文件名) 监听文件时数组为(操作,路径+文件名)
    echo $event
    local arg1=$(echo "$event" | cut -d"	" -f1)
    echo "参数[$arg1]"
    arg1=$(echo "$event" | cut -d"	" -f1)
    echo "参数[$arg1]"
    local arg2=$(echo "$event" | cut -d'	' -f2)
    echo "[$arg2]"
    local arg3=$(echo "$event" | cut -d'	' -f3)
    if [[ "$arg2" == "$sms_db" && "$sms_enable" == 1  ]]; then
      # 短信数据库修改
      sendSms
    fi
    if [[ "$arg2" == "$call_db" && "$call_enable" == "1"  ]]; then
      # 电话数据库修改
      sendCall "last_call_id"
    fi
    if [ "$arg3" == "config.conf" ] || [ "$arg2" == "$MODDIR/config.conf" ]; then
      echo "检测到配置修改"
      . $MODDIR/config.ini
      chmod 666 $sms_db
      chmod 666 $call_db
    fi
  done
  }
listen