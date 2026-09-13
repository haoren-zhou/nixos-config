import type {
  ExtensionAPI,
  ExtensionContext,
} from "@earendil-works/pi-coding-agent";
import { dependencyPath } from "./dependencies.ts";
import { getPermissionsService } from "./shared.ts";

// Reuse the upstream gate producers, normalizers, extractors and authorizer.
// Only gate resolution is delegated: the serving parent owns policy and YOLO.
const load = (path: string) =>
  import(dependencyPath("@gotgenes/pi-permission-system", `src/${path}.ts`));
const { ToolCallGatePipeline } = await load(
  "handlers/gates/tool-call-gate-pipeline",
);
const { SkillInputGatePipeline } = await load(
  "handlers/gates/skill-input-gate-pipeline",
);
const { PermissionGateHandler } = await load(
  "handlers/permission-gate-handler",
);
const { GateRunner } = await load("handlers/gates/runner");
const { isGateBypass, preResolvedCheckOf } = await load(
  "handlers/gates/descriptor",
);
const { createFailClosedToolCall } = await load("handlers/tool-call-boundary");
const { GateDecisionReporter } = await load("logging/decision-reporter");
const { DecisionAudit } = await load("logging/decision-audit");
const { getSubagentSessionRegistry } = await load(
  "authority/subagent-registry",
);
const {
  AncestorNodes,
  InheritingToolInputFormatterLookup,
  InheritingToolAccessExtractorLookup,
} = await load("authority/inherited-registrations");

interface Check {
  state: "allow" | "deny" | "ask";
  source: string;
  origin: string;
  [key: string]: unknown;
}
interface Resolver {
  resolve(intent: unknown): Check;
  checkPermission(...args: unknown[]): Check;
  getToolPermission(...args: unknown[]): unknown;
  isToolFullyDenied(...args: unknown[]): boolean;
  getConfigIssues(...args: unknown[]): unknown;
}
function forwardedCheck(check: Check): Check {
  return check.source === "session"
    ? check
    : { ...check, state: "ask", source: "default", origin: "baseline" };
}
interface PermissionNode {
  resolver: Resolver;
  session: {
    sessionRules: unknown;
    authorizerSelection: unknown;
    configStore: { deps: { logger: unknown } };
  };
  formatterRegistry: unknown;
  accessExtractorRegistry: unknown;
}

export function createBridgeGates(pi: ExtensionAPI, sessionId: string) {
  // The upstream service exposes read-only queries, not an execution gate.
  // Keep this private composition seam explicit and fail closed on API changes.
  const node = getPermissionsService(sessionId) as unknown as PermissionNode;
  if (
    ![
      "resolve",
      "checkPermission",
      "getToolPermission",
      "isToolFullyDenied",
      "getConfigIssues",
    ].every(
      (method) =>
        typeof (node?.resolver as unknown as Record<string, unknown>)?.[
          method
        ] === "function",
    ) ||
    !node.session?.sessionRules ||
    !node.session.authorizerSelection ||
    !node.session.configStore?.deps?.logger ||
    !node.formatterRegistry ||
    !node.accessExtractorRegistry
  )
    throw new Error("Guard: permission gate composition is unavailable");
  const original = node.resolver;
  const resolver: Resolver = {
    resolve: original.resolve.bind(original),
    checkPermission: original.checkPermission.bind(original),
    getToolPermission: original.getToolPermission.bind(original),
    isToolFullyDenied: original.isToolFullyDenied.bind(original),
    getConfigIssues: original.getConfigIssues.bind(original),
  };
  // The upstream inbox closes over the original resolver. Intermediate nodes
  // must relay rather than auto-approve grandchildren from cached local YOLO.
  // Public advisory queries and gate production keep their ordinary behavior.
  original.resolve = (intent) => forwardedCheck(resolver.resolve(intent));
  node.resolver = resolver;
  const logger = node.session.configStore.deps.logger;
  const reporter = new GateDecisionReporter(logger, pi.events);
  const runner = new GateRunner(
    resolver,
    node.session.sessionRules,
    node.session.authorizerSelection,
    reporter,
    () => false,
  );
  const delegatedRunner = {
    run(gate: Record<string, unknown> | null, agentName: string | null) {
      if (!gate || isGateBypass(gate)) return runner.run(gate, agentName);
      const check: Check =
        preResolvedCheckOf(gate) ??
        resolver.resolve({
          kind: "tool",
          surface: gate.surface,
          input: gate.input,
          agentName: agentName ?? undefined,
        });
      // Gate production and deny-first ordering are upstream-owned. The parent
      // decides the resulting fixed facts, except genuine human session grants.
      return runner.run(
        { ...gate, preCheck: forwardedCheck(check) },
        agentName,
      );
    },
  };
  const ancestors = new AncestorNodes(
    { currentSessionId: () => sessionId },
    getSubagentSessionRegistry(),
    getPermissionsService,
  );
  const registry = {
    getAll: () => pi.getAllTools(),
    getActive: () => pi.getActiveTools(),
    setActive: (names: string[]) => pi.setActiveTools(names),
  };
  const gates = new PermissionGateHandler(
    node.session,
    registry,
    new ToolCallGatePipeline(
      resolver,
      node.session,
      new InheritingToolInputFormatterLookup(node.formatterRegistry, ancestors),
      new InheritingToolAccessExtractorLookup(
        node.accessExtractorRegistry,
        ancestors,
      ),
    ),
    new SkillInputGatePipeline(resolver),
    delegatedRunner,
  );
  return {
    toolCall: createFailClosedToolCall(
      (event: unknown, ctx: ExtensionContext) =>
        gates.handleToolCall(event, ctx),
      reporter,
      new DecisionAudit(),
      logger,
    ) as (event: unknown, ctx: ExtensionContext) => Promise<unknown>,
    input: (event: unknown, ctx: ExtensionContext) =>
      gates.handleInput(event, ctx),
  };
}
