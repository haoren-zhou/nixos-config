# Pi Coding Agent configuration

Home Manager installs Pi from `llm-agents.nix`, deploys `extensions/` and
`skills/` under `~/.config/pi/agent`, and sets `PI_CODING_AGENT_DIR` to that
location.

The JSON configs in this directory (`settings.json`, `zentui.json`,
`hermes-memory-config.json`, `pi-plan-mode.json`) are
bootstrapped on activation as real, user-editable files rather than read-only
store symlinks.

The versioned `packages` entries in `settings.json` declare Pi packages that
Pi installs into its per-user npm directory when missing. Nix provides
Node.js/npm for this operation. Because the versions are pinned, Pi's package
update commands do not advance them; update the versions in `settings.json`
instead. Pi invokes npm with lifecycle scripts disabled; review a package
before removing this restriction if it requires an install script.

Currently declared packages:

- `@narumitw/pi-btw`: context-aware side questions through `/btw`
- `pi-hermes-memory`: searchable long-term and project-scoped memory
- `pi-reasonix`: DeepSeek prefix caching, tool-call repair, and result compaction
- `pi-rewind-hook`: conversation and worktree checkpoint restoration
- `pi-web-access`: web search, URL/content fetching, and source checking
- `@gotgenes/pi-permission-system`: deterministic allow, ask, and deny gates
- `pi-subagents`: single-agent delegation and scripted multi-agent workflows
  (replaces `@gotgenes/pi-subagents`)
- `@juicesharp/rpiv-ask-user-question`: structured multi-question questionnaires
- `@juicesharp/rpiv-todo`: persistent live todo overlay and `/todos` command
- `pi-zentui`: OpenCode-inspired editor, messages, working line, and footer
- `@narumitw/pi-plan-mode`: Codex-like read-only `/plan` collaboration mode
- `@narumitw/pi-goal`: autonomous single-objective `/goal` completion
- `@narumitw/pi-usage`: account usage for Codex/Copilot/OpenRouter and `/fast`

`pi-subagent-permission-forwarding` keeps permission approvals from
`@gotgenes/pi-permission-system` attached to the interactive session that
launched a `pi-subagents` child (including nested and background children) via
the `PI_SUBAGENT_PI_BINARY` launcher wrapper.

The permission policy allows read-only tools, asks before file mutations, shell
commands, and access outside the working directory, and denies selected secret
paths plus `rm -rf` and `sudo`. Zentui owns the editor, user-message styling,
working line, and footer. The local permission-status extension keeps a colored
`🔒 permissions` badge visible in Zentui's footer even when yolo mode is off;
Zentui's built-in status integration otherwise receives no value from the
permission package outside yolo mode. The memory display extension adds a
TUI-only transcript card containing the exact memory content after successful
memory writes, without adding that display-only copy to the model context.

`/btw <question>` opens a temporary side thread using the current model and
conversation context. Its messages stay out of the main conversation unless
you explicitly bring selected context back with `Ctrl+R`. Running `/btw`
without a question opens its thread manager and settings. Side threads use
additional model tokens and are kept only for the current Pi process.

`pi-rewind-hook` adds file checkpoints to Pi's native conversation navigation:

- `/fork` can restore conversation and files, conversation only, or files only.
- `/tree` can keep the current files, restore files to the selected point, or
  undo the last file rewind.

It works only inside Git repositories. It snapshots tracked files and
untracked, non-ignored files, but not ignored files or empty directories. The
real Git branch and index are left unchanged. Snapshot objects are retained in
the repository-local `refs/pi-rewind/store` ref for at most 30 days or 500
snapshots; labeled points are exempt from pruning.

For a non-Nix installation, copy the managed resources to Pi's default global
configuration directory:

```sh
cp settings.json zentui.json hermes-memory-config.json ~/.pi/agent/
cp pi-plan-mode.json ~/.pi/agent/pi-plan-mode.json
cp -R extensions skills ~/.pi/agent/
```

The `context.ts` extension and the `stop-slop` skill were vendored from
[`amosblomqvist/pi-config`](https://github.com/amosblomqvist/pi-config) commit
`575a0a5261ada93cf09189ebd59a508040f866f9`. Their Pi package imports were
updated from the former `@mariozechner` namespace to `@earendil-works`.

Keep API keys and generated authentication files out of this directory. Use
Pi's `/login` command or provider environment variables on each machine.
Hermes memories and databases, sessions, package installations, permission
review logs, missions, trust decisions, model metadata, and other runtime state
also remain machine-local and are intentionally not managed by Home Manager.
