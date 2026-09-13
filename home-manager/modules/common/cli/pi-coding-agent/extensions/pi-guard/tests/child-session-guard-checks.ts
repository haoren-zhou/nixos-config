import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { SessionManager } from "@earendil-works/pi-coding-agent";
import { dependencyPath } from "../dependencies.ts";
const { discoverAgents } = await import(
  dependencyPath("pi-subagents", "src/agents/agents.ts")
);
const { runSync } = await import(
  dependencyPath("pi-subagents", "src/runs/foreground/execution.ts")
);
const { buildInProcessChildLaunch } = await import(
  dependencyPath("pi-subagents", "src/runs/shared/child-launch.ts")
);
const { childSessionFactory, childSessionFactoryModule } = await import(
  dependencyPath("pi-subagents", "src/runs/shared/child-session.ts")
);
const { loadRunnerChildSessionFactory } = await import(
  dependencyPath("pi-subagents", "src/runs/background/runner-child-sessions.ts")
);
import {
  createGuardedFactory,
  installChildSessionGuard,
} from "../child-session-guard.ts";
import { getPermissionsService, hosts } from "../shared.ts";
import { executorChecks } from "./executor-checks.ts";
import { extensionBridgeChecks } from "./extension-bridge-checks.ts";
import { readLease, assertLeaseLive } from "../leases.ts";

