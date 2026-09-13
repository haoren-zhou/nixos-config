#!/usr/bin/env bash
set -euo pipefail
if [[ -z ${PI_GUARD_TEST_ORDER:-} ]]; then
  PI_GUARD_TEST_ORDER=permissions-first bash "$0"
  PI_GUARD_TEST_ORDER=guard-first bash "$0"
  exit 0
fi
case "$PI_GUARD_TEST_ORDER" in
  permissions-first|guard-first) ;;
  *) printf 'Unknown test order: %s\n' "$PI_GUARD_TEST_ORDER" >&2; exit 2 ;;
esac
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$here/isolated-env.sh"
scratch=$(mktemp -d /tmp/pi-guard-loader-test.XXXXXX)
mkdir -p "$scratch/agent/extensions/pi-permission-system" "$scratch/agent/npm" "$scratch/work"
ln -s "${PI_GUARD_TEST_NODE_MODULES:-${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}/npm/node_modules}" "$scratch/agent/npm/node_modules"
yolo=${PI_GUARD_TEST_YOLO:-false}
case "$yolo" in true|false) ;; *) printf 'Invalid YOLO test mode: %s\n' "$yolo" >&2; exit 2 ;; esac
printf '{"yoloMode":%s,"permission":{"*":"ask","read":"allow","path":{"*":"allow"},"bash":{"*":"ask","sudo *":"deny"}},"forwardingTimeoutMs":5000}\n' "$yolo" > "$scratch/agent/extensions/pi-permission-system/config.json"
printf '%s\n' '{"packages":[],"extensions":[],"enableInstallTelemetry":false}' > "$scratch/agent/settings.json"
printf 'Loader test directory: %s\n' "$scratch"
status=0
(cd "$scratch/work" && PI_OFFLINE=1 PI_CODING_AGENT_DIR="$scratch/agent" timeout 180s "${PI_GUARD_TEST_PI:-pi}" --no-extensions --no-skills --no-prompt-templates --no-context-files --no-session -e "$here/loader-checks.ts" -p /guard-loader-test) > "$scratch/output.log" 2>&1 || status=$?
tail -60 "$scratch/output.log"
exit "$status"
