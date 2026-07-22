#!/usr/bin/env bash

set -eu

command -v powerprofilesctl >/dev/null

if [[ "$(powerprofilesctl get)" == "power-saver" ]]; then
    # Not every device exposes a performance profile. Balanced is the
    # universally available fallback when leaving power-saver mode.
    powerprofilesctl set performance || powerprofilesctl set balanced
else
    powerprofilesctl set power-saver
fi
