#!/system/bin/sh
MODDIR=${0%/*}
sms_enable=1
sms_db=""
sms_format=""
call_enable=1
call_db=""
call_format=""

webhook=""
. "$MODDIR/config.ini"

sms_init_sql="SELECT _id FROM sms ORDER BY _id DESC LIMIT 1;"
call_init_sql="SELECT _id FROM calls ORDER BY _id DESC LIMIT 1;"
. "$MODDIR/global.sh"
echo $$ >> "$MODDIR/pid"
echo "程序运行中..."
loadId "last_sms_id" "$sms_db" "$sms_init_sql"
loadId "last_call_id" "$call_db" "$call_init_sql"

sendSms() {
  if [ "$sms_enable" -ne 1 ];then
    return 0;
  fi
  while true; do
    if [ -z "$last_sms_id" ]; then
      loadId "last_sms_id" "$sms_db" "$sms_init_sql" || {
        echo "数据库查询失败"
        break
      }
    fi
    local sql="SELECT _id, address, sub_id FROM sms WHERE _id > $last_sms_id ORDER BY _id  LIMIT 1;"
    local sms
    sms=$(sqlite3 "$sms_db" "$sql")
    if [ -z "$sms" ]; then
      break
    fi
    id=$(echo "$sms" | cut -d'|' -f1)
    send_number=$(echo "$sms" | cut -d'|' -f2)
    sub_id=$(echo "$sms" | cut -d'|' -f3)
    sql="SELECT body FROM sms WHERE _id = $id ORDER BY _id LIMIT 1;"
    body=$(sqlite3 "$sms_db" "$sql")
    content="${sms_format//\{body\}/$body}"
    content="${content//\{send_number\}/$send_number}"
    content="${content//\{sub_id\}/$sub_id}"
    sendWebhook "$webhook" "$content"
    saveId "last_sms_id" "$id"
    sleep 2
  done
}

sendCall() {
  if [ "$call_enable" -ne 1 ];then
      return 0;
  fi
  while true; do
    if [ -z "$last_call_id" ]; then
      loadId "last_call_id" "$call_db" "$call_init_sql" || {
        echo "数据库查询失败"
        break
      }
    fi
    local sql="SELECT _id, phone_account_address, number FROM calls where type=3 and _id > $last_call_id ORDER BY _id LIMIT 1;"
    local call
    call=$(sqlite3 "$call_db" "$sql")
    if [ -z "$call" ]; then
      break
    fi
    id=$(echo "$call" | cut -d'|' -f1)
    my_number=$(echo "$call" | cut -d'|' -f2)
    call_number=$(echo "$call" | cut -d'|' -f3)
    content="${call_format//\{my_number\}/$my_number}"
    content="${content//\{call_number\}/$call_number}"
    sendWebhook "$webhook" "$content"
    saveId "last_call_id" "$id"
    sleep 2
  done
}

check() {
  if [ "$sms_enable" -ne 1 ] && [ "$call_enable" -ne 1 ]; then
    echo "短信及未接来电转发功能全部关闭，请检查配置"
  elif [ -z "$webhook" ]; then
    echo "webhook 未配置，请到 config.conf 中配置webhook地址"
  else
    sendSms
    sendCall
  fi
}
check

# 监听目录时数组为(操作,路径,文件名) 监听文件时数组为(操作,路径+文件名)
inotifyd - "$sms_db:c" "$call_db:c" "$MODDIR:m" "$MODDIR/config.ini:w" | while read -r event; do
  arg2=$(echo "$event" | cut -f2)
  arg3=$(echo "$event" | cut -f3)
  if [ "$arg2" = "$sms_db" ] && [ "$sms_enable" -eq 1 ]; then
    # 短信数据库修改
    sendSms
  elif [ "$arg2" = "$call_db" ] && [ "$call_enable" -eq 1 ]; then
    # 电话数据库修改
    sendCall
  elif [ "$arg3" = "config.ini" ] || [ "$arg2" = "$MODDIR/config.ini" ]; then
    echo "检测到配置修改"
    . "$MODDIR"/config.ini
    chmod 666 "$sms_db"
    chmod 666 "$call_db"
    sendSms
    sendCall
  fi
done
