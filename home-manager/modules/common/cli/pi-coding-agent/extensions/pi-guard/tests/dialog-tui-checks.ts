// Run in a disposable *interactive* Pi, not -p/RPC: exercises real editor
// replacement, focus, rendering and the installed permission component.
import assert from "node:assert/strict";
import { writeFileSync } from "node:fs";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { dependencyPath } from "../dependencies.ts";
const { requestPermissionDecision } = await import(
  dependencyPath(
    "@gotgenes/pi-permission-system",
    "src/authority/permission-prompt-component.ts",
  )
);
const { DEFAULT_RENDER_BUDGET } = await import(
  dependencyPath(
    "@gotgenes/pi-permission-system",
    "src/presentation/dialog-renderer.ts",
  )
);
const { DEFAULT_DIALOG_KEYS } = await import(
  dependencyPath("@gotgenes/pi-permission-system", "src/config/dialog-keys.ts")
);
import { installDialogQueue } from "../dialog-queue.ts";
import { dialogQueueChecks } from "./dialog-queue-checks.ts";

const tick = () => new Promise<void>((resolve) => setTimeout(resolve, 25));
export default function (pi: ExtensionAPI) {
  pi.registerCommand("guard-dialog-tui-test", {
    handler: async (_args, ctx) => {
      const output = process.env.PI_GUARD_DIALOG_RESULT!;
      let queue: ReturnType<typeof installDialogQueue> | undefined;
      try {
        assert.equal(ctx.mode, "tui");
        const unit = await dialogQueueChecks();
        const ui = ctx.ui;
        const original = ui.custom;
        const shown: any[] = [];
        ui.custom = ((factory: any, options: any) =>
          original((tui, theme, kb, done) => {
            const component = factory(tui, theme, kb, done);
            shown.push({ tui, component, done });
            return component;
          }, options)) as typeof ui.custom;
        const payload = (value: string): any => ({
          kind: "bash",
          request: {
            requester: {
              agentName: "delegate",
              forwarded: true,
              sessionId: "fixture-child",
            },
            surface: "bash",
            toolName: "bash",
            invokedToolName: null,
            value,
            matchedPattern: "*",
            commandContext: null,
            executedUnit: null,
          },
          evidence: [],
          annotations: [],
        });
        const ask = (value: string) =>
          requestPermissionDecision(
            {
              mode: "tui",
              ui,
              doublePressToConfirm: false,
              budget: DEFAULT_RENDER_BUDGET,
              dialogKeys: DEFAULT_DIALOG_KEYS,
              promptNotifications: [],
              notice: { title: "Guard fixture", body: "Permission required" },
            },
            "Permission Required (Subagent)",
            payload(value),
          );
        const focused = (record: any) =>
          assert.equal(record.tui.focusedComponent, record.component);
        const answer = (record: any, key: string) => {
          focused(record);
          record.component.handleInput(key);
        };

        // First prove the exact old failure against the real Pi implementation.
        let firstSettled = false;
        const lost = ask("pwd").then((result) => {
          firstSettled = true;
          return result;
        });
        await tick();
        const oldFirst = shown.at(-1);
        focused(oldFirst);
        const replacing = ask("parent status check");
        await tick();
        const oldSecond = shown.at(-1);
        focused(oldSecond);
        assert.notEqual(oldFirst.tui.focusedComponent, oldFirst.component);
        answer(oldSecond, "n");
        assert.equal((await replacing).approved, false);
        await tick();
        assert.equal(
          firstSettled,
          false,
          "unpatched background prompt is orphaned",
        );
        oldFirst.done({ approved: false, state: "denied" });
        await lost;
        await tick();

        queue = installDialogQueue(ui);
        const before = shown.length;
        const background = ask("pwd");
        await tick();
        const first = shown.at(-1);
        focused(first);
        const foreground = ask("printf 'must deny'");
        const third = ask("pwd third request");
        await tick();
        assert.equal(
          shown.length,
          before + 1,
          "overlapping requests stay queued",
        );
        focused(first);
        const lines = first.component.render(100).join("\n");
        assert(
          lines.includes("pwd"),
          "actual permission dialog renders its command",
        );
        answer(first, "y");
        assert.equal((await background).approved, true);
        await tick();
        assert.equal(shown.length, before + 2);
        const second = shown.at(-1);
        focused(second);
        assert(second.component.render(100).join("\n").includes("must deny"));
        answer(second, "n");
        assert.equal((await foreground).approved, false);
        await tick();
        assert.equal(shown.length, before + 3);
        answer(shown.at(-1), "n");
        assert.equal((await third).approved, false);

        // Different root UI methods also cannot overwrite a permission dialog.
        await tick();
        const fourth = ask("pwd before timed confirm");
        await tick();
        const fourthUI = shown.at(-1);
        const confirm = ui.confirm(
          "Timed root question",
          "Never auto-approve",
          { timeout: 50 },
        );
        await tick();
        focused(fourthUI);
        answer(fourthUI, "n");
        assert.equal((await fourth).approved, false);
        assert.equal(await confirm, false);

        const cancelled = ask("pwd pending at shutdown");
        await tick();
        const stale = shown.at(-1);
        const waiting = ask("never shown after shutdown");
        const cancelledResults = [
          assert.rejects(cancelled, /session ended/),
          assert.rejects(waiting, /session ended/),
        ];
        queue.dispose();
        await Promise.all(cancelledResults);
        assert.notEqual(
          stale.tui.focusedComponent,
          stale.component,
          "shutdown closes the real component",
        );
        writeFileSync(
          output,
          JSON.stringify({
            passed: true,
            unit,
            realTui: true,
            unpatchedCollisionReproduced: true,
            permissionComponent: true,
            serializedApproveDeny: true,
            nextRequestUnblocked: true,
            mixedUi: true,
            shutdownClosed: true,
          }),
        );
      } catch (error) {
        writeFileSync(
          output,
          JSON.stringify({
            passed: false,
            error: String(error),
            stack: (error as Error).stack,
          }),
        );
        process.exitCode = 1;
      } finally {
        queue?.dispose();
        ctx.shutdown();
      }
    },
  });
}
