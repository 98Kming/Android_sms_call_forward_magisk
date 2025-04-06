sms() {
  while true; do
    local sql="SELECT _id, address, body, sub_id FROM sms WHERE _id > $last_sms_id ORDER BY _id  LIMIT 1;"
    local sms=$(exeSql $SMS_DB_PATH "$sql")
    if [[ ! -n "$sms" ]]; then
      break;
    fi
    local sms=$(echo "$sms" | tr '\n' '\\\n')
    local id=$(echo "$sms" | awk -F'|' '{print $1}')
    local send_number=$(echo "$sms" | awk -F'|' '{print $2}')
    local body=$(echo "$sms" | awk -F'|' '{print $3}')
    local sub_id=$(echo "$sms" | awk -F'|' '{print $4}')
    local content="${sms_format//\{body\}/$body}"
    local content="${content//\{send_number\}/$send_number}"
    local content="${content//\{sub_id\}/$sub_id}"
    local content=$(echo "$content" | tr '\\\n' '\n')
    . ./webhook.sh "$content"
    saveId "last_sms_id" $id
    sleep 2
  done
}
sms