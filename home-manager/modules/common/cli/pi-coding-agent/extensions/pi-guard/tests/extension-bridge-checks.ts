import assert from "node:assert/strict";
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { getAgentDir } from "@earendil-works/pi-coding-agent";
import { dependencyPath } from "../dependencies.ts";
import { getPermissionsService } from "../shared.ts";

export function writeBridgeFixture() {
  const file = join(process.cwd(), "bridge-tools.ts");
  const servicePath = dependencyPath(
    "@gotgenes/pi-permission-system",
    "src/service.ts",
  );
  writeFileSync(
    file,
    `
import { writeFileSync } from "node:fs";
import { Type } from "typebox";
import { getPermissionsService } from ${JSON.stringify(servicePath)};
export default function(pi) {
  pi.on("session_start", (_event, ctx) => {
    if (ctx.hasUI) throw new Error("custom extension received a fake UI");
  });
  pi.events.on("permissions:ready", ({sessionId}) => {
    const service = getPermissionsService(sessionId);
    for (const name of ["bridge_touch", "bridge_allow", "bridge_deny"]) {
      if (!service.getToolAccessExtractor(name))
        service.registerToolAccessExtractor(name, input => input.destination);
    }
  });
  for (const name of ["bridge_touch", "bridge_allow", "bridge_deny", "bridge_nested"]) {
    pi.registerTool({
      name, label: name, description: "Disposable permission bridge fixture",
      promptSnippet: "Exercise a disposable extension tool.",
      parameters: Type.Object({destination: Type.String(), content: Type.String()}),
      execute: async (_id, args, _signal, _update, ctx) => {
        if (name === "bridge_nested") return ctx.executeTool("bridge_touch", args);
        writeFileSync(args.destination, args.content);
        return {content:[{type:"text", text:"bridge extension executed"}], details:{destination:args.destination}};
      }
    });
  }
}
`,
  );
  return file;
}

