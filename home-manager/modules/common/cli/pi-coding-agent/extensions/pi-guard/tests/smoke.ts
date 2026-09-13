// Offline integration harness, invoked explicitly with pi -ne -e ... /guard-smoke.
// Uses disposable policy and simulated UI decisions, never live approvals.
import assert from "node:assert/strict";
import { readFileSync, readdirSync } from "node:fs";
import { dependencyPath } from "../dependencies.ts";
const { listBackgroundWorkProviders } = await import(
  dependencyPath("pi-subagents", "src/api/background-work.ts")
);
import { randomUUID } from "node:crypto";
import * as sdk from "@earendil-works/pi-coding-agent";
const { default: permissionSystem } = await import(
  dependencyPath("@gotgenes/pi-permission-system", "src/index.ts")
);
const { default: subagents } = await import(
  dependencyPath("pi-subagents", "index.ts")
);
import guardRoot from "../guard-root.ts";
// Internal lifecycle unit tests intentionally share a graph. loader-checks.ts
// separately tests the real entrypoint, source ownership and package filtering.
const guard = (pi: sdk.ExtensionAPI) => guardRoot(pi, () => {});
import { childSessionGuardChecks } from "./child-session-guard-checks.ts";
import { nestedLifetimeChecks } from "./nested-lifetime-checks.ts";
const { createDefaultChildSessionFactory } = await import(
  dependencyPath("pi-subagents", "src/runs/shared/child-session.ts")
);
import { getPermissionsService, hosts } from "../shared.ts";
import { bridgeSdk } from "../child-resources.ts";

type ReviewEntry = {
  event?: string;
  requestId?: string;
  agentName?: string;
  requesterAgentName?: string;
  requesterSessionId?: string;
  targetSessionId?: string;
  forwarded?: boolean;
  toolName?: string;
  command?: string;
  toolInputPreview?: string;
  resolution?: string;
  decidedBy?: {
    kind?: string;
    responderSessionId?: string;
    decision?: { kind?: string };
  };
};

function hasForwardedReview(
  review: ReviewEntry[],
  parentSessionId: string,
  resolution: "approved" | "denied",
  matchesInput: (entry: ReviewEntry) => boolean,
): boolean {
  // The requester owns input details, while the parent owns agent attribution.
  // Join on request identity; never combine unrelated approvals or identities.
  return review.some((result) => {
    if (
      !result.requestId ||
      result.event !== `permission_request.${resolution}` ||
      result.resolution !== resolution ||
      result.decidedBy?.kind !== "forwarded" ||
      result.decidedBy.responderSessionId !== parentSessionId ||
      result.decidedBy.decision?.kind !== "user" ||
      !matchesInput(result)
    )
      return false;
    const created = review.find(
      (entry) =>
        entry.event === "forwarded_permission.request_created" &&
        entry.requestId === result.requestId &&
        entry.requesterAgentName === "worker" &&
        entry.targetSessionId === parentSessionId &&
        typeof entry.requesterSessionId === "string",
    );
    return (
      !!created &&
      review.some(
        (entry) =>
          entry.event === `permission_request.${resolution}` &&
          entry.requestId === result.requestId &&
          entry.forwarded === true &&
          entry.resolution === resolution &&
          entry.agentName === "worker" &&
          entry.requesterSessionId === created.requesterSessionId &&
          entry.decidedBy?.kind === "user",
      )
    );
  });
}

