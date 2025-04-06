updateId() {
  echo $2 > "$MODDIR/$1"
  eval $1=$2
}
updateId $1 $2