export async function extensionBridgeChecks(input: any) {
  const { root, guarded, plan, prepare, dispatch, gate, controls } = input;
  const fixture = writeBridgeFixture();
  const permission = dependencyPath(
    "@gotgenes/pi-permission-system",
    "src/index.ts",
  );
  const names = ["bridge_touch", "bridge_allow", "bridge_deny"];
  const create = (parentSessionId = root.sessionId, extensions = [fixture]) =>
    guarded.create(
      plan("worker", { tools: names, extensions, parentSessionId }).session,
    );
  const rootNode = getPermissionsService(root.sessionId) as any;
  const config = rootNode.session.configStore;
  const initialConfig = { ...config.current() };
  const setMode = (yoloMode: boolean) =>
    config.save(
      { ...config.current(), yoloMode },
      {
        ui: { setStatus() {}, notify() {} },
      },
    );
  let parent: any;
  let child: any;
  try {
    // A discovered permission instance must be reused, not layered underneath
    // a second hook-owned service. Other extensions still see headless contexts.
    parent = await create(root.sessionId, [permission, fixture]);
    let session = await prepare(parent);
    const service = getPermissionsService(parent.sessionId);
    await prepare(parent);
    assert.equal(getPermissionsService(parent.sessionId), service);
    controls.setDecision("approve");
    let count = controls.prompts.length;
    const allowed = join(process.cwd(), "extension-allowed.txt");
    const result = await dispatch(session, "bridge_touch", {
      destination: allowed,
      content: "approved",
    });
    assert.equal(readFileSync(allowed, "utf8"), "approved");
    assert.equal(
      controls.prompts.length,
      count + 1,
      "exactly one parent approval, not duplicate permission gates",
    );
    assert(result.content);
    controls.setDecision("deny");
    const denied = join(process.cwd(), "extension-denied.txt");
    assert.equal(
      (
        await dispatch(session, "bridge_touch", {
          destination: denied,
          content: "no",
        })
      ).block,
      true,
    );
    assert(!existsSync(denied));
    controls.setDecision("approve");
    count = controls.prompts.length;
    await dispatch(session, "bridge_allow", {
      destination: join(process.cwd(), "extension-policy-allow.txt"),
      content: "yes",
    });
    assert.equal(
      (
        await gate(session, "bridge_deny", {
          destination: denied,
          content: "no",
        })
      )?.block,
      true,
    );
    assert.equal(
      controls.prompts.length,
      count,
      "parent allow/deny policy does not ask",
    );
    assert.equal(
      (
        await gate(session, "bridge_touch", {
          destination: join(process.cwd(), "extension.env"),
          content: "secret",
        })
      )?.block,
      true,
    );
    assert(
      !existsSync(join(process.cwd(), "extension.env")),
      "custom extractor retains path denial",
    );
    controls.setDecision("deny");
    count = controls.prompts.length;
    assert.equal(
      (
        await session.extensionRunner.emitInput(
          "/skill:fixture",
          undefined,
          "interactive",
        )
      ).action,
      "handled",
    );
    assert.equal(
      controls.prompts.length,
      count + 1,
      "skill input permission reaches the parent",
    );
    controls.setDecision("approve");
    assert.equal(
      (
        await session.extensionRunner.emitInput(
          "/skill:fixture",
          undefined,
          "interactive",
        )
      ).action,
      "continue",
    );
    parent.abort();
    assert.equal(
      (
        await session.extensionRunner.emitInput(
          "/skill:fixture",
          undefined,
          "interactive",
        )
      ).action,
      "handled",
      "stale input is consumed, not thrown and ignored by Pi",
    );
    await parent.dispose();
    parent = undefined;

    // Cache YOLO in a child, then turn it off only at the root. Neither the
    // child's gate nor its serving inbox may use that stale auto-approval.
    setMode(true);
    parent = await create();
    session = await prepare(parent);
    assert.equal(
      (
        getPermissionsService(parent.sessionId) as any
      ).session.configStore.current().yoloMode,
      true,
    );
    count = controls.prompts.length;
    await dispatch(session, "bridge_touch", {
      destination: join(process.cwd(), "extension-yolo.txt"),
      content: "auto",
    });
    assert.equal(controls.prompts.length, count);
    setMode(false);
    controls.setDecision("deny");
    assert.equal(
      (
        await dispatch(session, "bridge_touch", {
          destination: denied,
          content: "no",
        })
      ).block,
      true,
    );
    assert.equal(
      controls.prompts.length,
      count + 1,
      "root Guard mode overrides cached child YOLO",
    );
    assert(!existsSync(denied));
    child = await create(parent.sessionId);
    const childSession = await prepare(child);
    count = controls.prompts.length;
    assert.equal(
      (
        await dispatch(childSession, "bridge_touch", {
          destination: denied,
          content: "no",
        })
      ).block,
      true,
    );
    assert.equal(
      controls.prompts.length,
      count + 1,
      "cached intermediate YOLO cannot approve a grandchild",
    );
    assert(!existsSync(denied));
    controls.setDecision("approve");
    setMode(true);
    count = controls.prompts.length;
    await dispatch(childSession, "bridge_touch", {
      destination: join(process.cwd(), "extension-grandchild-yolo.txt"),
      content: "auto",
    });
    assert.equal(
      controls.prompts.length,
      count,
      "root YOLO applies through a Guard-cached grandchild",
    );
    await child.dispose();
    child = undefined;
    await parent.dispose();
    parent = undefined;
    setMode(false);

    const hermes = join(
      getAgentDir(),
      "npm/node_modules/pi-hermes-memory/src/index.ts",
    );
    let hermesSearch = false;
    if (existsSync(hermes)) {
      parent = await guarded.create(
        plan("worker", {
          tools: ["read", "memory_search"],
          subagentOnlyExtensions: [hermes],
        }).session,
      );
      session = await prepare(parent);
      assert(
        session.agent.state.tools.some(
          (tool: any) => tool.name === "memory_search",
        ),
      );
      count = controls.prompts.length;
      const memory = await dispatch(session, "memory_search", {
        query: "disposable bridge fixture",
      });
      assert(
        memory.content && !memory.block && !memory.isError,
        JSON.stringify(memory),
      );
      assert.equal(
        controls.prompts.length,
        count + 1,
        "real Hermes memory_search forwards its ask",
      );
      hermesSearch = true;
      await parent.dispose();
      parent = undefined;
    }
    // Exercise stock ambient discovery using the same runner-style plan. The
    // actual detached executor is tested separately against these same hooks.
    const settingsPath = join(getAgentDir(), "settings.json");
    const settingsBefore = readFileSync(settingsPath);
    const environment = { ...process.env };
    try {
      const settings = JSON.parse(settingsBefore.toString());
      settings.extensions = [permission, fixture];
      writeFileSync(settingsPath, JSON.stringify(settings));
      parent = await guarded.create(
        plan("worker", { host: "runner", tools: names, extensions: undefined })
          .session,
      );
      session = await prepare(parent);
      count = controls.prompts.length;
      await dispatch(session, "bridge_touch", {
        destination: join(process.cwd(), "extension-ambient.txt"),
        content: "ambient",
      });
      assert.equal(
        controls.prompts.length,
        count + 1,
        "ambient tools keep one forwarded permission gate",
      );
      await parent.dispose();
      parent = undefined;
    } finally {
      writeFileSync(settingsPath, settingsBefore);
      for (const name of Object.keys(process.env))
        if (!(name in environment)) delete process.env[name];
      Object.assign(process.env, environment);
    }
    console.log(
      JSON.stringify({
        extensionBridge: true,
        explicitAndAmbient: true,
        singlePermissionInstance: true,
        parentPolicy: true,
        modeChanges: true,
        nestedModeChanges: true,
        customExtractor: true,
        hermesSearch,
      }),
    );
  } finally {
    controls.setDecision("approve");
    await child?.dispose();
    await parent?.dispose();
    config.save(initialConfig, { ui: { setStatus() {}, notify() {} } });
  }
}
