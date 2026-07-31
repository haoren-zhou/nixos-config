#!/usr/bin/env bash

set -eu

command -v wf-recorder >/dev/null

output_dir="${XDG_VIDEOS_DIR:-$HOME/Videos}"
state_file="${XDG_RUNTIME_DIR:-/tmp}/screenrecord.path"

if pgrep -x wf-recorder >/dev/null; then
    # wf-recorder only finalises the container on SIGINT; SIGTERM truncates it.
    pkill -INT -x wf-recorder

    # Writing the trailer takes a moment, so the file is not complete the
    # instant the signal lands. Wait for the process to actually exit.
    for _ in {1..50}; do
        pgrep -x wf-recorder >/dev/null || break
        sleep 0.2
    done

    recording=$(cat "$state_file" 2>/dev/null || true)
    rm -f "$state_file"

    if [[ -s "${recording:-}" ]]; then
        notify-send -a "Screen recorder" "Recording saved" "$(basename "$recording")"
    else
        notify-send -a "Screen recorder" -u critical \
            "Recording failed" "See /tmp/wf-recorder.log"
    fi
    exit 0
fi

mkdir -p "$output_dir"
recording="$output_dir/rec-$(date +%Y%m%d-%H%M%S).mp4"
printf '%s' "$recording" >"$state_file"

# setsid detaches the recorder into its own session so it survives the
# caller's process group being torn down.
setsid -f wf-recorder -a -f "$recording" >/tmp/wf-recorder.log 2>&1