export async function childSessionGuardChecks(input: any) {
  const { root, factory, sessions, runtimeBuiltins, setDecision, prompts } =
    input;
  const guarded = createGuardedFactory(factory);
  const discovered = discoverAgents(process.cwd(), "both").agents;
  const roles = ["delegate", "worker", "reviewer", "scout", "oracle"];
  const plan = (name: string, extra: any = {}) => {
    const agent = discovered.find((entry: any) => entry.name === name);
    assert(agent, `real builtin ${name} discovered`);
    return buildInProcessChildLaunch({
      host: "parent",
      hostAvailableBuiltins: runtimeBuiltins,
      cwd: process.cwd(),
      sessionEnabled: false,
      childAgentName: agent.name,
      childIndex: sessions.length,
      parentSessionId: root.sessionId,
      runId: randomUUID(),
      orchestratorIntercomTarget: "guard-smoke-parent",
      systemPromptMode: agent.systemPromptMode,
      systemPrompt: agent.systemPrompt,
      tools: agent.tools,
      excludeTools: agent.excludeTools,
      extensions: agent.extensions,
      subagentOnlyExtensions: agent.subagentOnlyExtensions,
      inheritProjectContext: false,
      inheritGlobalContext: false,
      inheritSkills: false,
      waitToolEnabled: false,
      ...extra,
    });
  };
  // The wrapper must not narrow the upstream calling convention.
  const passthrough = createGuardedFactory({
    async create(launch: any) {
      const handle = await factory.create(launch);
      for (const method of ["prompt", "steer", "followUp"] as const) {
        handle[method] = async function (this: unknown, ...args: unknown[]) {
          return { method, args, receiverMatches: this === handle };
        };
      }
      return handle;
    },
    dispose: () => factory.dispose(),
  });
  const forwardingHandle = await passthrough.create(plan("delegate").session);
  try {
    for (const method of ["prompt", "steer", "followUp"] as const) {
      const args = ["probe", { attachment: "preserved" }];
      assert.deepEqual(await (forwardingHandle as any)[method](...args), {
        method,
        args,
        receiverMatches: true,
      });
    }
  } finally {
    await forwardingHandle.dispose();
  }

  const prepare = async (handle: any) => {
    const session = sessions.find(
      (item: any) => item.sessionId === handle.sessionId,
    );
    assert(session);
    const prepared = await session.extensionRunner.emitBeforeAgentStart(
      "native-agent probe",
      undefined,
      session.systemPrompt,
      {
        cwd: process.cwd(),
        selectedTools: session.agent.state.tools.map((tool: any) => tool.name),
        contextFiles: [],
        skills: [],
      },
    );
    if (prepared?.systemPrompt)
      session.agent.state.systemPrompt = prepared.systemPrompt;
    await session.extensionRunner.emit({ type: "agent_start" });
    return session;
  };
  const gate = (session: any, name: string, args: any) =>
    session.extensionRunner.emitToolCall({
      type: "tool_call",
      toolCallId: randomUUID(),
      toolName: name,
      input: args,
    });
  const dispatch = async (session: any, name: string, args: any) => {
    const result = await gate(session, name, args);
    if (result?.block) return result;
    const tool = session.agent.state.tools.find(
      (item: any) => item.name === name,
    );
    assert(tool, `${name} belongs to this role`);
    return tool.execute(randomUUID(), args);
  };
  const rootService = getPermissionsService(root.sessionId);
  for (const name of roles) {
    const launch = plan(name);
    const before = JSON.stringify(launch.session.tools);
    const handle = await guarded.create(launch.session);
    try {
      const session = await prepare(handle);
      const names = session.agent.state.tools.map((tool: any) => tool.name);
      const expected = launch.session.tools!;
      assert.deepEqual(
        [...names].sort(),
        [...expected].sort(),
        `${name} retains its resolved native tool allowlist`,
      );
      assert.equal(
        JSON.stringify(launch.session.tools),
        before,
        "caller launch is not mutated",
      );
      assert(
        !names.some((tool: string) => tool.startsWith("guard_")),
        "native agent keeps canonical tool names",
      );
      assert.equal(getPermissionsService(root.sessionId), rootService);
      if (name === "reviewer") {
        assert(
          !session
            .getAllTools()
            .some((tool: any) => ["bash", "write", "edit"].includes(tool.name)),
          "reviewer has no mutation tool in its registry",
        );
      }
      assert.equal(
        (await gate(session, "read", { path: process.cwd() + "/secret.env" }))
          ?.block,
        true,
      );
      if (names.includes("bash")) {
        const count = prompts.length;
        assert.equal(
          (await gate(session, "bash", { command: "sudo --version" }))?.block,
          true,
        );
        await dispatch(session, "bash", { command: "true" });
        assert.equal(
          prompts.length,
          count,
          "explicit deny and allow skip the UI",
        );
      }
      if (name === "worker") {
        setDecision("approve");
        const pwd = await dispatch(session, "bash", { command: "pwd" });
        assert(
          pwd.content.some((part: any) => part.text?.trim() === process.cwd()),
        );
        const file = process.cwd() + "/native-worker.txt";
        await dispatch(session, "write", { path: file, content: "first" });
        await dispatch(session, "edit", {
          path: file,
          edits: [{ oldText: "first", newText: "second" }],
        });
        assert.equal(readFileSync(file, "utf8"), "second");
        setDecision("deny");
        const denied = process.cwd() + "/native-denied.txt";
        assert.equal(
          (await dispatch(session, "write", { path: denied, content: "no" }))
            .block,
          true,
        );
        assert(!existsSync(denied));
        setDecision("approve");
        const host = [...hosts().values()][0];
        host.active = false;
        assert.equal(
          (await gate(session, "write", { path: denied, content: "no" }))
            ?.block,
          true,
          "the SDK tool-call boundary rejects stale authority",
        );
        await assert.rejects(
          () => handle.prompt("must not contact a model"),
          /Guard/,
        );
        assert(!existsSync(denied), "dispatch-time parent loss leaves no file");
        host.active = true;
      }
    } finally {
      await handle.dispose();
    }
    assert.equal(getPermissionsService(handle.sessionId), undefined);
  }

  const launch = plan("worker").session;
  const siblings = await Promise.all([
    guarded.create(plan("worker").session),
    guarded.create(plan("reviewer").session),
  ]);
  await Promise.all(siblings.map(prepare));
  assert.notEqual(
    readLease(siblings[0].sessionId)?.generation,
    readLease(siblings[1].sessionId)?.generation,
    "concurrent children have separate bindings",
  );
  await siblings[0].dispose();
  assert(
    getPermissionsService(siblings[1].sessionId),
    "one sibling cleanup preserves the other",
  );
  await siblings[1].dispose();
  const source = process.cwd() + "/fork-source.jsonl";
  writeFileSync(source, JSON.stringify(root.sessionManager.getHeader()) + "\n");
  const fork = SessionManager.forkFrom(
    source,
    process.cwd(),
    process.cwd() + "/fork-sessions",
  );
  const forked = await guarded.create({
    ...launch,
    storage: { kind: "file", sessionFile: fork.getSessionFile()! },
    runtime: { ...launch.runtime, forkCacheKey: root.sessionId },
  });
  await prepare(forked);
  assert.notEqual(
    forked.sessionId,
    root.sessionId,
    "fresh fork retains distinct child identity",
  );
  const oldLease = readLease(forked.sessionId)!;
  await assert.rejects(
    () =>
      guarded.create({
        ...launch,
        storage: { kind: "file", sessionFile: fork.getSessionFile()! },
      }),
    /activation failed/,
    "concurrent resume cannot evict a live node",
  );
  assert.equal(readLease(forked.sessionId)?.generation, oldLease.generation);
  assert(getPermissionsService(forked.sessionId));
  await forked.dispose();
  const resumed = await guarded.create({
    ...launch,
    storage: { kind: "file", sessionFile: fork.getSessionFile()! },
  });
  await prepare(resumed);
  assert.equal(
    resumed.sessionId,
    forked.sessionId,
    "resume retains session history identity",
  );
  assert.notEqual(
    readLease(resumed.sessionId)?.generation,
    oldLease.generation,
    "resume creates fresh authority",
  );
  assert.throws(() => assertLeaseLive(oldLease), /generation ended/);
  await resumed.dispose();
  await assert.rejects(
    () =>
      guarded.create({
        ...launch,
        storage: { kind: "file", sessionFile: source },
      }),
    /activation failed/,
    "resuming the parent id cannot replace its service",
  );
  assert.equal(getPermissionsService(root.sessionId), rootService);
  const parentPlan = plan("worker", {
    tools: [...launch.tools!, "subagent", "subagent_supervisor"],
    allowNestedSubagents: true,
    maxSubagentDepth: 3,
  });
  const parent = await guarded.create(parentPlan.session);
  const parentSession = await prepare(parent);
  assert(
    parentSession.agent.state.tools.some(
      (tool: any) => tool.name === "subagent",
    ),
    "authorized fanout retains subagent tool",
  );
  const grandchildPlan = plan("worker", {
    parentSessionId: parent.sessionId,
    inherited: parentPlan.config,
    maxSubagentDepth: 3,
  });
  const grandchild = await guarded.create(grandchildPlan.session);
  const grandchildSession = await prepare(grandchild);
  assert.equal(
    (await gate(grandchildSession, "bash", { command: "pwd" }))?.block,
    undefined,
    "grandchild asks relay through headless parent to root",
  );
  assert.equal(
    (await gate(grandchildSession, "bash", { command: "sudo --version" }))
      ?.block,
    true,
  );
  await parent.dispose();
  assert.equal(
    (await gate(grandchildSession, "bash", { command: "true" }))?.block,
    true,
    "parent loss blocks even allow-state grandchild calls",
  );
  await grandchild.dispose();
  await assert.rejects(
    () =>
      guarded.create({
        ...launch,
        runtime: { ...launch.runtime, parentSessionId: randomUUID() },
      }),
    /declared parent/,
  );
  const unchangedEnv = await guarded.create({ ...launch, processEnv: {} });
  await unchangedEnv.dispose();
  await assert.rejects(
    () =>
      guarded.create({
        ...launch,
        runtime: { ...launch.runtime, depth: 4, maxDepth: 3 },
      }),
    /depth/,
  );
  const noProviderExtensions = await guarded.create({
    ...launch,
    runtime: { ...launch.runtime, capabilityCeiling: { denyExtensions: true } },
  });
  const noProviderSession = await prepare(noProviderExtensions);
  assert.equal(
    (
      await gate(noProviderSession, "read", {
        path: process.cwd() + "/secret.env",
      })
    )?.block,
    true,
    "the trusted native permission bridge remains active under a provider-extension ceiling",
  );
  await noProviderExtensions.dispose();
  const defaultLaunch = { ...launch, tools: undefined };
  const stockDefaults = await factory.create(defaultLaunch);
  const stockDefaultSession = sessions.find(
    (item: any) => item.sessionId === stockDefaults.sessionId,
  );
  const expectedDefaults = stockDefaultSession.agent.state.tools
    .map((tool: any) => tool.name)
    .sort();
  await stockDefaults.dispose();
  const guardedDefaults = await guarded.create(defaultLaunch);
  const defaultSession = await prepare(guardedDefaults);
  assert.deepEqual(
    defaultSession.agent.state.tools.map((tool: any) => tool.name).sort(),
    expectedDefaults,
    "omitted tools preserve stock SDK defaults",
  );
  await guardedDefaults.dispose();
  const powerShell = await guarded.create(
    plan("delegate", { tools: ["powershell"] }).session,
  );
  const powerShellSession = await prepare(powerShell);
  assert(
    powerShellSession.agent.state.tools.some(
      (tool: any) => tool.name === "powershell",
    ),
    "Guard does not remove a requested builtin",
  );
  assert.equal(
    (
      await gate(powerShellSession, "powershell", {
        command: "Write-Output test",
      })
    )?.block,
    undefined,
    "PowerShell follows the permission engine rather than a Guard inventory ban",
  );
  await powerShell.dispose();
  const optionalMissing = await guarded.create({
    ...launch,
    extensionPaths: ["/missing-extension.ts"],
  });
  await optionalMissing.dispose();
  const withoutGuard = createGuardedFactory({
    create: (value: any) =>
      factory.create({
        ...value,
        hooks: value.hooks.filter(
          (hook: any) => !hook.name.startsWith("pi-guard:"),
        ),
      }),
    dispose: () => factory.dispose(),
  });
  await assert.rejects(
    () => withoutGuard.create(launch),
    /activation failed/,
    "SDK success with missing guard never reaches the executor",
  );
  const brokenGuard = createGuardedFactory({
    create: (value: any) =>
      factory.create({
        ...value,
        hooks: value.hooks.map((hook: any) =>
          hook.name.startsWith("pi-guard:")
            ? {
                ...hook,
                factory: () => {
                  throw new Error("intentional guard load failure");
                },
              }
            : hook,
        ),
      }),
    dispose: () => factory.dispose(),
  });
  await assert.rejects(() => brokenGuard.create(launch), /activation failed/);
  assert.equal(
    getPermissionsService(root.sessionId),
    rootService,
    "failure cleanup preserves parent",
  );
  const modulePath = childSessionFactoryModule();
  assert(modulePath?.endsWith("runner.ts"));
  await assert.rejects(
    () =>
      loadRunnerChildSessionFactory({ childSessionFactoryModule: modulePath }),
    /detached subagent process/,
  );
  const installed = childSessionFactory();
  installChildSessionGuard();
  assert.equal(
    childSessionFactory(),
    installed,
    "repeated installs are idempotent",
  );
  await extensionBridgeChecks({
    root,
    guarded,
    plan,
    prepare,
    dispatch,
    gate,
    controls: input,
  });
  await executorChecks(root, discovered, {
    setDecision,
    eventBus: input.eventBus,
    setOnPrompt: input.setOnPrompt,
    prompts,
  });
  // Exercise Nico's real foreground executor, not only our wrapper in isolation.
  // Use an unknown model as a second no-network barrier if interception regresses.
  const result = await runSync(
    process.cwd(),
    discovered,
    "worker",
    "do not execute",
    {
      parentSessionId: randomUUID(),
      modelOverride: "guard-offline/absent",
      modelOverrideFromParent: true,
      context: "fresh",
      sessionEnabled: false,
      artifactConfig: { enabled: false },
    } as any,
  );
  assert.notEqual(result.exitCode, 0);
  assert(
    (result.error ?? result.finalOutput ?? "").includes("no live binding"),
    `actual executor hits installed guard: ${result.error ?? result.finalOutput}`,
  );
  assert.equal(
    [...hosts().values()][0].children.size,
    0,
    "native factory probes leave no bound children",
  );
  console.log(
    JSON.stringify({
      childSessionGuard: true,
      roles,
      nativeUiPrompts: prompts.length,
      checks: [
        "native role/tool preservation",
        "fresh fork, resume and concurrent sibling isolation",
        "nested ask relay and ancestor loss",
        "canonical deny/allow/ask forwarding",
        "dispatch-time parent loss",
        "missing/broken guard rejection",
        "runner module rejects the wrong host process",
        "actual runSync factory interception",
      ],
    }),
  );
  return () =>
    assert.rejects(
      () => childSessionFactory().create(launch),
      /declared parent/,
      "shutdown never restores an unguarded default factory",
    );
}
