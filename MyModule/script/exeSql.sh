exeSql() {
  $MODDIR/bin/sqlite3 $1 "$2"
}
exeSql $1 "$2"