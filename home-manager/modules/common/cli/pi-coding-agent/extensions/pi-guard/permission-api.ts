import type {
  ExtensionAPI,
  ExtensionContext,
} from "@earendil-works/pi-coding-agent";

interface ForwardingController {
  start(ctx: ExtensionContext): void;
}
const headlessServers = new WeakSet<ForwardingController>();

// A headless parent still answers recorded-policy queries and denies unavailable
// human approvals. Change inbox eligibility only, not its selected authorizer.
export function serveHeadlessParent(
  service: unknown,
  ctx: ExtensionContext,
): void {
  const forwarding = (
    service as { session?: { forwarding?: ForwardingController } }
  )?.session?.forwarding;
  if (typeof forwarding?.start !== "function")
    throw new Error("Guard: headless parent forwarding is unavailable");
  if (!headlessServers.has(forwarding)) {
    const start = forwarding.start.bind(forwarding);
    forwarding.start = (value) =>
      start(value.hasUI ? value : { ...value, hasUI: true });
    headlessServers.add(forwarding);
  }
  forwarding.start(ctx);
}

export type PermissionEventHandler = (
  event?: unknown,
  ctx?: ExtensionContext,
) => unknown;

export type DynamicEventRegistrar = (
  event: string,
  handler: PermissionEventHandler,
) => void;

/** Isolate the cast needed to proxy an overloaded ExtensionAPI.on method. */
export function dynamicEventRegistrar(
  pi: Pick<ExtensionAPI, "on">,
): DynamicEventRegistrar {
  return pi.on.bind(pi) as unknown as DynamicEventRegistrar;
}
