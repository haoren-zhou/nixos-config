import * as fs from "node:fs";
import { fileURLToPath } from "node:url";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import {
  clearRootParentSessionMarker,
  deactivateInheritedBridgeEnvironment,
  installBridgeEnvironment,
  isChildProcess,
  type BridgeInstallation,
} from "./bridge.ts";

const WRAPPER_PATH = fileURLToPath(new URL("./launcher.mjs", import.meta.url));

export default function piSubagentPermissionForwarding(pi: ExtensionAPI): void {
  let installation: BridgeInstallation | null = null;
  let clearMarkerImmediate: NodeJS.Immediate | null = null;

  const clearRootMarker = () => {
    if (installation) clearRootParentSessionMarker(process.env);
  };

  const restore = () => {
    if (clearMarkerImmediate) clearImmediate(clearMarkerImmediate);
    clearMarkerImmediate = null;
    installation?.restore();
    installation = null;
  };

  pi.on("session_start", (_event, ctx) => {
    restore();

    // A child retains the anchor inherited from its interactive root. A
    // separately launched headless root must drop any bridge state inherited
    // from the shell that launched it, because it cannot host a human dialog.
    if (isChildProcess(process.env)) return;
    if (!ctx.hasUI) {
      deactivateInheritedBridgeEnvironment(process.env, WRAPPER_PATH);
      return;
    }

    const sessionId = ctx.sessionManager.getSessionId();
    const cliPath = process.argv[1];
    try {
      if (!fs.existsSync(WRAPPER_PATH)) {
        throw new Error(`Bridge launcher is missing at ${WRAPPER_PATH}.`);
      }
      if (!cliPath || !fs.existsSync(cliPath)) {
        throw new Error("The running Pi CLI entry point could not be resolved.");
      }
      if (!fs.existsSync(process.execPath)) {
        throw new Error(`The Node executable is missing at ${process.execPath}.`);
      }

      installation = installBridgeEnvironment({
        env: process.env,
        sessionId,
        wrapperPath: WRAPPER_PATH,
        nodePath: process.execPath,
        cliPath,
      });
      // Let every session_start handler finish first. pi-subagents sets the
      // parent-session variable during its own handler even in the UI root.
      clearMarkerImmediate = setImmediate(() => {
        clearMarkerImmediate = null;
        clearRootMarker();
      });
    } catch (error) {
      restore();
      const message = error instanceof Error ? error.message : String(error);
      ctx.ui.notify(`Subagent permission forwarding bridge disabled: ${message}`, "error");
    }
  });

  // Clear again at turn boundaries so permission-system handlers loaded later
  // see the root as a serving UI session even after session replacement.
  pi.on("input", () => {
    clearRootMarker();
  });

  pi.on("before_agent_start", () => {
    clearRootMarker();
  });

  pi.on("session_shutdown", () => {
    restore();
  });
}
