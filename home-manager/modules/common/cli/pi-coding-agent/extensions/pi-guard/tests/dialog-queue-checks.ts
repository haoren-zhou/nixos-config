import assert from "node:assert/strict";
import { installDialogQueue } from "../dialog-queue.ts";

const tick = () => new Promise<void>((resolve) => setImmediate(resolve));
export async function dialogQueueChecks() {
  const calls: any[] = [];
  const ui: any = {};
  for (const name of ["custom", "select", "confirm", "input", "editor"]) {
    ui[name] = (...args: any[]) =>
      new Promise((resolve, reject) => {
        const call = { name, args, resolve, reject };
        calls.push(call);
        args[2]?.signal?.addEventListener(
          "abort",
          () => resolve(name === "confirm" ? false : undefined),
          { once: true },
        );
        if (name === "custom") args[0]({}, {}, {}, resolve);
      });
  }
  const queue = installDialogQueue(ui);
  assert.equal(installDialogQueue(ui), queue, "idempotent installation");
  const a = ui.custom(() => ({}));
  const b = ui.custom(() => ({}));
  const c = ui.select("third", ["Yes", "No"]);
  assert.equal(
    calls.length,
    1,
    "second and third prompts cannot replace first",
  );
  calls[0].resolve({ approved: true });
  assert.deepEqual(await a, { approved: true });
  await tick();
  assert.equal(calls.length, 2);
  calls[1].resolve({ approved: false });
  assert.deepEqual(
    await b,
    { approved: false },
    "decisions never cross requests",
  );
  await tick();
  assert.equal(calls.length, 3);
  calls[2].resolve("No");
  assert.equal(await c, "No");
  await tick();

  for (const name of ["select", "confirm", "input", "editor"]) {
    const before = calls.length;
    const first = ui[name]("Title", name === "select" ? ["Yes"] : "Text");
    const next = ui.custom(() => ({}));
    assert.equal(calls.length, before + 1, `${name} holds the same queue`);
    calls[before].resolve(name === "confirm" ? false : "value");
    await first;
    await tick();
    assert.equal(calls.length, before + 2);
    calls[before + 1].resolve(undefined);
    await next;
    await tick();
  }

  const beforeAbort = calls.length;
  const held = ui.custom(() => ({}));
  const controller = new AbortController();
  const cancelled = ui.select("never visible", ["Yes"], {
    signal: controller.signal,
    timeout: 300,
  });
  controller.abort();
  assert.equal(await cancelled, undefined);
  calls[beforeAbort].resolve(false);
  await held;
  await tick();
  assert.equal(
    calls.length,
    beforeAbort + 1,
    "aborted queued request is removed",
  );
  const preAborted = new AbortController();
  preAborted.abort();
  assert.equal(
    await ui.confirm("never visible", "x", { signal: preAborted.signal }),
    false,
  );
  assert.equal(calls.length, beforeAbort + 1);
  const activeAbort = new AbortController();
  const active = ui.input("cancel me", "", {
    signal: activeAbort.signal,
    timeout: 321,
  });
  assert.equal(calls.at(-1).args[2].timeout, 321, "native timeout preserved");
  activeAbort.abort();
  assert.equal(await active, undefined);
  await tick();

  const failed = ui.custom(() => {
    throw new Error("broken factory");
  });
  await assert.rejects(failed, /broken factory/);
  const following = ui.custom(() => ({}));
  calls.at(-1).reject(new Error("native rejection"));
  await assert.rejects(following, /native rejection/);
  await tick();

  const overlay = ui.custom(() => ({}), { overlay: true });
  const overlayCall = calls.at(-1);
  const subdialog = ui.custom(() => ({}));
  assert.notEqual(
    calls.at(-1),
    overlayCall,
    "overlay can open inline UI without deadlock",
  );
  calls.at(-1).resolve("nested");
  assert.equal(await subdialog, "nested");
  overlayCall.resolve("overlay");
  assert.equal(await overlay, "overlay");
  await tick();

  let lateDone: any;
  const abandoned = ui.custom((_t: any, _th: any, _k: any, done: any) => {
    lateDone = done;
    return {};
  });
  const neverStarted = ui.custom(() => {
    throw new Error("must not display");
  });
  const staleCustom = ui.custom;
  const observed = [
    assert.rejects(abandoned, /session ended/),
    assert.rejects(neverStarted, /session ended/),
  ];
  queue.dispose();
  queue.dispose();
  lateDone({ approved: true });
  await Promise.all(observed);
  await assert.rejects(
    ui.custom(() => ({})),
    /session ended/,
  );
  assert.throws(() => installDialogQueue(ui), /session ended/);
  const rebound = installDialogQueue(ui, { allowRebind: true });
  const reboundAsk = ui.custom(() => ({}));
  calls.at(-1).resolve(false);
  assert.equal(
    await reboundAsk,
    false,
    "0.84.2 shared UI can be rebound only by explicit root startup",
  );
  await assert.rejects(
    staleCustom(() => ({})),
    /session ended/,
    "captured old method stays closed after rebind",
  );
  rebound.dispose();
  const fresh = {
    ...ui,
    ...Object.fromEntries(
      ["custom", "select", "confirm", "input", "editor"].map((key) => [
        key,
        async () => false,
      ]),
    ),
  };
  const nextQueue = installDialogQueue(fresh as any);
  assert.equal(
    await fresh.confirm(),
    false,
    "new session is independent of closed context",
  );
  fresh.custom = async () => true;
  assert.throws(() => nextQueue.assertLive(), /was replaced/);
  nextQueue.dispose();
  return {
    fifo: true,
    distinctDecisions: true,
    allInlineMethods: true,
    abort: true,
    errors: true,
    overlayNesting: true,
    shutdown: true,
    staleCallbacks: true,
    independentContexts: true,
  };
}
