#!/usr/bin/env bash

case ${1:-drun} in
drun)
  override="entry{placeholder:'Search Applications...';}listview{lines:9;}"
  pkill -x rofi || rofi -show drun -theme-str "$override"
  ;;
window)
  override="entry{placeholder:'Search Windows...';}listview{lines:9;}"
  pkill -x rofi || rofi -show window -theme-str "$override"
  ;;
file)
  override="entry{placeholder:'Search Files...';}listview{lines:8;}"
  pkill -x rofi || rofi -show filebrowser -theme-str "$override"
  ;;
emoji)
  override="entry{placeholder:'Search Emojis...';}listview{lines:12;}"
  pkill -x rofi || rofi -modi emoji -show emoji -theme-str "$override"
  ;;
games)
  override="entry{placeholder:'Search Games...';}listview{lines:12;}"
  pkill -x rofi || rofi -modi games -show games -theme-str "$override"
  ;;
help | --help)
  echo "Usage: rofi.sh [ACTION]"
  echo "Launch various rofi modes."
  echo ""
  echo "Actions:"
  echo "  drun         Launch application search mode"
  echo "  window       Switch between open windows"
  echo "  file         Browse and search files"
  echo "  emoji        Search and insert emojis"
  echo "  games        Launch games menu"
  echo "  help         Display this help message"
  echo "  --help       Same as 'help'"
  echo ""
  echo "If no action is specified, defaults to 'drun' mode."
  exit 0
  ;;
*) exec "$0" drun ;;
esac
