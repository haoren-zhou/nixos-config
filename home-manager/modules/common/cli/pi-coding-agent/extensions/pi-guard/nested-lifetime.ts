import { randomUUID } from "node:crypto";
import { readFileSync } from "node:fs";
import { isAbsolute, join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import type { BackgroundWorkProvider } from "pi-subagents/background-work";
import { dependencyPath } from "./dependencies.ts";
const { SUBAGENT_ASYNC_STARTED_EVENT } = await import(
  dependencyPath("pi-subagents", "src/shared/types.ts")
);
const { registerBackgroundWorkProvider } = await import(
  dependencyPath("pi-subagents", "src/api/background-work.ts")
);

// Nico's headless drain scans its main async directory, not nested-run state.
// Publishing owned nested runs through its provider API keeps the normal drain
// active; a separate agent_end waiter runs too late to prevent idle shutdown.
export function trackNestedLifetime(pi: ExtensionAPI) {
  const children = new Map<string, { dir: string; deadline: number }>();
  let active = true;
  let owner: string | undefined;
  let sessionFile: string | undefined;
  let unregister: (() => void) | undefined;
  const owns = (id: string) =>
    [owner, sessionFile].filter(Boolean).includes(id);
  pi.on("session_start", (_event, ctx) => {
    owner = ctx.sessionManager.getSessionId();
    sessionFile = ctx.sessionManager.getSessionFile();
    const provider: BackgroundWorkProvider = {
      name: `guard-nested-${randomUUID()}`,
      listActiveWork(context) {
        if (!active || !context || !owns(context.sessionId)) return [];
        for (const [id, child] of children) {
          const status = JSON.parse(
            readFileSync(join(child.dir, "status.json"), "utf8"),
          );
          if (status.runId !== id || !owns(status.sessionId))
            throw new Error("Guard nested run ownership changed");
          if (
            typeof status.deadlineAt === "number" &&
            Number.isFinite(status.deadlineAt)
          )
            child.deadline = Math.min(child.deadline, status.deadlineAt + 5000);
          // Nico owns task outcomes and retries. Guard only holds the parent
          // until the process is gone, including failed/cancelled runs.
          if (
            ["complete", "failed", "cancelled", "stopped"].includes(
              status.state,
            ) &&
            status.processTerminal?.state === "observed"
          ) {
            children.delete(id);
            continue;
          }
          if (context.nowMs >= child.deadline)
            throw new Error(
              `Guard nested child ${id} did not finish before its deadline`,
            );
        }
        return [...children.keys()].map((id) => ({
          id,
          sessionId: context.sessionId,
        }));
      },
    };
    unregister = registerBackgroundWorkProvider(provider);
  });
  const unsubscribe = pi.events.on(
    SUBAGENT_ASYNC_STARTED_EVENT,
    (value: unknown) => {
      if (!active || !value || typeof value !== "object") return;
      const event = value as Record<string, unknown>;
      if (
        typeof event.sessionId !== "string" ||
        !owns(event.sessionId) ||
        typeof event.id !== "string" ||
        typeof event.asyncDir !== "string" ||
        !isAbsolute(event.asyncDir)
      )
        return;
      if (children.size >= 1024)
        throw new Error("Guard nested run tracking capacity exceeded");
      children.set(event.id, {
        dir: event.asyncDir,
        deadline: Date.now() + 30 * 60 * 1000,
      });
    },
  );
  const stop = () => {
    active = false;
    unsubscribe();
    unregister?.();
    unregister = undefined;
    children.clear();
  };
  pi.on("session_shutdown", stop);
  return stop;
}
