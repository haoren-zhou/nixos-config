#!/usr/bin/env bash

# Directory for icons
iDIR="$HOME/.config/hypr/icons"

declare -A no_shuffle=(
)

declare -A shuffle=(
  ["Pop 📻🎶"]="https://youtube.com/playlist?list=PLMC9KNkIncKtPzgY-5rmhvj7fax8fdxoj"
  ["Dance 📻🎶"]="https://dancewave.online:443/dance.mp3"
  ["Lofi Radio ☕️🎶"]="https://play.streamafrica.net/lofiradio"
  ["Rock 📻🎶"]="https://www.youtube.com/playlist?list=PL6Lt9p1lIRZ311J9ZHuzkR5A3xesae2pk"
  ["Ghibli Music 🎻🎶"]="https://youtube.com/playlist?list=PLNi74S754EXbrzw-IzVhpeAaMISNrzfUy&si=rqnXCZU5xoFhxfOl"
  ["Top Youtube Music 2023 ☕️🎶"]="https://youtube.com/playlist?list=PLDIoUOhQQPlXr63I_vwF9GD8sAKh77dWU&si=y7qNeEVFNgA-XxKy"
  ["Chillhop ☕️🎶"]="https://stream.zeno.fm/fyn8eh3h5f8uv"
  ["Youtube Remix 📻🎶"]="https://youtube.com/playlist?list=PLeqTkIUlrZXlSNn3tcXAa-zbo95j0iN-0"
)

# Combine into menu_options array
declare -A menu_options
for key in "${!no_shuffle[@]}"; do menu_options["$key"]="${no_shuffle[$key]}"; done
for key in "${!shuffle[@]}"; do menu_options["$key"]="${shuffle[$key]}"; done

# Function for displaying notifications
notification() {
  # Default icon
  local icon="$iDIR/music.png"

  # Option 1: Try to get album art (if ytdl-hook plugin is enabled in mpv)
  # if [ -S "$MPV_SOCKET" ] && [[ "$2" == *"playlist"* ]]; then
  #   thumbnail_url=$(echo '{"command": ["get_property", "metadata/by-key/thumbnail"]}' | socat - "$MPV_SOCKET" 2>/dev/null | jq -r '.data // empty')
  #   if [ -n "$thumbnail_url" ] && [ "$thumbnail_url" != "null" ]; then
  #     # Download thumbnail to temp file and use it
  #     temp_thumb="${XDG_RUNTIME_DIR:-/tmp}/mpv_thumb.jpg"
  #     curl -s "$thumbnail_url" -o "$temp_thumb"
  #     icon="$temp_thumb"
  #   fi
  # fi

  notify-send -e -t 2500 -u normal -i "$iDIR/music.png" "Playing now: $1"
}

# Main function
main() {
  # TODO: increase this value if adding more playlists
  r_override="entry{placeholder:'Search Music...';}listview{lines:4;}"
  choice=$(printf "%s\n" "${!menu_options[@]}" | rofi -dmenu -theme-str "$r_override" -i -p "")

  if [ -z "$choice" ]; then
    exit 1
  fi

  link="${menu_options[$choice]}"

  notification "$choice"

  # Check if the link is a playlist and handle shuffling
  if [[ $link == *playlist* ]]; then
    if [[ -v no_shuffle["$choice"] ]]; then
      mpv --vid=no "$link"
    else
      mpv --vid=no --shuffle "$link"
    fi
  else
    # Non-playlist links (e.g., radio streams) play without shuffle
    mpv "$link"
  fi
}

# Check if an online music process is running and send a notification, otherwise run the main function
pkill mpv && notify-send -e -t 2500 -u low -i "$iDIR/music.png" "Playback stopped" || main