export default function smoke(pi: sdk.ExtensionAPI) {
  pi.registerCommand("guard-smoke", {
    handler: async () => {
      const sessions: any[] = [];
      let root: any;
      let factory: any;
      const errors: any[] = [];
      const prompts: string[] = [];
      const notices: { message: string; level: string }[] = [];
      const order = process.env.PI_GUARD_TEST_ORDER ?? "permissions-first";
      let decision: "approve" | "deny" = "approve";
      let onPrompt: (() => Promise<void>) | undefined;
      const envBefore = JSON.stringify(process.env);
      try {
        sdk.initTheme("dark");
        nestedLifetimeChecks();
        const runtimeVersion = JSON.parse(
          readFileSync(sdk.getPackageDir() + "/package.json", "utf8"),
        ).version;
        const inventorySettings = sdk.SettingsManager.inMemory({
          compaction: { enabled: false },
        });
        const inventoryLoader = new sdk.DefaultResourceLoader({
          cwd: process.cwd(),
          agentDir: process.env.PI_CODING_AGENT_DIR,
          settingsManager: inventorySettings,
          noExtensions: true,
          noSkills: true,
          noContextFiles: true,
          noThemes: true,
          noPromptTemplates: true,
        });
        await inventoryLoader.reload();
        const { session: inventory } = await sdk.createAgentSession({
          cwd: process.cwd(),
          resourceLoader: inventoryLoader,
          settingsManager: inventorySettings,
          sessionManager: sdk.SessionManager.inMemory(process.cwd()),
        });
        const inventoryTools = inventory.getAllTools();
        const runtimeBuiltins = inventoryTools.map((tool) => tool.name);
        inventory.dispose();
        assert(runtimeBuiltins.includes("bash"));
        if ("createPowerShellTool" in sdk)
          assert(
            runtimeBuiltins.includes("powershell"),
            "probe sees new builtin independently of guard constants",
          );
        // A genuinely absent service must remain unavailable even if someone
        // emits a matching ready fact.
        const pendingBus = sdk.createEventBus();
        const pendingHandlers = new Map<string, any>();
        const pendingNotices: { message: string; level: string }[] = [];
        const pendingId = randomUUID();
        const pendingCtx = {
          hasUI: true,
          sessionManager: { getSessionId: () => pendingId },
          ui: {
            notify: (message: string, level: string) =>
              pendingNotices.push({ message, level }),
          },
        };
        guard({
          events: pendingBus,
          on: (name: string, handler: any) =>
            pendingHandlers.set(name, handler),
        } as any);
        const admission = (input: any) =>
          pendingHandlers.get("tool_call")({ toolName: "subagent", input });
        assert.equal(
          admission({ agent: "worker" }),
          undefined,
          "native mode selection remains upstream-owned",
        );
        assert.equal(admission({ agent: "delegate", async: true }), undefined);
        assert.equal(admission({ agent: "reviewer", async: false }), undefined);
        assert.equal(
          admission({ action: "resume", id: "previous" }),
          undefined,
        );
        assert.equal(admission({ action: "status" }), undefined);
        assert.equal(
          admission({ agent: "codex-exec", async: true }),
          undefined,
          "external CLI routing is outside this guard",
        );
        await pendingHandlers.get("session_start")({}, pendingCtx);
        pendingBus.emit("permissions:ready", {
          sessionId: randomUUID(),
          adjudicatesLocally: true,
        });
        pendingBus.emit("permissions:ready", {
          sessionId: pendingId,
          adjudicatesLocally: true,
        });
        assert.equal(
          hosts().size,
          0,
          "missing service cannot create a binding",
        );
        assert(!pendingNotices.some((notice) => notice.level === "error"));
        await pendingHandlers.get("session_shutdown")();

        const failedCeilingBus = sdk.createEventBus();
        const failedCeilingHandlers = new Map<string, any>();
        const failedCeilingNotices: string[] = [];
        let shutdownRequested = 0;
        guardRoot(
          {
            events: failedCeilingBus,
            on: (name: string, handler: any) =>
              failedCeilingHandlers.set(name, handler),
          } as any,
          () => {
            throw new Error("intentional dispatcher conflict");
          },
          () => {
            throw new Error("intentional ceiling failure");
          },
        );
        const failedCeilingCtx = {
          hasUI: false,
          mode: "print",
          sessionManager: { getSessionId: () => randomUUID() },
          ui: {
            notify: (message: string) => failedCeilingNotices.push(message),
          },
          shutdown: () => {
            shutdownRequested++;
          },
        };
        await failedCeilingHandlers.get("session_start")({}, failedCeilingCtx);
        assert.equal(
          shutdownRequested,
          1,
          "a failed deny-all barrier shuts down the root",
        );
        assert(
          failedCeilingNotices.at(-1)?.includes("shutting down"),
          "the fail-closed shutdown is diagnostic",
        );
        assert.equal(
          failedCeilingHandlers.get("tool_call")({ toolName: "subagent" })
            .block,
          true,
          "model dispatch remains blocked during shutdown",
        );
        await failedCeilingHandlers.get("session_shutdown")();

        const bus = sdk.createEventBus();
        const settings = sdk.SettingsManager.inMemory({
          compaction: { enabled: false },
        });
        const loader = new sdk.DefaultResourceLoader({
          cwd: process.cwd(),
          agentDir: process.env.PI_CODING_AGENT_DIR,
          settingsManager: settings,
          noExtensions: true,
          noSkills: true,
          noContextFiles: true,
          noThemes: true,
          noPromptTemplates: true,
          eventBus: bus,
          extensionFactories:
            order === "guard-first"
              ? [
                  { name: "guard", factory: guard },
                  { name: "subagents", factory: subagents },
                  { name: "permissions", factory: permissionSystem },
                ]
              : [
                  { name: "permissions", factory: permissionSystem },
                  { name: "subagents", factory: subagents },
                  { name: "guard", factory: guard },
                ],
        });
        await loader.reload();
        assert.deepEqual(loader.getExtensions().errors, []);
        ({ session: root } = await sdk.createAgentSession({
          cwd: process.cwd(),
          agentDir: process.env.PI_CODING_AGENT_DIR,
          resourceLoader: loader,
          settingsManager: settings,
          sessionManager: sdk.SessionManager.inMemory(process.cwd()),
          tools: ["subagent"],
        }));
        await root.bindExtensions({
          mode: "rpc",
          uiContext: {
            select: async (title: string, choices: string[]) => {
              prompts.push(title);
              await onPrompt?.();
              const answer = decision === "approve" ? "Yes" : "No";
              assert(
                choices.includes(answer),
                "known permission-system UI choices",
              );
              return answer;
            },
            notify: (message: string, level: string) =>
              notices.push({ message, level }),
            setStatus: () => {},
            setWidget: () => {},
            setWorkingMessage: () => {},
            setWorkingIndicator: () => {},
            setTitle: () => {},
            setEditorText: () => {},
            getToolsExpanded: () => false,
            setToolsExpanded: () => {},
            setWorkingVisible: () => {},
            getEditorText: () => "",
          } as any,
          onError: (error: any) => errors.push(error),
        });
        assert.equal(hosts().size, 1, "guard root initialized");
        const rootService = getPermissionsService(root.sessionId);
        assert(rootService);
        assert.equal(
          rootService.checkPermission("bash", "sudo --version").state,
          "deny",
        );
        assert(
          !notices.some((notice) => notice.level === "error"),
          "startup ordering must not cause an error notification",
        );
        const initialHost = hosts().get(root.sessionId);
        bus.emit("permissions:ready", {
          sessionId: randomUUID(),
          adjudicatesLocally: true,
        });
        bus.emit("permissions:ready", {
          sessionId: root.sessionId,
          adjudicatesLocally: true,
        });
        bus.emit("permissions:ready", {
          sessionId: root.sessionId,
          adjudicatesLocally: true,
        });
        assert.equal(
          hosts().get(root.sessionId),
          initialHost,
          "readiness repeats must preserve parent generation",
        );

        factory = createDefaultChildSessionFactory({
          loadPiCodingAgent: async () =>
            bridgeSdk({
              ...sdk,
              createAgentSession: async (options: any) => {
                const result = await sdk.createAgentSession(options);
                sessions.push(result.session);
                return result;
              },
            }),
        });
        const childGuardAfterShutdown = await childSessionGuardChecks({
          root,
          factory,
          sessions,
          runtimeBuiltins,
          prompts,
          eventBus: bus,
          setDecision: (value: typeof decision) => {
            decision = value;
          },
          setOnPrompt: (handler?: () => Promise<void>) => {
            onPrompt = handler;
          },
        });
        const headlessLoader = new sdk.DefaultResourceLoader({
          cwd: process.cwd(),
          agentDir: sdk.getAgentDir(),
          settingsManager: settings,
          noExtensions: true,
          noSkills: true,
          noContextFiles: true,
          noThemes: true,
          extensionFactories: [
            { name: "permissions", factory: permissionSystem },
            { name: "guard", factory: guard },
          ],
        });
        await headlessLoader.reload();
        const { session: headlessRoot } = await sdk.createAgentSession({
          cwd: process.cwd(),
          settingsManager: settings,
          resourceLoader: headlessLoader,
          sessionManager: sdk.SessionManager.inMemory(process.cwd()),
        });
        let headlessChild: any;
        try {
          await headlessRoot.bindExtensions({
            mode: "print",
            onError: (error: any) => errors.push(error),
          });
          assert(
            hosts().has(headlessRoot.sessionId),
            "a headless root still serves recorded policy",
          );
          const { buildInProcessChildLaunch } = await import(
            dependencyPath("pi-subagents", "src/runs/shared/child-launch.ts")
          );
          const { createGuardedFactory } =
            await import("../child-session-guard.ts");
          const plan = buildInProcessChildLaunch({
            host: "parent",
            cwd: process.cwd(),
            childAgentName: "worker",
            childIndex: 0,
            runId: randomUUID(),
            parentSessionId: headlessRoot.sessionId,
            systemPrompt: '<active_agent name="worker">',
            tools: ["read", "bash"],
            inheritProjectContext: false,
            inheritGlobalContext: false,
            inheritSkills: false,
          });
          headlessChild = await createGuardedFactory(factory).create(
            plan.session,
          );
          const child = sessions.find(
            (session: any) => session.sessionId === headlessChild.sessionId,
          );
          const gate = (name: string, input: unknown) =>
            child.extensionRunner.emitToolCall({
              type: "tool_call",
              toolCallId: randomUUID(),
              toolName: name,
              input,
            });
          assert.equal(
            (await gate("read", { path: process.cwd() + "/native-worker.txt" }))
              ?.block,
            undefined,
          );
          assert.equal(
            (await gate("bash", { command: "pwd" }))?.block,
            true,
            "headless asks deny like the main agent",
          );
          const config = (getPermissionsService(headlessRoot.sessionId) as any)
            .session.configStore;
          const snapshot = { ...config.current() };
          config.save(
            { ...snapshot, yoloMode: true },
            { ui: { setStatus() {}, notify() {} } },
          );
          try {
            assert.equal(
              (await gate("bash", { command: "pwd" }))?.block,
              undefined,
              "headless parent YOLO can auto-approve",
            );
            assert.equal(
              (await gate("bash", { command: "sudo --version" }))?.block,
              true,
            );
          } finally {
            config.save(snapshot, { ui: { setStatus() {}, notify() {} } });
          }
        } finally {
          await headlessChild?.dispose();
          await headlessRoot.extensionRunner.emit({
            type: "session_shutdown",
            reason: "quit",
          });
          headlessRoot.dispose();
        }
        const activeHost = hosts().get(root.sessionId)!;
        activeHost.children.set("cleanup-fault", () => {
          throw new Error("intentional cleanup fault");
        });
        const cleanupErrors: string[] = [];
        const originalConsoleError = console.error;
        console.error = (...args) =>
          cleanupErrors.push(args.map(String).join(" "));
        try {
          await root.extensionRunner.emit({
            type: "session_shutdown",
            reason: "reload",
          });
        } finally {
          console.error = originalConsoleError;
        }
        assert(
          cleanupErrors.some((message) =>
            message.includes("intentional cleanup fault"),
          ),
          "cleanup faults are reported after revocation",
        );
        root.dispose();
        root = undefined;
        assert.equal(hosts().size, 0, "parent generation cleaned up");
        await childGuardAfterShutdown();
        assert.deepEqual(
          readdirSync(process.env.PI_CODING_AGENT_DIR + "/pi-guard/leases"),
          [],
          "all root/native generation leases cleaned up",
        );
        assert.equal(
          listBackgroundWorkProviders().length,
          0,
          "nested lifetime providers do not leak after disposal",
        );
        bus.emit("permissions:ready", {
          sessionId: initialHost!.sessionId,
          adjudicatesLocally: true,
        });
        assert.equal(
          hosts().size,
          0,
          "late readiness must not resurrect a shutdown parent",
        );
        assert.deepEqual(errors, []);
        const review = readFileSync(
          process.env.PI_CODING_AGENT_DIR +
            "/extensions/pi-permission-system/logs/pi-permission-system-permission-review.jsonl",
          "utf8",
        )
          .trim()
          .split("\n")
          .map((line) => JSON.parse(line));
        const workerPwd = (entry: ReviewEntry) =>
          entry.toolName === "bash" && entry.command === "pwd";
        const workerWrite = (entry: ReviewEntry) =>
          entry.toolName === "write" &&
          entry.toolInputPreview?.includes("/native-denied.txt") === true;
        const parentId = initialHost!.sessionId;
        assert(
          hasForwardedReview(review, parentId, "approved", workerPwd),
          "native worker approval has parent forwarding provenance",
        );
        assert(
          hasForwardedReview(review, parentId, "denied", workerWrite),
          "native worker write denial keeps its original agent identity",
        );
        for (const [resolution, input] of [
          ["approved", workerPwd],
          ["denied", workerWrite],
        ] as const) {
          assert(
            !hasForwardedReview(review, "wrong-parent", resolution, input),
          );
          assert(
            !hasForwardedReview(
              review.map((entry: ReviewEntry) =>
                entry.event === "forwarded_permission.request_created"
                  ? { ...entry, requestId: "unrelated-" + entry.requestId }
                  : entry,
              ),
              parentId,
              resolution,
              input,
            ),
            "unrelated records must not establish provenance",
          );
          assert(
            !hasForwardedReview(
              review.map((entry: ReviewEntry) =>
                entry.forwarded
                  ? { ...entry, agentName: "wrong-agent" }
                  : entry,
              ),
              parentId,
              resolution,
              input,
            ),
            "another agent's decision must not establish worker identity",
          );
        }
        // Pi-subagents itself may publish a parent marker; the guard never writes env.
        console.log(
          JSON.stringify({
            ok: true,
            runtimeVersion,
            runtimeBuiltins,
            order,
            uiPrompts: prompts.length,
            checks: [
              "stock SDK builtin inventory without Guard tool restrictions",
              "startup order and missing-service readiness",
              "idempotent readiness",
              "native role/tool preservation",
              "foreground/background/resume/nesting",
              "deny/allow/ask forwarding",
              "sibling and ancestor isolation",
              "service/lifecycle cleanup",
            ],
            environmentChangedByHostExtensions:
              JSON.stringify(process.env) !== envBefore,
          }),
        );
      } catch (error) {
        console.error(error);
        console.error("Extension errors:", errors);
        process.exitCode = 1;
      } finally {
        await factory?.dispose();
        if (root) {
          await root.extensionRunner.emit({
            type: "session_shutdown",
            reason: "quit",
          });
          root.dispose();
        }
      }
      process.exit(process.exitCode ?? 0);
    },
  });
}
