import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { dependencyPath } from "./dependencies.ts";
const { getPermissionsService } = await import(
  dependencyPath("@gotgenes/pi-permission-system", "src/service.ts")
);

export { getPermissionsService };
export const REGISTER = "pi-subagents:runtime-agent-register:v1";
export const CREATED = "subagents:child:session-created";
export const DISPOSED = "subagents:child:disposed";

export interface Host {
  sessionId: string;
  active: boolean;
  service: NonNullable<ReturnType<typeof getPermissionsService>>;
  children: Map<string, () => void>;
}

// Local child binding resolves the exact root session. Never select the first
// or most recent UI session, consult a prompt, or mutate process.env.
const KEY = Symbol.for("hr.pi-guard.hosts.v1");
export function hosts(): Map<string, Host> {
  const global = globalThis as Record<symbol, unknown>;
  return (global[KEY] ??= new Map<string, Host>()) as Map<string, Host>;
}

export function live(host: Host | undefined): host is Host {
  return (
    !!host?.active && getPermissionsService(host.sessionId) === host.service
  );
}

export function block(reason: string) {
  return {
    block: true as const,
    reason: `Pi Guard: ${reason}`,
    terminate: true,
  };
}

export function announce(
  pi: ExtensionAPI,
  channel: string,
  childId: string,
  parentId?: string,
): void {
  pi.events.emit(channel, {
    sessionId: childId,
    ...(parentId ? { parentSessionId: parentId } : {}),
  });
}
