# Pi subagent permission forwarding bridge

This global extension keeps `@gotgenes/pi-permission-system` approval requests attached to the interactive Pi session that launched a native `pi-subagents` child.

At interactive session start, the extension records the session ID in the parent process environment and configures `PI_SUBAGENT_PI_BINARY` to use `launcher.mjs`. It removes `PI_SUBAGENT_PARENT_SESSION` from the interactive root because the permission system treats that convention variable as a child marker; `pi-subagents@0.56.0` currently sets it in the root process. The launcher restores the root ID as `PI_SUBAGENT_PARENT_SESSION` only in each child. Nested children inherit the same root ID, so the permission system can display its existing approval dialog in the owning TUI.

The bridge does not approve tools and does not use `contact_supervisor`. Permission rules and human decisions remain inside `@gotgenes/pi-permission-system`.

## Safety behavior

- Headless roots remove inherited bridge variables and do not install the bridge.
- Child extension instances do not replace the inherited root session ID.
- Invalid or missing session IDs stop the child launch instead of selecting another open Pi session.
- Existing `PI_SUBAGENT_PI_BINARY` wrappers are chained.
- Multiple Pi processes keep separate environment anchors.
- Session shutdown restores the environment values that the extension replaced.

## Files

- `index.ts`: owns interactive session setup and cleanup.
- `bridge.ts`: validates IDs and manages environment changes.
- `launcher.mjs`: starts child Pi processes with the corrected forwarding target.

Run `/reload` after adding, changing, or removing this extension.

## Runtime checks

Test guarded behavior in guard mode: a child `bash` call should pause and display the permission-system dialog in the owning TUI. Approving should run the command; denying should block it. Repeat with a nested child.

Then switch to yolo mode and repeat the child call. No approval dialog should appear, and the permission review log should record the automatic decision with `origin: "yolo"`.
