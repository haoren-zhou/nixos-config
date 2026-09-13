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
scratch=$(mktemp -d /tmp/pi-guard-test.XXXXXX)
mkdir -p "$scratch/agent/extensions/pi-permission-system" "$scratch/agent/npm" "$scratch/work"
ln -s "${PI_GUARD_TEST_NODE_MODULES:-${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}/npm/node_modules}" "$scratch/agent/npm/node_modules"
printf '%s\n' '{"yoloMode":false,"permission":{"*":"ask","read":"allow","bridge_allow":"allow","bridge_deny":"deny","path":{"*":"allow","*.env":"deny"},"bash":{"*":"ask","sudo *":"deny","true":"allow"}},"forwardingTimeoutMs":5000}' > "$scratch/agent/extensions/pi-permission-system/config.json"
printf '%s\n' '{"packages":[],"extensions":[],"enableInstallTelemetry":false,"defaultTools":["read","bash","powershell","edit","write"]}' > "$scratch/agent/settings.json"
printf 'Test directory: %s\n' "$scratch"
status=0
(cd "$scratch/work" && PI_OFFLINE=1 PI_CODING_AGENT_DIR="$scratch/agent" timeout 180s "${PI_GUARD_TEST_PI:-pi}" --no-extensions --no-skills --no-prompt-templates --no-context-files --no-session -e "$here/smoke.ts" -p /guard-smoke) > "$scratch/output.log" 2>&1 || status=$?
tail -70 "$scratch/output.log"
exit "$status"
