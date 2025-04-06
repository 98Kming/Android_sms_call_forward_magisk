call() {
  while true; do
    local sql="SELECT _id, phone_account_address, number FROM calls where type=3 and _id > $last_call_id ORDER BY _id LIMIT 1;"
    local call=$(exeSql $CALL_DB_PATH "$sql")
    if [[ ! -n "$call" ]]; then
      break;
    fi
    call=$(echo "$call" | tr '\n' '\\\n')
    id=$(echo "$call" | awk -F'|' '{print $1}')
    my_number=$(echo "$call" | awk -F'|' '{print $2}')
    call_number=$(echo "$call" | awk -F'|' '{print $3}')
    content="${call_format//\{my_number\}/$my_number}"
    content="${content//\{call_number\}/$call_number}"
    content=$(echo "$content" | tr '\\\n' '\n')
    sendWebhook "$content"
    saveId "last_call_id" $id
    sleep 2
  done
}
call