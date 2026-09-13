# Pi Guard

Approval-forwarding bridge between pi-permission-system and Nico's native Pi subagents. It preserves stock tool selection, extension discovery, foreground/background execution, resumed sessions, and authorized nesting. The serving parent evaluates permission gates: ordinary allows and denials remain automatic; asks reach its human UI. The parent's current Guard/YOLO mode is authoritative, not a child's cached mode. Upstream packages and live policy stay unchanged.

## Requirements and installation

Install `pi-subagents` and `@gotgenes/pi-permission-system` through Pi. Put this directory under `<agentDir>/extensions/pi-guard/`. Pi's default agent directory is `~/.pi/agent`; this repository sets `PI_CODING_AGENT_DIR` to `~/.config/pi/agent`.

Keep permission-system enabled. Disable the **standalone** Nico extension entrypoint in your agent settings, retaining its other package resources. For example, with the repository's current pin:

```json
{ "source": "npm:pi-subagents@0.74.0", "extensions": [] }
```

Do not also load Nico's entrypoint through project settings or `-e`. Pi Guard loads it through `index.ts` and rejects conflicting tool/command ownership.

There are no Pi or plugin version allowlists. The current regression suite passes on Linux Pi 0.99.2 with pi-subagents 0.74.0 and permission-system 36.2.1. Earlier adapter revisions were tested on Pi 0.84.2 and 0.85.1 with pi-subagents 0.67.0 and permission-system 32.0.2; those are historical results, not validation of the current suite. These combinations are not runtime requirements. Changes to upstream internal APIs can still require adapter updates; run the tests after upgrades. Linux is required because process-identity checks use `/proc/<pid>/stat`.

`dependencies.ts` locates installed plugins under `<getAgentDir()>/npm/node_modules/`. It follows the package's runtime export layout to resolve source `.ts` or compiled `.js` files consistently, then canonicalizes the complete entry file. It never falls back to a different layout for an individual missing file. Call-site dynamic imports use Pi's existing loader graph, including when the source lives behind Home Manager symlinks. You do not need a `node_modules` directory beside Guard. Missing modules fail to load; child-session creation also checks permission activation before returning a usable handle.

Home Manager installs ordinary source-file symlinks. It only seeds settings and permission policy when absent, so merge the package filter into an existing installation yourself. It must not overwrite mutable permission rules. Generated lease files belong under `<agentDir>/pi-guard/`, outside the extension source.

Quit and restart Pi after installation. Guard applies automatically whenever the interactive root launches a supported native agent.

### Migrating from earlier adapters

Quit Pi and finish its children first. Back up unmanaged extension files outside extension discovery before activating Home Manager; do not force-overwrite them. Home Manager removes the managed `pi-subagent-permission-forwarding` bridge and the later `pi-guard-prototype`, then installs `extensions/pi-guard/`. Include new source files in Git before a normal Git-flake rebuild.

Confirm that neither old directory has an entrypoint and restart Pi. The earlier `PI_SUBAGENT_PI_BINARY` launcher and `/guard-prototype` command are no longer used. Retained factory registrations require a full restart, not `/reload`. Guard does not reuse old `<agentDir>/guard-prototype/` state; archive it only after the old processes exit.

## Usage and boundaries

Use ordinary agent names and tool names. Nico owns tool allowlists/defaults, exclusions, extension loading, execution-mode defaults, resume, fanout authorization, depth limits, and budgets. Nesting follows stock `tools: subagent` or `allowNestedSubagents: true` rules; Guard adds no tool-inventory requirement.

Keep the interactive root running. Root shutdown or generation replacement revokes child authority; resume creates a fresh binding rather than reviving old approval state. Checks run at permission middleware boundaries, not inside replacement tool implementations. Revocation cannot undo effects from an approved or running operation.

