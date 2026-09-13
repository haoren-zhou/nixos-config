import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import {
  createEventBus,
  type ExtensionAPI,
} from "@earendil-works/pi-coding-agent";
import { dependencyPath } from "../dependencies.ts";
import { trackNestedLifetime } from "../nested-lifetime.ts";
const { listBackgroundWorkProviders } = await import(
  dependencyPath("pi-subagents", "src/api/background-work.ts")
);
const { SUBAGENT_ASYNC_STARTED_EVENT } = await import(
  dependencyPath("pi-subagents", "src/shared/types.ts")
);

export function nestedLifetimeChecks(): void {
  const dir = mkdtempSync(join(tmpdir(), "pi-guard-nested-unit."));
  const owner = randomUUID();
  const events = createEventBus();
  const handlers = new Map<string, (...args: any[]) => unknown>();
  const previous = new Set(listBackgroundWorkProviders());
  const stop = trackNestedLifetime({
    events,
    on(name: string, handler: (...args: any[]) => unknown) {
      handlers.set(name, handler);
    },
  } as ExtensionAPI);
  try {
    handlers.get("session_start")!(
      {},
      {
        sessionManager: {
          getSessionId: () => owner,
          getSessionFile: () => join(dir, "owner.jsonl"),
        },
      },
    );
    const provider = listBackgroundWorkProviders().find(
      (entry: unknown) => !previous.has(entry),
    );
    assert(provider);
    const context = { sessionId: owner, nowMs: Date.now() };
    const publish = (
      id: string,
      state: string,
      observed = false,
      extra = {},
    ) => {
      writeFileSync(
        join(dir, "status.json"),
        JSON.stringify({
          runId: id,
          sessionId: owner,
          state,
          processTerminal: { state: observed ? "observed" : "pending" },
          ...extra,
        }),
      );
    };
    const started = (id: string) =>
      events.emit(SUBAGENT_ASYNC_STARTED_EVENT, {
        id,
        sessionId: owner,
        asyncDir: dir,
      });
    for (const state of ["complete", "failed", "cancelled", "stopped"]) {
      const id = randomUUID();
      publish(id, state);
      started(id);
      assert.equal(
        provider.listActiveWork(context).length,
        1,
        `${state} must retain an unobserved process`,
      );
      publish(id, state, true);
      assert.deepEqual(
        provider.listActiveWork(context),
        [],
        `${state} must release an observed process`,
      );
      assert.deepEqual(
        provider.listActiveWork(context),
        [],
        "terminal errors must not poison later drains",
      );
    }
    const active = randomUUID();
    publish(active, "running");
    started(active);
    assert.equal(
      provider.listActiveWork(context).length,
      1,
      "subsequent work still drains",
    );
    publish(active, "running", false, { sessionId: "different-owner" });
    assert.throws(() => provider.listActiveWork(context), /ownership changed/);
    writeFileSync(join(dir, "status.json"), "malformed");
    assert.throws(
      () => provider.listActiveWork(context),
      SyntaxError,
      "unknown status must not count as completion",
    );
    publish(active, "running", false, { deadlineAt: 0 });
    assert.throws(
      () => provider.listActiveWork(context),
      /deadline/,
      "timeout must not release an unobserved process",
    );
    publish(active, "stopped", true);
    assert.deepEqual(provider.listActiveWork(context), []);
  } finally {
    stop();
    assert.deepEqual(new Set(listBackgroundWorkProviders()), previous);
    rmSync(dir, { recursive: true, force: true });
  }
}
