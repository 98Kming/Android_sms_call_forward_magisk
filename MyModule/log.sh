
log_output() {
  local result="[$$ $(date +"%Y-%m-%d %H:%M:%S")]"
  while IFS= read -r line; do
    echo "$result $line"
    result=""
  done | tee -a $MODDIR/log.log
}

logSh() {
  /data/adb/ksu/bin/busybox sh -o standalone $1 2>&1 | log_output
}

logCmd() {
  eval $1 2>&1 | log_output
}

log() {
  echo "$1" | log_output
}