- Native tool allowlists, read-only roles, supervisor tools, SDK settings, trust decisions and capability ceilings remain in effect. Omitting `tools` keeps stock defaults; Guard does not wrap, rename, add or remove SDK tools.
- Foreground children do not load ambient parent extensions in stock Nico. Configure `extensions` or `subagentOnlyExtensions` for extension tools. Background children retain normal ambient discovery unless their agent/ceiling restricts it. Merely naming a tool does not load its provider.
- For example, `memory_search` works when Hermes is loaded and the tool is permitted by the agent's selection. It is not automatically added to bundled agents' allowlists. Any permission-system tool-surface filtering is ordinary policy behavior, not a Guard-only inventory.
- Guard reuses a discovered permission-system instance or installs one native-hook fallback when absent. It never layers duplicate permission gates. `denyExtensions` retains Nico's provider restrictions; the trusted native bridge still enforces permissions.
- PowerShell, custom tools, MCP tools and SDK-nested `ctx.executeTool` calls use the same permission engine as the main agent. Guard adds no language parser or blanket safety guarantee beyond that engine.
- External CLI/job internals, trusted extension code and direct host-process I/O outside Pi's tool middleware are outside this bridge, as they are outside main-agent tool permissions. This is not an OS sandbox or protection against malicious same-user code.
- Nico's tool/provider discovery and metadata stay unchanged; Guard adds only its native permission integration.
- A headless parent can resolve recorded allows/denials and YOLO without a UI. Its normal headless authorizer denies an ask when no human confirmation is available; Guard does not fabricate approval.
- Existing jobs do not gain protection when you install Guard.

## Implementation

- `index.ts` loads Nico and Guard in one Pi module graph. Separate entrypoints would wrap a different factory instance. It verifies dispatcher provenance for model tools, direct API calls, and slash commands.
- `guard-root.ts` owns parent readiness and authority generations. It waits for the keyed permission-service publication, serializes root approval dialogs, and installs a deny-all capability ceiling if another dispatcher owns the session. For a headless parent, it enables recorded-policy inbox serving without changing the normal authorizer.
- `child-session-guard.ts` wraps the native child-session factory. `runner.ts` installs the same wrapper in detached processes and their descendants. Loader-graph-specific ownership permits reloads without unguarding retained graphs. The factory checks child permission activation before exposing a handle.
- `child-resources.ts` uses the stock SDK resource loader. After discovery it adapts the one permission instance (or installs a fallback), leaving tool definitions, providers, paths and other extension order untouched. Child authority starts before permission publication; Nico's prompt runtime retains priority.
- `native-child.ts` binds child lifecycle and permission handlers. Local children use the keyed parent registry; detached children use filesystem approval forwarding. A permission-only headless relay context serves nested requests and denies local-dialog fallbacks. Other extensions retain the real headless context. Authority is rechecked after approval.
- `bridge-gates.ts` reuses upstream gate producers, normalization, deny-first ordering, extractors, previews and authorizers. It delegates gate decisions to the serving parent, retaining genuine human session grants. Intermediate inboxes also relay, preventing cached local YOLO from approving grandchildren. Read-only service queries retain upstream semantics. This private composition seam is capability-checked; incompatible package changes fail activation.
- `leases.ts` verifies session generations, process start times, ancestor chains, and serving status. Private directories, no-follow reads, exclusive creation, and generation-specific cleanup prevent a resumed session from evicting a live owner.
- `nested-lifetime.ts` registers owned nested runs with Nico's background-work provider so its drain waits for descendants. It releases terminal runs only after observed process exit, including failed/cancelled runs; Nico owns task outcomes and retries.
- `nico-contracts.ts` contains the narrow structural types for Nico's private factory seam. `permission-api.ts` isolates the event-overload casts required by the upstream permission adapter. `cleanup.ts` ensures one cleanup failure cannot skip later revocation steps.

`dialog-queue.ts` serializes inline `custom`, `select`, `confirm`, `input`, and `editor` calls on Pi's shared root UI. Otherwise, a local approval can replace a background approval without settling its promise. Shutdown rejects pending requests, dismisses active custom/abortable dialogs, and leaves captured methods closed. New root startup can rebind a reused UI object. Leases, rather than UI-object identity, enforce authority.

Overlays retain their own stack and can open inline subdialogs. Built-in menus and direct `setEditorComponent` calls bypass this queue; avoid them while answering permissions. Recursively awaiting a second inline dialog from the first is unsupported. Pi owns teardown of its multiline editor. RPC and headless relays do not use the TUI queue.

