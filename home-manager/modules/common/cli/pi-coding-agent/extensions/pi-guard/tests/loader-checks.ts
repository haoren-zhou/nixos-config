// Regression: load package and adapter through separate REAL Pi loader calls.
// Never import their factories or execution helpers into this test's module graph.
import assert from "node:assert/strict";
import { createServer } from "node:http";
import {
  readFileSync,
  writeFileSync,
  readdirSync,
  mkdirSync,
  symlinkSync,
  lstatSync,
  unlinkSync,
} from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { randomUUID } from "node:crypto";
import * as sdk from "@earendil-works/pi-coding-agent";
import { dependencyPath } from "../dependencies.ts";

export default function (pi: sdk.ExtensionAPI) {
  pi.registerCommand("guard-loader-test", {
    handler: async () => {
      let root: any;
      let registration: any;
      const errors: any[] = [];
      const prompts: string[] = [];
      const notices: string[] = [];
      const turns: any[] = [];
      const tuiMode = process.env.PI_GUARD_TEST_UI === "tui";
      const headlessMode = process.env.PI_GUARD_TEST_HEADLESS === "1";
      const yoloMode = process.env.PI_GUARD_TEST_YOLO === "true";
      const symlinkDeployment = process.env.PI_GUARD_TEST_LINKS === "true";
      const missingDependency = process.env.PI_GUARD_TEST_MISSING_DEPENDENCY;
      const brokenDependency = process.env.PI_GUARD_TEST_BROKEN_DEPENDENCY;
      const alternateVersions =
        process.env.PI_GUARD_TEST_ALTERNATE_VERSIONS === "true";
      let holdNext = false;
      let held: ((key: string) => void) | undefined;
      const nextDecisions: string[] = [];
      let activeDialogs = 0;
      const server = createServer((req, res) => {
        let body = "";
        req.on("data", (data) => {
          body += data;
          if (body.length > 1_000_000) req.destroy();
        });
        req.on("end", () => {
          try {
            const input = JSON.parse(body);
            const child = input.messages.some(
              (m: any) =>
                m.role === "system" &&
                JSON.stringify(m.content).includes("<active_agent "),
            );
            if (child) turns.push(input);
            assert(turns.length <= 100);
            const lastUser = input.messages.findLastIndex(
              (m: any) => m.role === "user",
            );
            const task = JSON.stringify(input.messages[lastUser]?.content);
            const text = input.messages
              .map((m: any) =>
                typeof m.content === "string"
                  ? m.content
                  : JSON.stringify(m.content),
              )
              .join("\n");
            const coordinator = text.includes(
              '<active_agent name="guard-loader-coordinator"',
            );
            const done = (
              coordinator ? input.messages : input.messages.slice(lastUser)
            ).some((m: any) => m.role === "tool");
            const command = task.includes("PROBE_ASK")
              ? "pwd"
              : task.includes("PROBE_DENY")
                ? "printf 'loader-denied\\n'"
                : "sudo --version";
            res.writeHead(200, { "Content-Type": "text/event-stream" });
            const chunk = (delta: any, finish_reason: string | null) =>
              res.write(
                `data: ${JSON.stringify({ id: "fixture", object: "chat.completion.chunk", created: 1, model: "fixture", choices: [{ index: 0, delta, finish_reason }] })}\n\n`,
              );
            // Native completion notifications can wake the fixture root too.
            // Acknowledge those without tool calls; count only actual child turns.
            if (!child || done)
              chunk({ role: "assistant", content: "Probe complete." }, "stop");
            else {
              chunk(
                {
                  role: "assistant",
                  tool_calls: [
                    {
                      index: 0,
                      id: "fixture_" + turns.length,
                      type: "function",
                      function: {
                        name: coordinator ? "subagent" : "bash",
                        arguments: JSON.stringify(
                          coordinator
                            ? {
                                agent: "delegate",
                                task: task.includes("PROBE_DENY")
                                  ? "Read-only PROBE_DENY"
                                  : "Read-only PROBE_ASK",
                                model: "guard-test/fixture",
                                async: task.includes("NESTED_ASYNC"),
                                context: "fresh",
                                acceptance: false,
                                timeoutMs: 15000,
                              }
                            : { command },
                        ),
                      },
                    },
                  ],
                },
                null,
              );
              chunk({}, "tool_calls");
            }
            res.end("data: [DONE]\n\n");
          } catch (error) {
            res.writeHead(500);
            res.end(String(error));
          }
        });
      });
      try {
        sdk.initTheme("dark");
        await new Promise<void>((resolve) =>
          server.listen(0, "127.0.0.1", resolve),
        );
        const agentDir = process.env.PI_CODING_AGENT_DIR!;
        const port = (server.address() as any).port;
        writeFileSync(
          agentDir + "/models.json",
          JSON.stringify({
            providers: {
              "guard-test": {
                baseUrl: `http://127.0.0.1:${port}/v1`,
                api: "openai-completions",
                apiKey: "fixture-only",
                models: [{ id: "fixture", reasoning: false, maxTokens: 512 }],
              },
            },
          }),
        );
        const upstream = dependencyPath("pi-subagents", ".");
        const upstreamEntry = dependencyPath("pi-subagents", "index.ts");
        let adapter = fileURLToPath(new URL("../index.ts", import.meta.url));
        if (symlinkDeployment) {
          // Home Manager creates per-file symlinks into immutable source.
          const source = dirname(adapter);
          const deployed = join(agentDir, "extensions", "pi-guard");
          mkdirSync(deployed, { recursive: true });
          for (const name of readdirSync(source).filter(
            (name) =>
              name.endsWith(".ts") ||
              name === "package.json" ||
              name === "node_modules",
          )) {
            symlinkSync(join(source, name), join(deployed, name));
          }
          adapter = join(deployed, "index.ts");
        }
        const permissions = dependencyPath(
          "@gotgenes/pi-permission-system",
          "src/index.ts",
        );
        if (missingDependency || brokenDependency || alternateVersions) {
          const plugins = [
            "pi-subagents",
            "@gotgenes/pi-permission-system",
          ] as const;
          const bad = missingDependency ?? brokenDependency;
          if (bad) assert((plugins as readonly string[]).includes(bad));
          const modules = join(agentDir, "npm", "node_modules");
          const fixture = new Map(
            plugins.map((name) => [name, dependencyPath(name, ".")]),
          );
          // Replace only the disposable fixture symlink, never the real npm tree.
          assert(lstatSync(modules).isSymbolicLink());
          unlinkSync(modules);
          mkdirSync(modules);
          for (const [name, root] of fixture) {
            const target = join(modules, name);
            if (name === missingDependency) continue;
            mkdirSync(dirname(target), { recursive: true });
            if (name === brokenDependency || alternateVersions) {
              mkdirSync(target);
              const manifest = JSON.parse(
                readFileSync(join(root, "package.json"), "utf8"),
              );
              // Version strings alone must not reject an otherwise working plugin.
              writeFileSync(
                join(target, "package.json"),
                JSON.stringify({ ...manifest, version: "999.0.0" }),
              );
              if (name !== brokenDependency) {
                for (const entry of readdirSync(root).filter(
                  (entry) => entry !== "package.json",
                )) {
                  symlinkSync(join(root, entry), join(target, entry));
                }
              }
            } else symlinkSync(root, target);
          }
        }
        const loaderMode = process.env.PI_GUARD_LOADER_MODE;
        const separate = ["separate", "nico-first"].includes(loaderMode ?? "");
        const nicoFirst = loaderMode === "nico-first";
        const settings = sdk.SettingsManager.inMemory({
          packages: [
            {
              source: upstream,
              ...(!separate || nicoFirst ? { extensions: [] } : {}),
            },
          ],
          compaction: { enabled: false },
        });
        const guardedPaths =
          process.env.PI_GUARD_TEST_ORDER === "guard-first"
            ? [adapter, permissions]
            : [permissions, adapter];
        const paths = nicoFirst
          ? [upstreamEntry, ...guardedPaths]
          : guardedPaths;
        const bus = sdk.createEventBus();
        const loader = new sdk.DefaultResourceLoader({
          cwd: process.cwd(),
          agentDir,
          settingsManager: settings,
          eventBus: bus,
          additionalExtensionPaths: paths,
          noSkills: true,
          noContextFiles: true,
          noThemes: true,
          noPromptTemplates: true,
        });
        await loader.reload();
        const loadErrors = loader.getExtensions().errors;
        if (missingDependency || brokenDependency) {
          assert(
            loadErrors.some((error: any) => error.path === adapter),
            JSON.stringify(loadErrors),
          );
          assert(
            !loader
              .getExtensions()
              .extensions.some((extension: any) => extension.path === adapter),
          );
          ({ session: root } = await sdk.createAgentSession({
            cwd: process.cwd(),
            agentDir,
            resourceLoader: loader,
            settingsManager: settings,
            sessionManager: sdk.SessionManager.create(
              process.cwd(),
              agentDir + "/sessions",
            ),
            tools: ["subagent"],
          }));
          assert(
            !root.agent.state.tools.some(
              (tool: any) => tool.name === "subagent",
            ),
            "missing dependencies must not expose an unguarded dispatcher",
          );
          assert.equal(turns.length, 0);
          console.log(
            JSON.stringify({
              missingDependency,
              brokenDependency,
              failClosed: true,
              modelRequests: 0,
            }),
          );
          return;
        }
        if (separate) {
          assert(
            loadErrors.length > 0,
            "duplicate loading must report a conflict",
          );
          const conflictOwner = nicoFirst ? adapter : upstreamEntry;
          assert(
            loadErrors.every(
              (error: any) =>
                error.path === conflictOwner &&
                error.error.includes("conflicts"),
            ),
            JSON.stringify(loadErrors),
          );
        } else assert.deepEqual(loadErrors, []);
        console.log(
          "LOADED " +
            JSON.stringify(
              loader.getExtensions().extensions.map((e: any) => e.path),
            ),
        );
        ({ session: root } = await sdk.createAgentSession({
          cwd: process.cwd(),
          agentDir,
          resourceLoader: loader,
          settingsManager: settings,
          sessionManager: sdk.SessionManager.create(
            process.cwd(),
            agentDir + "/sessions",
          ),
          tools: ["subagent"],
        }));
        const uiContext = {
          custom: (factory: any) =>
            new Promise((resolve, reject) => {
              try {
                assert.equal(
                  activeDialogs++,
                  0,
                  "root inline dialogs must never overlap",
                );
                const theme = {
                  fg: (_c: string, t: string) => t,
                  bg: (_c: string, t: string) => t,
                  bold: (t: string) => t,
                };
                let settled = false;
                const component = factory(
                  { requestRender() {} },
                  theme,
                  { matches: () => false },
                  (value: any) => {
                    if (settled) return;
                    settled = true;
                    activeDialogs--;
                    resolve(value);
                  },
                );
                const text = component.render(120).join("\n");
                prompts.push(text);
                const answer = (key: string) => {
                  component.handleInput(key);
                  if (!settled) component.handleInput(key); // default double-press confirmation
                };
                if (holdNext) {
                  holdNext = false;
                  held = answer;
                } else
                  queueMicrotask(() =>
                    answer(
                      nextDecisions.shift() ??
                        (text.includes("printf") ? "n" : "y"),
                    ),
                  );
              } catch (error) {
                reject(error);
              }
            }),
          confirm: async () => false,
          input: async () => undefined,
          editor: async () => undefined,
          select: async (title: string, choices: string[]) => {
            prompts.push(title);
            const answer = title.includes("printf") ? "No" : "Yes";
            assert(choices.includes(answer));
            return answer;
          },
          notify: (message: string) => notices.push(message),
          setStatus() {},
          setWidget() {},
          setTitle() {},
          setWorkingMessage() {},
          setWorkingIndicator() {},
          setEditorText() {},
          getToolsExpanded: () => false,
          setToolsExpanded() {},
          setWorkingVisible() {},
          getEditorText: () => "",
        } as any;
        await root.bindExtensions({
          mode: tuiMode ? "tui" : headlessMode ? "print" : "rpc",
          onError: (error: any) => errors.push(error),
          uiContext,
        });
        if (separate) {
          assert(
            notices.some((message) =>
              message.includes("duplicate or unguarded"),
            ),
            "misconfiguration must not report ready",
          );
          const gate = await root.extensionRunner.emitToolCall({
            type: "tool_call",
            toolCallId: "duplicate-probe",
            toolName: "subagent",
            input: { agent: "delegate", task: "Read-only probe", async: false },
          });
          assert(
            gate?.block,
            "duplicate loader configuration must block model dispatch",
          );
          assert.equal(turns.length, 0);
          const direct = root.agent.state.tools.find(
            (tool: any) => tool.name === "subagent",
          );
          assert(
            direct,
            "standalone Nico dispatcher must be present in fixture",
          );
          await assert.rejects(
            async () =>
              direct.execute(randomUUID(), {
                agent: "delegate",
                task: "Direct invocation must fail closed",
                async: false,
              }),
            /not allowed|capability ceiling|(?:Pi )?Guard/i,
          );
          assert.equal(
            turns.length,
            0,
            "direct invocation must not reach a model",
          );
          console.log(
            JSON.stringify({
              duplicateEntryRejected: true,
              loaderMode,
              headlessMode,
            }),
          );
          return;
        }
        // Actual registered dispatcher: no imported execution helper or factory.
        const execute = (params: any) =>
          root.agent.state.tools
            .find((t: any) => t.name === "subagent")
            .execute(randomUUID(), params);
        const wait = (dir: string) =>
          new Promise<any>((resolve, reject) => {
            const deadline = Date.now() + 30000;
            const timer = setInterval(() => {
              try {
                const status = JSON.parse(
                  readFileSync(join(dir, "status.json"), "utf8"),
                );
                if (
                  !["running", "queued"].includes(status.state) &&
                  (status.mode === "workflow" ||
                    status.processTerminal?.state === "observed")
                ) {
                  clearInterval(timer);
                  resolve(status);
                } else if (Date.now() > deadline)
                  throw new Error("Timeout waiting for " + dir);
              } catch (error) {
                clearInterval(timer);
                reject(error);
              }
            }, 100);
          });
        if (tuiMode && !yoloMode) {
          // A real detached permission request overlaps a local root tool gate.
          // No model-driven status inspection or live human policy is involved.
          holdNext = true;
          const before = prompts.length;
          const response = await execute({
            agent: "delegate",
            task: "Read-only PROBE_ASK overlap",
            model: "guard-test/fixture",
            async: true,
            context: "fresh",
            acceptance: false,
            timeoutMs: 15000,
          });
          assert(response.details?.asyncDir, JSON.stringify(response));
          const deadline = Date.now() + 10000;
          while (!held) {
            assert(
              Date.now() < deadline,
              `detached ask did not reach root UI: ${JSON.stringify(response)}`,
            );
            await new Promise((resolve) => setTimeout(resolve, 25));
          }
          nextDecisions.push("n");
          const parentAsk = root.extensionRunner.emitToolCall({
            type: "tool_call",
            toolCallId: "overlapping-status",
            toolName: "subagent",
            input: { action: "status" },
          });
          await new Promise((resolve) => setTimeout(resolve, 25));
          assert.equal(
            prompts.length,
            before + 1,
            "parent status approval waits behind detached pwd approval",
          );
          held("y");
          held = undefined;
          const denied = await parentAsk;
          assert(
            denied?.block,
            "parent denial must not be consumed by the approved child",
          );
          const status = await wait(response.details.asyncDir);
          assert.equal(status.state, "complete", JSON.stringify(status));
          assert.equal(prompts.length, before + 2);
        }
        let resumable: any;
        for (const workflow of [false, true])
          for (const background of [false, true])
            for (const probe of ["POLICY", "ASK", "DENY"]) {
              const before = turns.length;
              const beforePrompts = prompts.length;
              const params = {
                agent: "delegate",
                task: `Read-only PROBE_${probe}: make one fixture tool call.`,
                model: "guard-test/fixture",
                async: background,
                context: "fresh",
                acceptance: false,
                timeoutMs: 15000,
              };
              const workflowPath = join(process.cwd(), "probe-workflow.js");
              if (workflow) {
                writeFileSync(
                  workflowPath,
                  `return await runs.run('probe', ${JSON.stringify(params)});`,
                );
              }
              const response = await execute(
                workflow
                  ? {
                      workflow: workflowPath,
                      async: true,
                      mission: false,
                    }
                  : params,
              );
              let status: any;
              let runId: string | undefined;
              if (workflow) {
                assert(response.details?.asyncDir, JSON.stringify(response));
                const flow = await wait(response.details.asyncDir);
                assert.equal(flow.state, "complete", JSON.stringify(flow));
                runId = flow.steps[0].runId;
                if (background)
                  status = await wait(
                    join(dirname(response.details.asyncDir), runId!),
                  );
              } else if (background) {
                runId = response.details?.asyncId;
                status = await wait(response.details.asyncDir);
              } else
                assert.equal(
                  response.details?.results?.[0]?.exitCode,
                  0,
                  JSON.stringify(response),
                );
              if (status) {
                assert.equal(status.state, "complete", JSON.stringify(status));
                resumable = { runId, status };
              }
              const messages = turns
                .slice(before)
                .flatMap((turn) => turn.messages)
                .filter((m) => m.role === "tool");
              const expected =
                probe === "POLICY"
                  ? "Denied by policy"
                  : probe === "DENY"
                    ? yoloMode
                      ? "loader-denied"
                      : "user denied"
                    : process.cwd();
              assert(
                messages.some((m) =>
                  probe === "POLICY"
                    ? /Denied by policy|policy rule .* denied/.test(
                        JSON.stringify(m.content),
                      )
                    : JSON.stringify(m.content).includes(expected),
                ),
                `workflow=${workflow} background=${background} ${probe}: ${JSON.stringify(messages)}`,
              );
              assert.equal(
                turns.length - before,
                2,
                `real model/tool round trip ${workflow}/${background}/${probe}: ${JSON.stringify(turns.slice(before).map((turn) => turn.messages.filter((m: any) => m.role === "user")))}`,
              );
              assert.equal(
                prompts.length - beforePrompts,
                yoloMode || probe === "POLICY" ? 0 : 1,
                "YOLO and policy denials never prompt; Guard asks once",
              );
            }
        const beforeResume = turns.length;
        const resumed = await execute({
          action: "resume",
          id: resumable.runId,
          message: "Read-only PROBE_ASK: make another fixture tool call.",
        });
        assert(resumed.details?.asyncDir, JSON.stringify(resumed));
        const status = await wait(resumed.details.asyncDir);
        assert.equal(status.state, "complete", JSON.stringify(status));
        assert.equal(turns.length - beforeResume, 2);
        const history = readFileSync(status.steps[0].sessionFile, "utf8")
          .trim()
          .split("\n")
          .map((line) => JSON.parse(line));
        assert.equal(
          history.filter((e) => e.message?.role === "toolResult").length,
          2,
          "actual resume retains prior history",
        );
        const request: any = {
          version: 1,
          name: "guard-loader-coordinator",
          definition: {
            description: "Disposable real-loader fanout fixture",
            systemPrompt: "Perform the single fixture delegation.",
            tools: [
              "read",
              "bash",
              "subagent",
              "contact_supervisor",
              "subagent_supervisor",
            ],
            defaultContext: "fresh",
            inheritProjectContext: false,
            inheritGlobalContext: false,
            inheritSkills: false,
          },
        };
        bus.emit("pi-subagents:runtime-agent-register:v1", request);
        assert(request.result?.ok, JSON.stringify(request.result));
        registration = request.result.registration;
        for (const [outer, inner, deny] of [
          [false, false, false],
          [false, true, false],
          [true, false, false],
          [true, true, false],
          [true, true, true],
        ]) {
          const before = turns.length;
          const beforePrompts = prompts.length;
          const response = await execute({
            agent: "guard-loader-coordinator",
            task: `${inner ? "NESTED_ASYNC" : "NESTED_FOREGROUND"} PROBE_${deny ? "DENY" : "ASK"}`,
            model: "guard-test/fixture",
            async: outer,
            context: "fresh",
            acceptance: false,
            timeoutMs: 25000,
          });
          if (outer) {
            assert(response.details?.asyncDir, JSON.stringify(response));
            const status = await wait(response.details.asyncDir);
            assert.equal(status.state, "complete", JSON.stringify(status));
          } else
            assert.equal(
              response.details?.results?.[0]?.exitCode,
              0,
              JSON.stringify(response),
            );
          const leaf = turns
            .slice(before)
            .filter(
              (turn) =>
                !turn.messages.some(
                  (m: any) =>
                    m.role === "system" &&
                    JSON.stringify(m.content).includes(
                      "guard-loader-coordinator",
                    ),
                ),
            );
          assert.equal(
            leaf.length,
            2,
            "nested leaf finishes a real model/tool round trip",
          );
          assert(
            leaf.some((turn) =>
              turn.messages.some(
                (m: any) =>
                  m.role === "tool" &&
                  JSON.stringify(m.content).includes(
                    deny
                      ? yoloMode
                        ? "loader-denied"
                        : "user denied"
                      : process.cwd(),
                  ),
              ),
            ),
          );
          assert.equal(
            prompts.length - beforePrompts,
            yoloMode ? 0 : 2,
            "spawn and leaf asks respect root Guard/YOLO mode through the live chain",
          );
        }
        registration.dispose();
        registration = undefined;
        const beforeReload = turns.length;
        await root.reload();
        const reloaded = await execute({
          agent: "delegate",
          task: "Read-only PROBE_POLICY: one fixture call after real reload.",
          model: "guard-test/fixture",
          async: false,
          acceptance: false,
          timeoutMs: 15000,
        });
        assert.equal(
          reloaded.details?.results?.[0]?.exitCode,
          0,
          JSON.stringify(reloaded),
        );
        assert(
          turns
            .slice(beforeReload)
            .some((turn) =>
              turn.messages.some(
                (m: any) =>
                  m.role === "tool" &&
                  /Denied by policy|policy rule .* denied/.test(
                    JSON.stringify(m.content),
                  ),
              ),
            ),
          "new loader graph retains enforcement after reload",
        );
        const promptsAfterReload = prompts.length;
        const reloadedAsk = await execute({
          agent: "delegate",
          task: "Read-only PROBE_ASK after reload",
          model: "guard-test/fixture",
          async: false,
          acceptance: false,
          timeoutMs: 15000,
        });
        assert.equal(
          reloadedAsk.details?.results?.[0]?.exitCode,
          0,
          JSON.stringify(reloadedAsk),
        );
        assert.equal(
          prompts.length,
          promptsAfterReload + (yoloMode ? 0 : 1),
          "Guard/YOLO remains usable after reload",
        );
        // Pi replaces AgentSession for these operations. Exercise the actual
        // runtime factory/rebind lifecycle, not a manually emitted start event.
        const runtime = await sdk.createAgentSessionRuntime(
          async ({ cwd, sessionManager, sessionStartEvent }) => {
            const services = await sdk.createAgentSessionServices({
              cwd,
              agentDir,
              settingsManager: sdk.SettingsManager.inMemory({
                packages: [{ source: upstream, extensions: [] }],
                compaction: { enabled: false },
              }),
              resourceLoaderOptions: {
                additionalExtensionPaths: guardedPaths,
                noSkills: true,
                noContextFiles: true,
                noThemes: true,
                noPromptTemplates: true,
              },
            });
            assert.deepEqual(
              services.resourceLoader.getExtensions().errors,
              [],
            );
            return {
              ...(await sdk.createAgentSessionFromServices({
                services,
                sessionManager,
                sessionStartEvent,
                tools: ["subagent"],
              })),
              services,
              diagnostics: services.diagnostics,
            };
          },
          {
            cwd: process.cwd(),
            agentDir,
            sessionManager: sdk.SessionManager.create(
              process.cwd(),
              agentDir + "/sessions",
            ),
          },
        );
        const bindReplacement = async (session: sdk.AgentSession) => {
          await session.bindExtensions({
            mode: "rpc",
            uiContext,
            onError: (error: any) => errors.push(error),
          });
        };
        runtime.setRebindSession(bindReplacement);
        try {
          await bindReplacement(runtime.session);
          const entryId = runtime.session.sessionManager.appendMessage({
            role: "user",
            content: "Session replacement fixture",
            timestamp: Date.now(),
          });
          const originalFile = runtime.session.sessionFile!;
          for (const replace of [
            () => runtime.newSession(),
            () => runtime.switchSession(originalFile),
            () => runtime.fork(entryId),
            () => runtime.importFromJsonl(originalFile),
          ]) {
            const previous = runtime.session;
            const oldTool = previous.agent.state.tools.find(
              (tool: any) => tool.name === "subagent",
            )!;
            const outcome = await replace();
            assert.equal(outcome.cancelled, false);
            assert.notEqual(runtime.session, previous);
            const beforeStale = turns.length;
            await assert.rejects(
              async () =>
                oldTool.execute(randomUUID(), {
                  agent: "delegate",
                  task: "Read-only PROBE_ASK from stale root",
                  model: "guard-test/fixture",
                  async: false,
                  acceptance: false,
                }),
              /Guard|session|context|binding|lease|unavailable|inactive/i,
            );
            assert.equal(
              turns.length,
              beforeStale,
              "old root cannot launch after replacement",
            );
            for (const probe of ["POLICY", "ASK"]) {
              const before = turns.length;
              const tool = runtime.session.agent.state.tools.find(
                (tool: any) => tool.name === "subagent",
              )!;
              const response = await tool.execute(randomUUID(), {
                agent: "delegate",
                task: `Read-only PROBE_${probe} after replacement`,
                model: "guard-test/fixture",
                async: false,
                acceptance: false,
                timeoutMs: 15000,
              });
              assert.equal(
                response.details?.results?.[0]?.exitCode,
                0,
                JSON.stringify(response),
              );
              assert(
                turns
                  .slice(before)
                  .some((turn) =>
                    turn.messages.some(
                      (message: any) =>
                        message.role === "tool" &&
                        (probe === "POLICY"
                          ? /Denied by policy|policy rule .* denied/.test(
                              JSON.stringify(message.content),
                            )
                          : JSON.stringify(message.content).includes(
                              process.cwd(),
                            )),
                    ),
                  ),
                "fresh replacement root retains policy and approval forwarding",
              );
            }
          }
        } finally {
          await runtime.dispose();
        }
        const oldKey = Symbol.for("hr.pi-guard-prototype.normal-factory.v3");
        const globals = globalThis as any;
        assert(!globals[oldKey]);
        globals[oldKey] = {};
        try {
          await assert.rejects(
            async () =>
              execute({
                agent: "delegate",
                task: "Read-only PROBE_POLICY",
                async: false,
              }),
            /restart Pi/,
          );
          const previousErrors = errors.length;
          await root.prompt("/subagents-guide");
          assert.equal(
            errors.length,
            previousErrors + 1,
            "slash-command dispatch also rejects an incompatible retained factory",
          );
          assert(String(errors.pop().error).includes("restart Pi"));
        } finally {
          delete globals[oldKey];
        }
        assert.deepEqual(errors, []);
        console.log(
          JSON.stringify({
            loaderRegression: true,
            alternateVersions,
            tuiMode,
            headlessMode,
            yoloMode,
            symlinkDeployment,
            overlappingForwardedAndRootAsks: tuiMode && !yoloMode,
            packageFiltered: true,
            directAndWorkflowForegroundBackground: true,
            resumed: true,
            realReload: true,
            sessionReplacement: ["new", "switch", "fork", "import"],
            allNestedModes: true,
            nestedDenial: !yoloMode,
            requests: turns.length,
            prompts: prompts.length,
          }),
        );
      } catch (error) {
        console.error(error);
        console.error("Extension errors:", errors);
        process.exitCode = 1;
      } finally {
        registration?.dispose();
        if (root) {
          await root.extensionRunner?.emit({ type: "session_shutdown" });
          root.dispose();
          const leases = process.env.PI_CODING_AGENT_DIR + "/pi-guard/leases";
          try {
            assert.deepEqual(
              readdirSync(leases),
              [],
              "real loader generations cleaned up",
            );
          } catch (error) {
            if ((error as any).code !== "ENOENT") throw error;
          }
        }
        server.closeAllConnections();
        await new Promise<void>((resolve) => server.close(() => resolve()));
      }
    },
  });
}
