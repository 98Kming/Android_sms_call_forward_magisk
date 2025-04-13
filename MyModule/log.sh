pid=$$
log_output() {
  #local result="[$$ $(date +"%Y-%m-%d %H:%M:%S")]"
  if [ $1 == '1' ]; then
    while IFS= read -r line; do
      echo "[$pid $(date +"%Y-%m-%d %H:%M:%S")] $line"
    done >> "$MODDIR/log.log"
  else
    while IFS= read -r line; do
      echo "[$pid $(date +"%Y-%m-%d %H:%M:%S")] $line"
    done | tee -a "$MODDIR/log.log"
  fi
}

logSh() {
  # ksu运行环境 /data/adb/ksu/bin/busybox sh -o standalone
  $1 2>&1 | log_output "$2"
}

logCmd() {
  eval $1 2>&1 | log_output
}

log() {
  echo "$1" 2>&1 | log_output
}
