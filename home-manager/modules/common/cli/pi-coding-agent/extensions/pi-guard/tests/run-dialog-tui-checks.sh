#!/usr/bin/env bash
set -euo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$here/isolated-env.sh"
scratch=$(mktemp -d /tmp/pi-guard-dialog-tui.XXXXXX)
mkdir -p "$scratch/agent/npm" "$scratch/work"
ln -s "${PI_GUARD_TEST_NODE_MODULES:-${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}/npm/node_modules}" "$scratch/agent/npm/node_modules"
printf '%s\n' '{"packages":[],"extensions":[],"enableInstallTelemetry":false}' > "$scratch/agent/settings.json"
export PI_OFFLINE=1 PI_CODING_AGENT_DIR="$scratch/agent" PI_GUARD_DIALOG_RESULT="$scratch/result.json"
export PI_GUARD_DIALOG_EXTENSION="$here/dialog-tui-checks.ts" PI_GUARD_DIALOG_PI="${PI_GUARD_TEST_PI:-pi}"
printf 'TUI regression directory: %s\n' "$scratch"
status=0
(cd "$scratch/work" && timeout 45s script -qefc 'stty cols 120 rows 40; "$PI_GUARD_DIALOG_PI" --no-extensions --no-skills --no-prompt-templates --no-context-files --no-session -e "$PI_GUARD_DIALOG_EXTENSION" /guard-dialog-tui-test' "$scratch/terminal.log" < /dev/null) > "$scratch/output.log" 2>&1 || status=$?
node --input-type=module -e 'import fs from "node:fs"; const r=JSON.parse(fs.readFileSync(process.env.PI_GUARD_DIALOG_RESULT,"utf8")); console.log(JSON.stringify(r,null,2)); if(!r.passed)process.exit(1);'
if [[ $status -ne 0 ]]; then printf 'Interactive Pi exited %s\n' "$status" >&2; exit "$status"; fi
