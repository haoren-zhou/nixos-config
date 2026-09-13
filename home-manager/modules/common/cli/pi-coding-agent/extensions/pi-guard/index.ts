import { fileURLToPath } from "node:url";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { dependencyPath } from "./dependencies.ts";
import guardRoot from "./guard-root.ts";
import { installChildSessionGuard } from "./child-session-guard.ts";

const { default: subagents } = await import(
  dependencyPath("pi-subagents", "index.ts")
);

// Pi gives each extension entrypoint a separate uncached loader graph. Import
// Nico and its factory adapter from this entrypoint so they share one graph.
export default function guardedSubagents(pi: ExtensionAPI): void {
  if (process.env.PI_SUBAGENT_CHILD === "1") return;
  const entry = fileURLToPath(import.meta.url);
  const verify = () => {
    installChildSessionGuard();
    const tool = pi.getAllTools().find((tool) => tool.name === "subagent");
    if (
      tool?.sourceInfo.path !== entry ||
      pi
        .getCommands()
        .some(
          (command) =>
            command.source === "extension" &&
            command.name.startsWith("subagents-") &&
            command.sourceInfo.path !== entry,
        )
    ) {
      throw new Error(
        "Guard: duplicate or unguarded Nico entrypoint; set the pi-subagents package extensions filter to [] and restart Pi",
      );
    }
  };
  guardRoot(pi, verify);
  // Also protect direct extension/RPC invocations, which need not emit the
  // model's tool_call event. Preserve Nico's argument, renderer and result APIs.
  const guardedApi: ExtensionAPI = {
    ...pi,
    registerTool(tool) {
      pi.registerTool({
        ...tool,
        execute(...args) {
          verify();
          return tool.execute(...args);
        },
      });
    },
    registerCommand(name, command) {
      pi.registerCommand(name, {
        ...command,
        handler(...args) {
          verify();
          return command.handler(...args);
        },
      });
    },
  };
  subagents(guardedApi);
}