## Validation

Run from the source directory with the plugins installed through Pi:

```sh
node tests/package-checks.mjs
bash tests/run-dialog-tui-checks.sh
PI_GUARD_TEST_LINKS=true PI_GUARD_TEST_UI=tui bash tests/run-loader-checks.sh
PI_GUARD_TEST_LINKS=true PI_GUARD_TEST_YOLO=true bash tests/run-loader-checks.sh
bash tests/run-smoke.sh
```

For Home Manager validation, build the activation package and run those scripts through its actual links:

```sh
generation=$(nix build --no-link --print-out-paths \
  'path:.#homeConfigurations."hr@kilat".activationPackage')
tests="$generation/home-files/.config/pi/agent/extensions/pi-guard/tests"
PI_GUARD_TEST_UI=tui bash "$tests/run-loader-checks.sh"
```

The runners create disposable policy, state and npm fixtures; they do not alter live credentials or policy. A loopback SSE provider drives real model/tool round trips. Both startup orders run by default. Set `PI_GUARD_TEST_PI` for another executable or `PI_GUARD_TEST_NODE_MODULES` for another installed plugin tree.

Additional loader cases:

- `PI_GUARD_TEST_MISSING_DEPENDENCY=pi-subagents`: absent plugin, no dispatcher or model requests.
- `PI_GUARD_TEST_BROKEN_DEPENDENCY=pi-subagents`: installed manifest but missing implementation, same fail-closed result.
- Repeat those cases with `@gotgenes/pi-permission-system`.
- `PI_GUARD_TEST_ALTERNATE_VERSIONS=true`: change fixture plugin manifests to version `999.0.0` while retaining their implementation; the full suite must still pass. This proves metadata does not gate compatibility, not that unknown releases work.
- `PI_GUARD_LOADER_MODE=separate`: duplicate-entrypoint rejection when Guard loads first.
- `PI_GUARD_LOADER_MODE=nico-first`: the same rejection with standalone Nico loaded first, including direct tool invocation.

The real-loader suite covers foreground/background direct and file-backed workflow calls, resume history, all four nesting combinations, nested denial, reload, new/switch/fork/import session replacement, overlapping local/forwarded approval, and retained-factory rejection. Replacement tests reject direct calls through the old root's dispatcher and verify policy denial and approval forwarding through the fresh root. It complements the shared-import smoke suite's stock default/explicit role inventories, requested PowerShell availability, seven SDK tools through the real child planner and dispatcher, explicit/ambient providers, single permission-instance reuse, actual Hermes `memory_search` (when installed), extension model/tool round trips and nested SDK execution in foreground/detached children, parent-mode switches through cached child/intermediate YOLO, headless parent allow/deny/YOLO, custom extractors, denied-write side effects, stale approvals, missing/broken enforcement, concurrent siblings, ancestor collisions, cleanup, and environment checks. Provenance assertions join requester input details, worker identity, and the parent's user decision by request ID and session identity; mismatched request IDs, agents, and responders must fail. The TUI suite uses a pseudo-terminal and scripted decisions to verify dialog focus, ordering, cancellation, and shutdown.

`package-checks.mjs` checks plugin presence and entrypoint identity. Optional arguments compare source bytes and repository settings/filter wiring. It does not require particular installed versions.

For live validation, enter Guard mode: approve `pwd`, deny a harmless `printf`, and confirm the existing `sudo *` rule blocks `sudo --version` without a prompt. Repeat across foreground, background, resume, and an authorized coordinator. Spawn approval and child-operation approval are separate. In YOLO, ordinary asks should skip prompts while explicit denials remain effective; inspect audit provenance rather than inferring auto-approval from command success. Automated checks do not replace this model/provider-specific test.

## Removal

Quit Pi and finish children before removing the adapter or restoring a backup. Leave Nico's package filter at `extensions: []` to keep its parent dispatcher disabled. Re-enabling its standalone entrypoint restores unguarded native foreground execution; it is not a safe routine rollback. Permission policy does not need to change.
