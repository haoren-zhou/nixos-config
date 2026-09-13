import assert from "node:assert/strict";
import { createServer } from "node:http";
import { writeFileSync, unlinkSync, readFileSync, existsSync } from "node:fs";
import { randomUUID, createHash } from "node:crypto";
import {
  createReadToolDefinition,
  createBashToolDefinition,
  createEditToolDefinition,
  createWriteToolDefinition,
  createGrepToolDefinition,
  createFindToolDefinition,
  createLsToolDefinition,
} from "@earendil-works/pi-coding-agent";
import {
  readLease,
  acquireLease,
  releaseLease,
  assertLeaseLive,
} from "../leases.ts";
import { dependencyPath } from "../dependencies.ts";
const { runSync } = await import(
  dependencyPath("pi-subagents", "src/runs/foreground/execution.ts")
);
import { REGISTER } from "../shared.ts";
import { writeBridgeFixture } from "./extension-bridge-checks.ts";

export async function executorChecks(
  root: any,
  discovered: any[],
  controls: any,
) {
  const requests: any[] = [];
  const server = createServer((req, res) => {
    let body = "";
    req.on("data", (data) => {
      body += data;
      if (body.length > 1_000_000) req.destroy();
    });
    req.on("end", () => {
      try {
        const input = JSON.parse(body);
        requests.push(input);
        assert(requests.length <= 80, "bounded scripted model turns");
        const text = input.messages
          .map((m: any) =>
            typeof m.content === "string"
              ? m.content
              : JSON.stringify(m.content),
          )
          .join("\n");
        const role = text.match(/<active_agent name="([^"]+)"/)?.[1];
        assert(
          [
            "delegate",
            "worker",
            "reviewer",
            "guard-fixture-coordinator",
            "guard-fixture-extensions",
          ].includes(role!),
        );
        const lastUser = input.messages.findLastIndex(
          (m: any) => m.role === "user",
        );
        const tail = input.messages.slice(lastUser);
        const userText = JSON.stringify(tail[0]?.content);
        const coordinator = role === "guard-fixture-coordinator";
        let done = (coordinator ? input.messages : tail).some(
          (m: any) => m.role === "tool",
        );
        let name = role === "reviewer" ? "read" : "bash";
        let args: any =
          role === "reviewer"
            ? { path: process.cwd() + "/native-worker.txt" }
            : { command: role === "worker" ? "sudo --version" : "pwd" };
        if (userText.includes("NAMED_TOOLS")) {
          const file = process.cwd() + "/named-tools.txt";
          const calls = [
            ["write", { path: file, content: "first\n" }],
            [
              "edit",
              { path: file, edits: [{ oldText: "first", newText: "second" }] },
            ],
            ["read", { path: file }],
            [
              "grep",
              {
                pattern: "second",
                path: process.cwd(),
                glob: "named-tools.txt",
              },
            ],
            ["find", { pattern: "named-tools.txt", path: process.cwd() }],
            ["ls", { path: process.cwd() }],
            ["bash", { command: "pwd" }],
          ] as const;
          const step = tail.filter(
            (message: any) => message.role === "tool",
          ).length;
          done = step >= calls.length;
          [name, args] = calls[Math.min(step, calls.length - 1)];
        }
        if (userText.includes("EXTENSION_NESTED")) {
          name = "bridge_nested";
          args = {
            destination: process.cwd() + "/extension-dispatch.txt",
            content: "nested extension",
          };
        }
        if (userText.includes("EXTENSION_MEMORY")) {
          name = "memory_search";
          args = { query: "disposable bridge fixture" };
        }
        if (userText.includes("DENY_WRITE")) {
          name = "write";
          args = {
            path: process.cwd() + "/remote-denied.txt",
            content: "must not exist",
          };
        }
        if (userText.includes("STALE_WRITE")) {
          name = "write";
          args = {
            path: process.cwd() + "/remote-stale.txt",
            content: "must not exist",
          };
        }
        if (coordinator) {
          name = "subagent";
          args = {
            agent: "delegate",
            task: "Read-only NESTED_LEAF fixture: perform one tool call and report completion.",
            model: "guard-test/fixture",
            async: text.includes("NESTED_ASYNC"),
            context: "fresh",
            acceptance: false,
            timeoutMs: 15000,
          };
        }
        res.writeHead(200, { "Content-Type": "text/event-stream" });
        const chunk = (delta: any, finish_reason: string | null) =>
          res.write(
            `data: ${JSON.stringify({
              id: "guard-fixture",
              object: "chat.completion.chunk",
              created: 1,
              model: "fixture",
              choices: [{ index: 0, delta, finish_reason }],
            })}\n\n`,
          );
        if (done)
          chunk(
            { role: "assistant", content: "Guard fixture complete." },
            "stop",
          );
        else {
          chunk(
            {
              role: "assistant",
              tool_calls: [
                {
                  index: 0,
                  id: "fixture_" + requests.length,
                  type: "function",
                  function: { name, arguments: JSON.stringify(args) },
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
  await new Promise<void>((resolve, reject) => {
    server.once("error", reject);
    server.listen(0, "127.0.0.1", resolve);
  });
  const address = server.address() as { port: number };
  const path = process.env.PI_CODING_AGENT_DIR + "/models.json";
  writeFileSync(
    path,
    JSON.stringify({
      providers: {
        "guard-test": {
          baseUrl: `http://127.0.0.1:${address.port}/v1`,
          api: "openai-completions",
          apiKey: "fixture-only",
          models: [{ id: "fixture", reasoning: false, maxTokens: 512 }],
        },
      },
    }),
    { flag: "wx" },
  );
  let registration: any;
  let extensionRegistration: any;
  const completed: string[] = [];
  const wait = (dir: string) =>
    new Promise<any>((resolve, reject) => {
      const start = Date.now();
      const timer = setInterval(() => {
        try {
          const value = JSON.parse(readFileSync(dir + "/status.json", "utf8"));
          if (
            !["queued", "running"].includes(value.state) &&
            value.processTerminal?.state === "observed"
          ) {
            clearInterval(timer);
            resolve(value);
          } else if (Date.now() - start > 30000) {
            clearInterval(timer);
            reject(new Error("async fixture timed out: " + dir));
          }
        } catch (error) {
          clearInterval(timer);
          reject(error);
        }
      }, 100);
    });
  try {
    const extensionFixture = writeBridgeFixture();
    const hermes =
      process.env.PI_CODING_AGENT_DIR +
      "/npm/node_modules/pi-hermes-memory/src/index.ts";
    const extensionRequest: any = {
      version: 1,
      name: "guard-fixture-extensions",
      definition: {
        description: "Disposable extension tool dispatcher fixture",
        systemPrompt:
          "Perform the requested fixture tool call and report completion.",
        tools: [
          "bridge_nested",
          "bridge_touch",
          ...(existsSync(hermes) ? ["memory_search"] : []),
        ],
        subagentOnlyExtensions: [
          extensionFixture,
          ...(existsSync(hermes) ? [hermes] : []),
        ],
        defaultContext: "fresh",
        inheritProjectContext: false,
        inheritGlobalContext: false,
        inheritSkills: false,
      },
    };
    controls.eventBus.emit(REGISTER, extensionRequest);
    assert(
      extensionRequest.result?.ok,
      JSON.stringify(extensionRequest.result),
    );
    extensionRegistration = extensionRequest.result.registration;
    const dispatcher = root.agent.state.tools.find(
      (tool: any) => tool.name === "subagent",
    );
    for (const background of [false, true]) {
      for (const probe of [
        "EXTENSION_NESTED",
        ...(existsSync(hermes) ? ["EXTENSION_MEMORY"] : []),
      ]) {
        const before = requests.length;
        const beforePrompts = controls.prompts.length;
        const response = await dispatcher.execute(randomUUID(), {
          agent: "guard-fixture-extensions",
          task: probe + " fixture",
          model: "guard-test/fixture",
          async: background,
          context: "fresh",
          acceptance: false,
          timeoutMs: 30000,
        });
        if (background) {
          assert(response.details?.asyncDir, JSON.stringify(response));
          const status = await wait(response.details.asyncDir);
          assert.equal(status.state, "complete", JSON.stringify(status));
          completed.push(response.details.asyncDir);
        } else
          assert.equal(
            response.details?.results?.[0]?.exitCode,
            0,
            JSON.stringify(response),
          );
        const turns = requests.slice(before);
        assert.equal(turns.length, 2, "extension model/tool round trip");
        const output = turns
          .at(-1)
          .messages.filter((message: any) => message.role === "tool");
        assert.equal(output.length, 1);
        assert(
          !JSON.stringify(output).includes("Permission denied"),
          JSON.stringify(output),
        );
        assert(
          turns[0].tools.some(
            (tool: any) =>
              tool.function.name ===
              (probe === "EXTENSION_NESTED"
                ? "bridge_nested"
                : "memory_search"),
          ),
        );
        assert.equal(
          controls.prompts.length,
          beforePrompts + (probe === "EXTENSION_NESTED" ? 2 : 1),
          "outer and SDK-nested extension calls each reach the parent exactly once",
        );
        if (probe === "EXTENSION_NESTED")
          assert.equal(
            readFileSync(process.cwd() + "/extension-dispatch.txt", "utf8"),
            "nested extension",
          );
        else
          assert(
            !/error|failed/i.test(JSON.stringify(output)),
            JSON.stringify(output),
          );
      }
    }
    extensionRegistration.dispose();
    extensionRegistration = undefined;
    const beforeMatrix = requests.length;
    const matrix = await runSync(
      process.cwd(),
      discovered,
      "delegate",
      "NAMED_TOOLS fixture: exercise the seven declared SDK tools in order.",
      {
        parentSessionId: root.sessionId,
        modelOverride: "guard-test/fixture",
        modelOverrideFromParent: true,
        context: "fresh",
        sessionEnabled: false,
        artifactConfig: { enabled: false },
        timeoutMs: 25000,
      } as any,
    );
    assert.equal(matrix.exitCode, 0, matrix.error ?? matrix.finalOutput);
    const matrixTurns = requests.slice(beforeMatrix);
    const matrixTools = matrixTurns[0].tools.map(
      (tool: any) => tool.function.name,
    );
    // Inspect the request's effective prompt, not only persisted sections:
    // before_agent_start can force a different system prompt onto the wire.
    const matrixPrompt = matrixTurns[0].messages
      .filter((message: any) => message.role === "system")
      .map((message: any) =>
        typeof message.content === "string"
          ? message.content
          : JSON.stringify(message.content),
      )
      .join("\n");
    for (const factory of [
      createReadToolDefinition,
      createBashToolDefinition,
      createEditToolDefinition,
      createWriteToolDefinition,
      createGrepToolDefinition,
      createFindToolDefinition,
      createLsToolDefinition,
    ]) {
      const definition = factory(process.cwd());
      assert(
        matrixTools.includes(definition.name),
        `real child registry retains ${definition.name} despite the parent's restrictive tool surface`,
      );
      assert(definition.promptSnippet, `${definition.name} has an SDK snippet`);
      assert(
        matrixPrompt.includes(definition.promptSnippet),
        `effective model-request prompt advertises ${definition.name}`,
      );
      for (const guideline of definition.promptGuidelines ?? []) {
        assert(
          matrixPrompt.includes(guideline),
          `effective model-request prompt preserves ${definition.name} guideline: ${guideline}`,
        );
      }
    }
    const matrixResults = matrixTurns
      .at(-1)
      .messages.filter((message: any) => message.role === "tool");
    assert.equal(
      matrixResults.length,
      7,
      "every named tool completed a real dispatcher round trip",
    );
    assert.equal(
      readFileSync(process.cwd() + "/named-tools.txt", "utf8"),
      "second\n",
    );
    for (const [index, expected] of [
      [2, "second"],
      [3, "second"],
      [4, "named-tools.txt"],
      [5, "named-tools.txt"],
      [6, process.cwd()],
    ] as const) {
      assert(
        JSON.stringify(matrixResults[index].content).includes(expected),
        `named tool ${index} produced its expected result`,
      );
    }
    for (const name of ["delegate", "worker", "reviewer"]) {
      const before = requests.length;
      const result = await runSync(
        process.cwd(),
        discovered,
        name,
        "Perform the single read-only fixture tool call; report completion. Do not edit anything.",
        {
          parentSessionId: root.sessionId,
          modelOverride: "guard-test/fixture",
          modelOverrideFromParent: true,
          context: "fresh",
          sessionEnabled: false,
          artifactConfig: { enabled: false },
          timeoutMs: 15000,
        } as any,
      );
      assert.equal(
        result.exitCode,
        0,
        `${name}: ${result.error ?? result.finalOutput}`,
      );
      const turns = requests.slice(before);
      assert.equal(
        turns.length,
        2,
        `${name} real foreground tool/model round trip`,
      );
      const names = turns[0].tools.map((tool: any) => tool.function.name);
      assert(
        !names.some(
          (tool: string) =>
            tool.startsWith("guard_") ||
            ["powershell", "subagent"].includes(tool),
        ),
      );
      if (name === "reviewer")
        assert(
          !names.some((tool: string) =>
            ["bash", "write", "edit"].includes(tool),
          ),
        );
      const output = turns[1].messages
        .filter((m: any) => m.role === "tool")
        .map((m: any) => JSON.stringify(m.content))
        .join("\n");
      assert(
        name === "worker"
          ? /Denied by policy|policy rule .* denied/.test(output)
          : output.includes(name === "delegate" ? process.cwd() : "second"),
        output,
      );
    }
    await root.modelRuntime.refresh({ allowNetwork: false });
    const subagent = root.agent.state.tools.find(
      (tool: any) => tool.name === "subagent",
    );
    assert(subagent, "root has real Nico dispatcher");
    const execute = (params: any) => subagent.execute(randomUUID(), params);
    let first: any;
    for (const name of ["delegate", "worker", "reviewer"]) {
      const response = await execute({
        agent: name,
        task: "Perform the single read-only fixture tool call and report completion. Do not edit anything.",
        model: "guard-test/fixture",
        async: true,
        context: "fresh",
        artifacts: true,
        acceptance: false,
        timeoutMs: 20000,
      });
      assert(response.details?.asyncDir, JSON.stringify(response));
      const status = await wait(response.details.asyncDir);
      assert.equal(status.state, "complete", JSON.stringify(status));
      const session = readFileSync(status.steps[0].sessionFile, "utf8")
        .trim()
        .split("\n")
        .map((line) => JSON.parse(line));
      const result = session.find(
        (entry: any) => entry.message?.role === "toolResult",
      ).message;
      assert.equal(
        result.isError,
        name === "worker",
        `${name} remote result: ${JSON.stringify(result)}`,
      );
      if (name === "worker")
        assert(
          /Denied by policy|policy rule .* denied/.test(JSON.stringify(result)),
        );
      if (name === "reviewer")
        assert(
          !status.steps[0].recentTools.some((tool: any) =>
            ["bash", "write", "edit"].includes(tool.tool),
          ),
        );
      completed.push(response.details.asyncDir);
      first ??= { response, status, sessionId: session[0].id };
    }
    const resume = await execute({
      action: "resume",
      id: first.response.details.asyncId,
      message:
        "Perform another read-only fixture tool call and report completion.",
    });
    assert(resume.details?.asyncDir, JSON.stringify(resume));
    const resumedStatus = await wait(resume.details.asyncDir);
    assert.equal(
      resumedStatus.state,
      "complete",
      JSON.stringify(resumedStatus),
    );
    const resumed = readFileSync(resumedStatus.steps[0].sessionFile, "utf8")
      .trim()
      .split("\n")
      .map((line) => JSON.parse(line));
    assert.equal(
      resumed[0].id,
      first.sessionId,
      "actual resume preserves child session id",
    );
    assert.equal(
      resumed.filter((entry: any) => entry.message?.role === "toolResult")
        .length,
      2,
      "resume checks another operation",
    );
    completed.push(resume.details.asyncDir);

    controls.setDecision("deny");
    const denied = await execute({
      agent: "delegate",
      task: "DENY_WRITE fixture: attempt the single tool call and report the outcome.",
      model: "guard-test/fixture",
      async: true,
      context: "fresh",
      acceptance: false,
      timeoutMs: 20000,
    });
    assert(denied.details?.asyncDir, JSON.stringify(denied));
    const deniedStatus = await wait(denied.details.asyncDir);
    assert.equal(deniedStatus.state, "complete", JSON.stringify(deniedStatus));
    const deniedSession = readFileSync(
      deniedStatus.steps[0].sessionFile,
      "utf8",
    );
    assert(deniedSession.includes('"isError":true'), "remote write was denied");
    assert(
      !existsSync(process.cwd() + "/remote-denied.txt"),
      "remote denial creates no file",
    );
    controls.setDecision("approve");
    completed.push(denied.details.asyncDir);

    const request: any = {
      version: 1,
      name: "guard-fixture-coordinator",
      definition: {
        description: "Offline authorized fanout fixture",
        systemPrompt:
          "Perform the single fixture delegation and report completion.",
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
    controls.eventBus.emit(REGISTER, request);
    assert(request.result?.ok, JSON.stringify(request.result));
    registration = request.result.registration;
    for (const nestedAsync of [false, true]) {
      const beforePrompts = controls.prompts.length;
      const response = await execute({
        agent: "guard-fixture-coordinator",
        task: nestedAsync
          ? "NESTED_ASYNC fixture"
          : "NESTED_FOREGROUND fixture",
        model: "guard-test/fixture",
        async: true,
        context: "fresh",
        acceptance: false,
        timeoutMs: 25000,
      });
      assert(response.details?.asyncDir, JSON.stringify(response));
      const status = await wait(response.details.asyncDir);
      assert.equal(status.state, "complete", JSON.stringify(status));
      const transcript = readFileSync(status.steps[0].sessionFile, "utf8");
      const nested = transcript
        .trim()
        .split("\n")
        .map((line) => JSON.parse(line))
        .find((entry) => entry.message?.toolName === "subagent")?.message;
      assert(
        nested && !nested.isError,
        "nested dispatcher succeeded: " + transcript.slice(-5000),
      );
      let leafLog: string;
      if (nestedAsync) {
        assert(nested.details?.asyncDir);
        const leafStatus = await wait(nested.details.asyncDir);
        assert.equal(leafStatus.state, "complete", JSON.stringify(leafStatus));
        leafLog = readFileSync(leafStatus.steps[0].sessionFile, "utf8");
        completed.push(nested.details.asyncDir);
      } else {
        assert.equal(nested.details?.results?.[0]?.exitCode, 0);
        leafLog = readFileSync(
          nested.details.results[0].transcriptPath,
          "utf8",
        );
      }
      const leafResults = leafLog
        .trim()
        .split("\n")
        .map((line) => JSON.parse(line))
        .map((entry) => entry.message)
        .filter((message) => message?.role === "toolResult");
      assert(
        leafResults.some(
          (message) =>
            message.toolName === "bash" &&
            !message.isError &&
            JSON.stringify(message.content).includes(process.cwd()),
        ),
        "nested leaf really executed approved pwd",
      );
      assert(
        controls.prompts.length >= beforePrompts + 2,
        "both nested spawn and leaf ask reach the human root",
      );
      completed.push(response.details.asyncDir);
    }
    for (const nestedAsync of [false, true]) {
      const before = requests.length;
      const response = await execute({
        agent: "guard-fixture-coordinator",
        task: nestedAsync
          ? "NESTED_ASYNC fixture"
          : "NESTED_FOREGROUND fixture",
        model: "guard-test/fixture",
        async: false,
        context: "fresh",
        acceptance: false,
        timeoutMs: 25000,
      });
      assert.equal(
        response.details?.results?.[0]?.exitCode,
        0,
        JSON.stringify(response).slice(0, 5000),
      );
      const turns = requests.slice(before);
      assert.equal(
        turns.length,
        4,
        "foreground coordinator waits for real nested tool/model round trip",
      );
      assert(
        turns.some((turn) =>
          turn.messages.some(
            (message: any) =>
              message.role === "tool" &&
              JSON.stringify(message.content).includes(process.cwd()),
          ),
        ),
        "foreground nested leaf received actual pwd output",
      );
    }
    const original = readLease(root.sessionId)!;
    let replacement: ReturnType<typeof acquireLease> | undefined;
    controls.setOnPrompt(async () => {
      releaseLease(original);
      replacement = acquireLease(root.sessionId);
      assert.throws(() => assertLeaseLive(original), /generation ended/);
    });
    try {
      const stale = await execute({
        agent: "delegate",
        task: "STALE_WRITE fixture",
        model: "guard-test/fixture",
        async: true,
        context: "fresh",
        acceptance: false,
        timeoutMs: 15000,
      });
      assert(stale.details?.asyncDir, JSON.stringify(stale));
      const status = await wait(stale.details.asyncDir);
      assert.equal(
        status.state,
        "failed",
        "same session id with a new generation cannot approve the old child",
      );
      assert(
        replacement,
        "test revoked authority while remote approval was pending",
      );
      assert(
        !existsSync(process.cwd() + "/remote-stale.txt"),
        "stale remote approval has no side effects",
      );
      completed.push(stale.details.asyncDir);
    } finally {
      controls.setOnPrompt();
      if (replacement) {
        releaseLease(replacement);
        // Test-only restoration after the old process has fully terminated.
        const leasePath =
          process.env.PI_CODING_AGENT_DIR +
          "/pi-guard/leases/" +
          createHash("sha256").update(root.sessionId).digest("hex") +
          ".json";
        writeFileSync(leasePath, JSON.stringify(original), {
          flag: "wx",
          mode: 0o600,
        });
      }
    }
    console.log(
      JSON.stringify({
        realExecutorRoundTrips: ["delegate", "worker", "reviewer"],
        detachedResume: true,
        detachedNestedForeground: true,
        detachedNestedBackground: true,
        foregroundNestedForeground: true,
        foregroundNestedBackground: true,
        remoteWriteDenial: true,
        remoteStaleApprovalBlocked: true,
        localModelRequests: requests.length,
        namedToolMatrix: true,
        actualRunnerDirs: completed,
      }),
    );
  } finally {
    registration?.dispose();
    extensionRegistration?.dispose();
    controls.setOnPrompt();
    controls.setDecision("approve");
    unlinkSync(path);
    server.closeAllConnections();
    await new Promise<void>((resolve) => server.close(() => resolve()));
  }
}
