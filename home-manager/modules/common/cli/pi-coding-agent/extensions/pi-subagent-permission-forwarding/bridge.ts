import * as path from "node:path";

export const SUBAGENT_CHILD_ENV = "PI_SUBAGENT_CHILD";
export const SUBAGENT_PI_BINARY_ENV = "PI_SUBAGENT_PI_BINARY";
export const SUBAGENT_PARENT_SESSION_ENV = "PI_SUBAGENT_PARENT_SESSION";

export const BRIDGE_ROOT_SESSION_ENV = "PI_PERMISSION_FORWARDING_ROOT_SESSION";
export const BRIDGE_NODE_ENV = "PI_PERMISSION_FORWARDING_NODE";
export const BRIDGE_CLI_ENV = "PI_PERMISSION_FORWARDING_CLI";
export const BRIDGE_DELEGATE_ENV =
  "PI_PERMISSION_FORWARDING_DELEGATE_PI_BINARY";

const MANAGED_ENV_KEYS = [
  SUBAGENT_PI_BINARY_ENV,
  BRIDGE_ROOT_SESSION_ENV,
  BRIDGE_NODE_ENV,
  BRIDGE_CLI_ENV,
  BRIDGE_DELEGATE_ENV,
] as const;

export interface BridgeInstallOptions {
  env: NodeJS.ProcessEnv;
  sessionId: string;
  wrapperPath: string;
  nodePath: string;
  cliPath: string;
  delegateBinary?: string;
}

export interface BridgeInstallation {
  restore(): void;
}

export function normalizeSessionId(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const normalized = value.trim();
  if (!normalized || normalized.toLowerCase() === "unknown") return null;
  return /^[A-Za-z0-9._:-]+$/.test(normalized) ? normalized : null;
}

/**
 * A standalone Pi executable is the Bun-compiled `pi` binary: it cannot be
 * driven through an interpreter recipe (nodePath + cliPath) because the
 * archive's synthesized entry path (process.argv[1] = "/$bunfs/root/pi")
 * is not an on-disk CLI script. Such binaries must be spawned directly.
 */
export function isStandalonePiExecutable(execPath: string): boolean {
  const executableName = execPath.split(/[\\/]/).pop();
  return /^pi(?:\.exe)?$/i.test(executableName ?? "");
}

export function isChildProcess(env: NodeJS.ProcessEnv): boolean {
  const marker = env[SUBAGENT_CHILD_ENV];
  return typeof marker === "string" && marker.trim().length > 0;
}

/**
 * nicobailon/pi-subagents currently writes PI_SUBAGENT_PARENT_SESSION into
 * the interactive root process. The permission-system convention treats that
 * variable itself as a child marker, so the root stops serving its inbox.
 * Remove it only in a process that lacks pi-subagents' explicit child marker.
 */
export function clearRootParentSessionMarker(env: NodeJS.ProcessEnv): void {
  if (!isChildProcess(env)) delete env[SUBAGENT_PARENT_SESSION_ENV];
}

/** Remove bridge state inherited by a separately launched headless root. */
export function deactivateInheritedBridgeEnvironment(
  env: NodeJS.ProcessEnv,
  wrapperPath: string,
): void {
  if (isChildProcess(env)) return;

  const configuredBinary = env[SUBAGENT_PI_BINARY_ENV]?.trim();
  const bridgeOwnsBinary = configuredBinary
    ? path.isAbsolute(configuredBinary) &&
      path.resolve(configuredBinary) === path.resolve(wrapperPath)
    : false;
  if (bridgeOwnsBinary) {
    const delegate = env[BRIDGE_DELEGATE_ENV]?.trim();
    if (delegate) env[SUBAGENT_PI_BINARY_ENV] = delegate;
    else delete env[SUBAGENT_PI_BINARY_ENV];
  }

  delete env[BRIDGE_ROOT_SESSION_ENV];
  delete env[BRIDGE_NODE_ENV];
  delete env[BRIDGE_CLI_ENV];
  delete env[BRIDGE_DELEGATE_ENV];
}

export function validateLaunchRecipe(
  options: Pick<BridgeInstallOptions, "wrapperPath" | "nodePath" | "cliPath">,
): void {
  const paths = {
    wrapperPath: options.wrapperPath,
    nodePath: options.nodePath,
    cliPath: options.cliPath,
  };
  for (const [label, value] of Object.entries(paths)) {
    if (!path.isAbsolute(value)) {
      throw new Error(`${label} must be an absolute path.`);
    }
  }
  if (path.resolve(options.wrapperPath) === path.resolve(options.nodePath)) {
    throw new Error(
      "The bridge wrapper and Node executable must be different paths.",
    );
  }
}

export function installBridgeEnvironment(
  options: BridgeInstallOptions,
): BridgeInstallation {
  const sessionId = normalizeSessionId(options.sessionId);
  if (!sessionId)
    throw new Error("The interactive Pi session has no valid session ID.");
  validateLaunchRecipe(options);

  const { env } = options;
  const before = new Map<string, string | undefined>();
  for (const key of MANAGED_ENV_KEYS) before.set(key, env[key]);

  const existingBinary = env[SUBAGENT_PI_BINARY_ENV]?.trim();
  const existingIsWrapper = existingBinary
    ? path.isAbsolute(existingBinary) &&
      path.resolve(existingBinary) === path.resolve(options.wrapperPath)
    : false;
  const delegate =
    existingBinary && !existingIsWrapper
      ? existingBinary
      : (options.delegateBinary ?? env[BRIDGE_DELEGATE_ENV])?.trim();

  const installed = new Map<string, string | undefined>([
    [SUBAGENT_PI_BINARY_ENV, options.wrapperPath],
    [BRIDGE_ROOT_SESSION_ENV, sessionId],
    [BRIDGE_NODE_ENV, options.nodePath],
    [BRIDGE_CLI_ENV, options.cliPath],
    [BRIDGE_DELEGATE_ENV, delegate || undefined],
  ]);

  for (const [key, value] of installed) {
    if (value === undefined) delete env[key];
    else env[key] = value;
  }

  let restored = false;
  return {
    restore() {
      if (restored) return;
      restored = true;
      for (const [key, installedValue] of installed) {
        if (env[key] !== installedValue) continue;
        const original = before.get(key);
        if (original === undefined) delete env[key];
        else env[key] = original;
      }
    },
  };
}
