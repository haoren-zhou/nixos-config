import type {
  ExtensionAPI,
  ExtensionContext,
} from "@earendil-works/pi-coding-agent";
import { runCleanup, type CleanupStep } from "./cleanup.ts";
import { createBridgeGates } from "./bridge-gates.ts";
import {
  announce,
  block,
  CREATED,
  DISPOSED,
  getPermissionsService,
} from "./shared.ts";
import {
  acquireLease,
  assertLeaseLive,
  releaseLease,
  type Lease,
} from "./leases.ts";
import { trackNestedLifetime } from "./nested-lifetime.ts";
import {
  dynamicEventRegistrar,
  type PermissionEventHandler,
} from "./permission-api.ts";

export interface NativeBinding {
  parent: Lease;
  remote: boolean;
  allowNested: boolean;
  lease?: Lease;
  active: boolean;
  failure?: string;
  permissionReady?: boolean;
  permissionService?: object;
  close?: () => void;
  permissionApi?: ExtensionAPI;
  wrapPermissionHandler?: (
    event: string,
    handler: PermissionEventHandler,
  ) => PermissionEventHandler;
}

// Only permission-system sees a serving context. Other child extensions retain
// their real headless context; local dialog fallbacks can never approve a call.
function relayContext(ctx: ExtensionContext): ExtensionContext {
  return {
    ...ctx,
    hasUI: true,
    mode: "print",
    ui: {
      ...ctx.ui,
      select: async () => undefined,
      confirm: async () => false,
      input: async () => undefined,
      editor: async () => undefined,
      custom: async () => undefined,
    },
  } as ExtensionContext;
}

export async function attachNativeChild(
  pi: ExtensionAPI,
  binding: NativeBinding,
): Promise<void> {
  let initialized = false;
  let gates: ReturnType<typeof createBridgeGates> | undefined;
  const shutdown: (() => void)[] = [];
  const stopNested = binding.allowNested ? trackNestedLifetime(pi) : () => {};
  const parentCheck = () => {
    assertLeaseLive(binding.parent);
    if (
      binding.remote &&
      (process.env.PI_SUBAGENT_PARENT_SESSION !== binding.parent.sessionId ||
        process.env.PI_AGENT_ROUTER_PARENT_SESSION_ID)
    )
      throw new Error("runner permission-forwarding environment changed");
  };
  const check = (_event?: unknown, ctx?: ExtensionContext) => {
    try {
      if (
        !binding.active ||
        !binding.lease ||
        (ctx && ctx.sessionManager.getSessionId() !== binding.lease.sessionId)
      )
        throw new Error(binding.failure ?? "child binding is inactive");
      if (
        binding.permissionReady &&
        getPermissionsService(binding.lease.sessionId) !==
          binding.permissionService
      )
        throw new Error("child permission service changed");
      if (ctx?.signal?.aborted) throw new Error("tool call cancelled");
      parentCheck();
      assertLeaseLive(binding.lease);
    } catch (error) {
      return block(String(error));
    }
  };
  const release = () => {
    const revokedLease = binding.lease;
    binding.active = false;
    binding.permissionReady = false;
    binding.permissionService = undefined;
    binding.lease = undefined;
    if (!revokedLease) return;
    runCleanup("Pi Guard child", [
      {
        name: "announce child disposal",
        run: () => announce(pi, DISPOSED, revokedLease.sessionId),
      },
      { name: "release child lease", run: () => releaseLease(revokedLease) },
    ]);
  };
  binding.close = () => {
    const steps: CleanupStep[] = [
      { name: "stop nested-run tracking", run: stopNested },
      { name: "revoke child binding", run: release },
    ];
    if (initialized) {
      initialized = false;
      gates = undefined;
      shutdown.forEach((stop, index) =>
        steps.push({ name: `permission shutdown ${index + 1}`, run: stop }),
      );
    }
    runCleanup("Pi Guard child", steps);
  };
  pi.on("session_shutdown", release);
  pi.on("session_start", (_event, ctx) => {
    try {
      if (ctx.hasUI || binding.lease)
        throw new Error("invalid or repeated native child activation");
      parentCheck();
      const id = ctx.sessionManager.getSessionId();
      if (getPermissionsService(id))
        throw new Error("session already has a permission service");
      binding.lease = acquireLease(id, binding.parent);
      announce(
        pi,
        CREATED,
        id,
        binding.remote ? undefined : binding.parent.sessionId,
      );
      binding.active = true;
    } catch (error) {
      binding.failure = String(error);
      throw error;
    }
  });
  pi.on("tool_call", check);

  binding.wrapPermissionHandler = (event, handler) => {
    if (event === "session_shutdown") shutdown.push(() => handler());
    return async (value, ctx) => {
      if (event === "session_shutdown") {
        if (!initialized) return;
        initialized = false;
        gates = undefined;
        return handler(value, ctx);
      }
      if (event === "tool_call") {
        if (!ctx) return block("child permission context is unavailable");
        const denied = check(value, ctx);
        if (denied) return denied;
        if (!gates) return block("child permission gates are unavailable");
        const result = await gates.toolCall(value, relayContext(ctx));
        return check(value, ctx) ?? result;
      }
      if (event === "input") {
        // Pi continues input processing after thrown handler errors. Consume
        // unavailable/stale skill inputs rather than permit unchecked expansion.
        if (!ctx || !gates || check(value, ctx)) return { action: "handled" };
        try {
          const result = await gates.input(value, relayContext(ctx));
          return check(value, ctx) ? { action: "handled" } : result;
        } catch {
          return { action: "handled" };
        }
      }
      if (!binding.active || !binding.lease)
        throw new Error(binding.failure ?? "native binding did not activate");
      if (!ctx) throw new Error(`permission event ${event} has no context`);
      parentCheck();
      if (event === "session_start") initialized = true;
      const result = await handler(value, relayContext(ctx));
      if (event === "session_start") {
        gates = createBridgeGates(pi, binding.lease.sessionId);
        binding.permissionService = getPermissionsService(
          binding.lease.sessionId,
        );
        binding.permissionReady = true;
      }
      return result;
    };
  };
  const register = dynamicEventRegistrar(pi);
  binding.permissionApi = {
    ...pi,
    on: ((event: string, handler: PermissionEventHandler) =>
      register(
        event,
        binding.wrapPermissionHandler!(event, handler),
      )) as ExtensionAPI["on"],
  };
}
