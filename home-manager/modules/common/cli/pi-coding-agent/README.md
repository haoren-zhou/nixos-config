# Pi Coding Agent configuration

Home Manager installs Pi from `llm-agents.nix`, deploys this directory's
`settings.json`, `extensions/`, and `skills/` under `~/.config/pi/agent`, and
sets `PI_CODING_AGENT_DIR` to that location.

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
- `@gotgenes/pi-subagents`: foreground and background child-agent delegation
- `@gotgenes/pi-permission-system`: deterministic allow, ask, and deny gates

The permission policy allows read-only tools, asks before file mutations, shell
commands, and access outside the working directory, and denies selected secret
paths plus `rm -rf` and `sudo`. The custom footer shows the working directory,
Git branch, model and full thinking level, context use, cumulative input/output
tokens, latest cache-hit rate, and permission mode. It wraps at segment
boundaries when the terminal is too narrow.

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

For a non-Nix installation, copy those three resources to Pi's default global
configuration directory:

```sh
cp settings.json ~/.pi/agent/settings.json
cp -R extensions skills ~/.pi/agent/
```

The `ask-user-question.ts` and `context.ts` extensions and the `stop-slop`
skill were vendored from
[`amosblomqvist/pi-config`](https://github.com/amosblomqvist/pi-config) commit
`575a0a5261ada93cf09189ebd59a508040f866f9`. Their Pi package imports were
updated from the former `@mariozechner` namespace to `@earendil-works`.

Keep API keys and generated authentication files out of this directory. Use
Pi's `/login` command or provider environment variables on each machine.
Hermes memories and databases, sessions, package installations, permission
review logs, missions, trust decisions, model metadata, and other runtime state
also remain machine-local and are intentionally not managed by Home Manager.
