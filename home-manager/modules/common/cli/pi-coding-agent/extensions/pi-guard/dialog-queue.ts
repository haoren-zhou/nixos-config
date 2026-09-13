import type { ExtensionUIContext } from "@earendil-works/pi-coding-agent";

// Root extensions share a mutable UI object. Inline dialogs can replace the
// editor without settling the displaced dialog. Intercept that shared object,
// not a private copy. Pi does not expose a public dialog-middleware API.
const METHODS = ["custom", "select", "confirm", "input", "editor"] as const;
type Method = (typeof METHODS)[number];
// Erase the heterogeneous UI overloads only at this forwarding boundary.
type Call = (...args: any[]) => Promise<unknown>;
type CustomFactory = Parameters<ExtensionUIContext["custom"]>[0];
type Job = { start(): void; cancel(): void };
const KEY = Symbol.for("hr.pi-guard.dialog-queues.v1");

export interface DialogQueue {
  readonly ui: ExtensionUIContext;
  assertLive(): void;
  dispose(): void;
}

type Installation = {
  queue: DialogQueue;
  originals: Record<Method, Call>;
  wrappers: Record<Method, Call>;
  isClosed(): boolean;
};

export function installDialogQueue(
  ui: ExtensionUIContext,
  options: { allowRebind?: boolean } = {},
): DialogQueue {
  const globals = globalThis as Record<symbol, unknown>;
  const queues = (globals[KEY] ??= new WeakMap<
    object,
    Installation
  >()) as WeakMap<object, Installation>;
  const existing = queues.get(ui);
  if (existing) {
    if (!existing.isClosed() || !options.allowRebind) {
      existing.queue.assertLive();
      return existing.queue;
    }
    // Pi 0.84.2 reuses the raw UI object on SDK reload (0.85.1 wraps
    // it afresh). Only the root's new startup may replace closed wrappers.
    for (const name of METHODS) {
      if (ui[name] !== existing.wrappers[name])
        throw new Error(`Guard dialog queue: ui.${name} changed before rebind`);
    }
  }
  for (const name of METHODS) {
    if (typeof ui[name] !== "function")
      throw new Error(`Guard dialog queue: missing ui.${name}`);
  }
  const previous = Object.fromEntries(
    METHODS.map((name) => [name, ui[name]]),
  ) as Record<Method, Call>;
  const originals = existing?.originals ?? previous;
  const pending: Job[] = [];
  let active: Job | undefined;
  let closed = false;
  const stopped = () =>
    new Error("Guard dialog queue: session ended; approval unavailable");
  const pump = () => {
    if (closed || active) return;
    active = pending.shift();
    active?.start();
  };

  const enqueue = (name: Method, args: any[]): Promise<unknown> => {
    if (closed) return Promise.reject(stopped());
    // Overlays have their own stack and may open an inline subdialog. Holding
    // the inline queue for an overlay would deadlock that supported use case.
    if (name === "custom" && args[1]?.overlay)
      return originals.custom.apply(ui, args);
    const callerSignal: AbortSignal | undefined = [
      "select",
      "confirm",
      "input",
    ].includes(name)
      ? args[2]?.signal
      : undefined;
    const cancelledValue = name === "confirm" ? false : undefined;
    return new Promise((resolve, reject) => {
      let settled = false;
      let started = false;
      let closeCustom: (() => void) | undefined;
      const controller = new AbortController();
      const finish = (ok: boolean, value: unknown) => {
        if (settled) return;
        settled = true;
        callerSignal?.removeEventListener("abort", onAbort);
        const index = pending.indexOf(job);
        if (index !== -1) pending.splice(index, 1);
        if (active === job) active = undefined;
        if (ok) resolve(value);
        else reject(value);
        // The native promise settles only after restoring the editor. Never
        // start the next dialog from inside the previous component's done().
        queueMicrotask(pump);
      };
      const onAbort = () => {
        if (!started) finish(true, cancelledValue);
        else controller.abort(); // native dialog owns closing/restoring its UI
      };
      const job: Job = {
        start() {
          if (settled) return;
          started = true;
          const nativeArgs = [...args];
          if (["select", "confirm", "input"].includes(name)) {
            nativeArgs[2] = { ...args[2], signal: controller.signal };
          } else if (name === "custom") {
            const factory: CustomFactory = args[0];
            nativeArgs[0] = ((tui, theme, keys, done) => {
              closeCustom = () => done(undefined);
              return factory(tui, theme, keys, (value) => {
                if (!closed) done(value);
              });
            }) satisfies CustomFactory;
          }
          try {
            Promise.resolve(originals[name].apply(ui, nativeArgs)).then(
              (value) => finish(!closed, closed ? stopped() : value),
              (error) => finish(false, error),
            );
          } catch (error) {
            finish(false, error);
          }
        },
        cancel() {
          // Reject rather than synthesizing a human decision. For custom UI,
          // close the actual component as well so forwarding can unwind.
          try {
            controller.abort();
            closeCustom?.();
          } finally {
            finish(false, stopped());
          }
        },
      };
      pending.push(job);
      callerSignal?.addEventListener("abort", onAbort, { once: true });
      if (callerSignal?.aborted) onAbort();
      pump();
    });
  };

  const queue: DialogQueue = {
    ui,
    assertLive() {
      if (closed) throw stopped();
      for (const name of METHODS) {
        if (ui[name] !== wrappers[name])
          throw new Error(
            `Guard dialog queue: ui.${name} was replaced; restart Pi`,
          );
      }
    },
    dispose() {
      if (closed) return;
      closed = true;
      for (const job of [...pending, ...(active ? [active] : [])]) job.cancel();
      // Retain closed wrappers until root startup rebinds this UI (0.84.2)
      // or receives a fresh object (0.85.1). Captured old methods stay closed.
    },
  };
  const wrappers = Object.fromEntries(
    METHODS.map((name) => [name, (...args: any[]) => enqueue(name, args)]),
  ) as Record<Method, Call>;
  const methods = ui as unknown as Record<Method, Call>;
  try {
    for (const name of METHODS) methods[name] = wrappers[name];
    queue.assertLive();
  } catch (error) {
    for (const name of METHODS)
      if (ui[name] === wrappers[name]) methods[name] = previous[name];
    throw error;
  }
  queues.set(ui, { queue, originals, wrappers, isClosed: () => closed });
  return queue;
}
