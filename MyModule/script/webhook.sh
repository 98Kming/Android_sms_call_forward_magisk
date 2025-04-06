post(){
  local data="{\"msgtype\":\"text\",\"text\":{\"content\":\"$content\"}}"
    #log "$data"
  curl "$webhook" -H 'Content-Type: application/json' -d "$data"
}
post