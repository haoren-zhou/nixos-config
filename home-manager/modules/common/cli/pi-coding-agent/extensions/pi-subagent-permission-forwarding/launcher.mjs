#!/usr/bin/env node

import { spawn } from "node:child_process";
import * as path from "node:path";

const ROOT_SESSION_ENV = "PI_PERMISSION_FORWARDING_ROOT_SESSION";
const NODE_ENV = "PI_PERMISSION_FORWARDING_NODE";
const CLI_ENV = "PI_PERMISSION_FORWARDING_CLI";
const DELEGATE_ENV = "PI_PERMISSION_FORWARDING_DELEGATE_PI_BINARY";
const PARENT_SESSION_ENV = "PI_SUBAGENT_PARENT_SESSION";

function validSessionId(value) {
  if (typeof value !== "string") return null;
  const normalized = value.trim();
  if (!normalized || normalized.toLowerCase() === "unknown") return null;
  return /^[A-Za-z0-9._:-]+$/.test(normalized) ? normalized : null;
}

function commandValue(value) {
  if (typeof value !== "string") return null;
  const normalized = value.trim();
  return normalized && !normalized.includes("\0") ? normalized : null;
}

function absolutePath(value) {
  const normalized = commandValue(value);
  return normalized && path.isAbsolute(normalized) ? normalized : null;
}

function fail(message) {
  process.stderr.write(`[pi-subagent-permission-forwarding] ${message}\n`);
  process.exitCode = 126;
}

const rootSessionId = validSessionId(process.env[ROOT_SESSION_ENV]);
if (!rootSessionId) {
  fail(`Refusing to launch a child without a valid ${ROOT_SESSION_ENV}.`);
} else {
  const wrapperPath = path.resolve(process.argv[1]);
  const delegate = commandValue(process.env[DELEGATE_ENV]);
  const nodePath = absolutePath(process.env[NODE_ENV]);
  const cliPath = absolutePath(process.env[CLI_ENV]);
  const delegateIsWrapper = delegate && path.isAbsolute(delegate) && path.resolve(delegate) === wrapperPath;

  let command;
  let prefixArgs;
  if (delegate && !delegateIsWrapper) {
    command = delegate;
    prefixArgs = [];
  } else if (nodePath && cliPath) {
    command = nodePath;
    prefixArgs = [cliPath];
  } else {
    fail("Refusing to launch a child because no valid delegated binary or Pi CLI recipe is available.");
  }

  if (command) {
    const childEnv = {
      ...process.env,
      [PARENT_SESSION_ENV]: rootSessionId,
    };
    const child = spawn(command, [...prefixArgs, ...process.argv.slice(2)], {
      env: childEnv,
      shell: false,
      stdio: "inherit",
      windowsHide: true,
    });

    const forwardedSignals = ["SIGINT", "SIGTERM", "SIGHUP"];
    for (const signal of forwardedSignals) {
      process.on(signal, () => {
        if (!child.killed) child.kill(signal);
      });
    }

    child.once("error", (error) => {
      process.stderr.write(`[pi-subagent-permission-forwarding] Failed to start child Pi: ${error.message}\n`);
      process.exitCode = 127;
    });

    child.once("exit", (code, signal) => {
      if (signal) {
        for (const forwarded of forwardedSignals) process.removeAllListeners(forwarded);
        try {
          process.kill(process.pid, signal);
        } catch {
          process.exitCode = 1;
        }
        return;
      }
      process.exitCode = code ?? 1;
    });
  }
}
