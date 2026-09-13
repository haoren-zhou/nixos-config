import type {
  ExtensionAPI,
  ExtensionContext,
} from "@earendil-works/pi-coding-agent";
import { runCleanup, type CleanupStep } from "./cleanup.ts";
import { dependencyPath } from "./dependencies.ts";
import { installChildSessionGuard } from "./child-session-guard.ts";
import { installDialogQueue, type DialogQueue } from "./dialog-queue.ts";
import { serveHeadlessParent } from "./permission-api.ts";
import {
  acquireLease,
  assertLeaseLive,
  releaseLease,
  type Lease,
} from "./leases.ts";
import {
  block,
  getPermissionsService,
  hosts,
  live,
  type Host,
} from "./shared.ts";
import type {
  CapabilityCeilingHandle,
  CapabilityCeilingModule,
  RegisterCapabilityCeiling,
} from "./nico-contracts.ts";

const { registerSubagentCapabilityCeiling } = (await import(
  dependencyPath("pi-subagents", "src/api/capability-ceiling.ts")
)) as unknown as CapabilityCeilingModule;

export default function guardRoot(
  pi: ExtensionAPI,
  verifyDispatcher: () => void = () => {
    throw new Error(
      "Guard root must be loaded through the guarded Nico entrypoint",
    );
  },
  registerFailureCeiling: RegisterCapabilityCeiling = registerSubagentCapabilityCeiling,
): void {
  if (process.env.PI_SUBAGENT_CHILD === "1") return;
  let lease: Lease | undefined;
  let host: Host | undefined;
  let failureCeiling: CapabilityCeilingHandle | undefined;
  let currentCtx: ExtensionContext | undefined;
  let parentSessionId: string | undefined;
  let dialogs: DialogQueue | undefined;

  const cleanup = () => {
    const revokedLease = lease;
    const revokedHost = host;
    const revokedCeiling = failureCeiling;

    lease = undefined;
    host = undefined;
    failureCeiling = undefined;
    if (revokedHost) {
      revokedHost.active = false;
      if (hosts().get(revokedHost.sessionId) === revokedHost)
        hosts().delete(revokedHost.sessionId);
    }

    const steps: CleanupStep[] = [];
    for (const [childId, release] of revokedHost?.children ?? [])
      steps.push({ name: `release child ${childId}`, run: release });
    if (revokedLease)
      steps.push({
        name: "release root lease",
        run: () => releaseLease(revokedLease),
      });
    if (revokedCeiling)
      steps.push({
        name: "dispose failure ceiling",
        run: () => revokedCeiling.dispose(),
      });
    runCleanup("Pi Guard root", steps);
  };

  const markUnavailable = (ctx: ExtensionContext, error: unknown) => {
    const sessionId = ctx.sessionManager.getSessionId();
    cleanup();
    let reason = String(error);
    try {
      failureCeiling = registerFailureCeiling({
        sessionId,
        source: "pi-guard:unavailable",
        ceiling: { allowedAgents: [] },
      });
    } catch (ceilingError) {
      reason += `; failed to install deny-all capability ceiling: ${String(ceilingError)}; shutting down`;
      ctx.shutdown();
    }
    ctx.ui.notify(`Pi Guard unavailable: ${reason}`, "error");
  };

  // Install even while permission-system is still starting: unknown parents
  // must fail closed at the native factory, not fall through to the default.
  let installationError: unknown;
  try {
    installChildSessionGuard();
  } catch (error) {
    installationError = error;
  }
  pi.on("tool_call", (event) => {
    if (event.toolName !== "subagent") return;
    if (installationError)
      return block(`native factory unavailable: ${String(installationError)}`);
    try {
      dialogs?.assertLive();
      verifyDispatcher();
      installChildSessionGuard();
    } catch (error) {
      return block(String(error));
    }
    // Dispatch mode, resume, depth and fanout remain Nico-owned. Every native
    // session reaches the guarded foreground or detached factory.
  });

  const start = (ctx: ExtensionContext) => {
    // Install before permission readiness, in either extension load order.
    // All root extensions (including permission-system) retain this UI object.
    if (ctx.hasUI && ctx.mode === "tui") {
      try {
        if (installationError) throw installationError;
        if (dialogs && dialogs.ui !== ctx.ui) {
          dialogs.dispose();
          dialogs = undefined;
        }
        dialogs ??= installDialogQueue(ctx.ui, { allowRebind: true });
        dialogs.assertLive();
      } catch (error) {
        markUnavailable(ctx, error);
        return;
      }
    }
    // Ready broadcasts may repeat, including at turn preparation. Never
    // invalidate a live generation (and its children) just to refresh status.
    if (live(host) && host.sessionId === ctx.sessionManager.getSessionId()) {
      try {
        verifyDispatcher();
        installChildSessionGuard();
        if (!lease) throw new Error("missing root generation");
        assertLeaseLive(lease);
        return;
      } catch (error) {
        installationError = error;
      }
    }
    cleanup();
    try {
      if (installationError) throw installationError;
      verifyDispatcher();
      installChildSessionGuard();
    } catch (error) {
      markUnavailable(ctx, error);
      return;
    }
    try {
      const sessionId = ctx.sessionManager.getSessionId();
      const service = getPermissionsService(sessionId);
      if (!service) return;
      if (!ctx.hasUI) serveHeadlessParent(service, ctx);
      lease = acquireLease(sessionId);
      host = { sessionId, service, active: true, children: new Map() };
      hosts().set(sessionId, host);
    } catch (error) {
      markUnavailable(ctx, error);
    }
  };

  // Local extensions can start before npm extensions. Subscribe at factory
  // load, then use only this parent's keyed publication, never a child's ready
  // event or a service capability supplied in the event payload.
  const stopReady = pi.events.on("permissions:ready", (payload: unknown) => {
    if (!currentCtx || !payload || typeof payload !== "object") return;
    if (
      (payload as { sessionId?: unknown }).sessionId !== parentSessionId ||
      currentCtx.sessionManager.getSessionId() !== parentSessionId
    )
      return;
    start(currentCtx);
  });
  pi.on("session_start", (_event, ctx) => {
    cleanup();
    currentCtx = ctx;
    parentSessionId = ctx.sessionManager.getSessionId();
    start(ctx);
  });
  pi.on("session_shutdown", () => {
    currentCtx = undefined;
    parentSessionId = undefined;
    stopReady();
    cleanup();
    dialogs?.dispose();
    dialogs = undefined;
  });
}
