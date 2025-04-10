#!/system/bin/sh
PATH=$PATH:$MODDIR/bin
waitLoadFile() {
 # 最大尝试次数
  local max_attempts=30
  local attempt=0
  until [ -f "$1" ] || [ $attempt = $max_attempts ]; do
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

saveId() {
  echo "$2" > "$MODDIR/$1"
  eval "$1=$2"
}

sendWebhook() {
  local data='{"msgtype":"text","text":{"content":"'"$2"'"}}'
  local resp
  resp=$( curl -s "$1" -H 'Content-Type: application/json' -d "$data")
  if [ $? -eq 0 ]; then
    local msg
    msg=$(echo "$resp" | jq -r '.errmsg')
    if [ "$msg" = "ok" ]; then
      return 0
    else
      echo "消息发送失败，错误信息：$msg"
      return 1
    fi
  fi
  echo "curl 命令执行失败，请检查网络连接或代理设置"
  return 1
}

# 参数：$1数据库文件路径，$2数据库查询语句，$3保存id的文件名，$4执行通知函数名
loadId() {
  local id_file="$1"
  local db_path="$2"
  local sql="$3"
  waitLoadFile "$db_path"
  # 读取数据库最新id
  id=$(sqlite3 "$db_path" "$sql") || {
    echo "数据库查询失败"
    return 1
  }

  echo "数据库最大值：$id"
  # 找到id文件
  if [ -f "$MODDIR"/"$id_file" ]; then
    # 读取id文件中的值
    local old_id
    old_id=$(head -n 1 "$MODDIR"/"$id_file")
    if [ "$old_id" -eq "$old_id" ] 2>/dev/null && [ "$old_id" -lt "$id" ]; then
      # id文件中的值小于数据库值，说明有新短信，执行通知
      id=$old_id
    fi
  fi
  # [找不到id文件]||[id文件中的值不是数字]||[id文件中的值大于数据库值，说明数据异常]||[id文件中的值等于数据库值，没有新短信]
  # 同步为数据库值，不执行通知
  saveId "$id_file" "$id"
}