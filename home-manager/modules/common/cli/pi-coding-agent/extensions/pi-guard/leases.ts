import { randomUUID, createHash } from "node:crypto";
import {
  closeSync,
  constants,
  fstatSync,
  lstatSync,
  mkdirSync,
  openSync,
  readFileSync,
  unlinkSync,
  writeFileSync,
} from "node:fs";
import { join } from "node:path";
import { getAgentDir, getPackageDir } from "@earendil-works/pi-coding-agent";
import { dependencyPath } from "./dependencies.ts";
import { getPermissionsService, hosts, live } from "./shared.ts";

const { computeExtensionPaths } = await import(
  dependencyPath(
    "@gotgenes/pi-permission-system",
    "src/config/extension-paths.ts",
  )
);
const { ServingHeartbeatStore } = await import(
  dependencyPath(
    "@gotgenes/pi-permission-system",
    "src/authority/forwarding-liveness.ts",
  )
);
const { getServingSessionRegistry } = await import(
  dependencyPath(
    "@gotgenes/pi-permission-system",
    "src/authority/serving-registry.ts",
  )
);

export interface LeaseRef {
  sessionId: string;
  generation: string;
}
export interface Lease extends LeaseRef {
  version: 1;
  pid: number;
  processStart: string;
  parent?: LeaseRef;
}
function fail(message: string): never {
  throw new Error(`Guard binding: ${message}`);
}
const validId = (value: unknown): value is string =>
  typeof value === "string" && value.length > 0 && value.length <= 256;
function isLeaseRef(value: unknown): value is LeaseRef {
  if (!value || typeof value !== "object") return false;
  const ref = value as Partial<LeaseRef>;
  return (
    validId(ref.sessionId) &&
    typeof ref.generation === "string" &&
    /^[a-f0-9-]{36}$/.test(ref.generation)
  );
}
function isLease(value: unknown): value is Lease {
  if (!isLeaseRef(value)) return false;
  const lease = value as Partial<Lease>;
  return (
    lease.version === 1 &&
    typeof lease.pid === "number" &&
    Number.isInteger(lease.pid) &&
    lease.pid > 0 &&
    typeof lease.processStart === "string" &&
    /^\d+$/.test(lease.processStart) &&
    (lease.parent === undefined || isLeaseRef(lease.parent))
  );
}
const directory = () => join(getAgentDir(), "pi-guard", "leases");
const pathFor = (sessionId: string) =>
  join(
    directory(),
    createHash("sha256").update(sessionId).digest("hex") + ".json",
  );
function privateDirectory() {
  if (process.platform !== "linux")
    fail("Linux /proc is required for process-identity checks");
  for (const path of [join(getAgentDir(), "pi-guard"), directory()]) {
    mkdirSync(path, { recursive: true, mode: 0o700 });
    const info = lstatSync(path);
    if (
      !info.isDirectory() ||
      info.isSymbolicLink() ||
      info.uid !== process.getuid!() ||
      info.mode & 0o077
    )
      fail("state directory is not private");
  }
}
function processStart(pid: number): string | undefined {
  try {
    const stat = readFileSync(`/proc/${pid}/stat`, "utf8");
    const fields = stat.slice(stat.lastIndexOf(")") + 2).split(" ");
    if (["Z", "X"].includes(fields[0])) return;
    return fields[19];
  } catch {
    return;
  }
}
export function readLease(sessionId: string): Lease | undefined {
  if (!validId(sessionId)) return;
  let fd: number | undefined;
  try {
    privateDirectory();
    fd = openSync(
      pathFor(sessionId),
      constants.O_RDONLY | constants.O_NOFOLLOW,
    );
    const stat = fstatSync(fd);
    if (
      !stat.isFile() ||
      stat.uid !== process.getuid!() ||
      stat.mode & 0o077 ||
      stat.size > 4096
    )
      return;
    const data: unknown = JSON.parse(readFileSync(fd, "utf8"));
    if (!isLease(data) || data.sessionId !== sessionId) return;
    return data;
  } catch {
    return;
  } finally {
    if (fd !== undefined) closeSync(fd);
  }
}
export function assertLeaseLive(expected: LeaseRef): Lease {
  let current: LeaseRef | undefined = expected;
  const seen = new Set<string>();
  let first: Lease | undefined;
  const heartbeats = new ServingHeartbeatStore({
    forwardingDir: computeExtensionPaths(getAgentDir(), getPackageDir())
      .forwardingDir,
    logger: { debug() {}, review() {} },
  });
  while (current) {
    if (seen.has(current.sessionId) || seen.size >= 128)
      fail("cyclic or excessive parent chain");
    seen.add(current.sessionId);
    const lease = readLease(current.sessionId);
    if (
      !lease ||
      lease.generation !== current.generation ||
      processStart(lease.pid) !== lease.processStart
    )
      fail("parent generation ended or process disappeared");
    if (lease.pid === process.pid) {
      if (
        !getPermissionsService(lease.sessionId) ||
        !getServingSessionRegistry().isServing(lease.sessionId)
      )
        fail("local permission service is not serving");
      if (
        !lease.parent &&
        ![...hosts().values()].some(
          (host) => host.sessionId === lease.sessionId && live(host),
        )
      )
        fail("local root generation is inactive");
    } else if (heartbeats.read(lease.sessionId) !== "alive")
      fail("remote permission service is not serving");
    first ??= lease;
    current = lease.parent;
  }
  return first ?? fail("missing parent binding");
}
export function acquireLease(sessionId: string, parent?: LeaseRef): Lease {
  if (!validId(sessionId)) fail("invalid session identity");
  if (parent) {
    assertLeaseLive(parent);
    let ancestor: LeaseRef | undefined = parent;
    while (ancestor) {
      if (ancestor.sessionId === sessionId)
        fail("child identity collides with an ancestor");
      ancestor = readLease(ancestor.sessionId)?.parent;
    }
  }
  privateDirectory();
  const previous = readLease(sessionId);
  if (previous) {
    if (processStart(previous.pid) === previous.processStart)
      fail("session already has a live owner");
    // Dead owners only; never reclaim a live sibling or resume concurrently.
    releaseLease(previous);
  }
  const start =
    processStart(process.pid) ?? fail("cannot identify current process");
  const lease: Lease = {
    version: 1,
    sessionId,
    generation: randomUUID(),
    pid: process.pid,
    processStart: start,
    ...(parent
      ? {
          parent: {
            sessionId: parent.sessionId,
            generation: parent.generation,
          },
        }
      : {}),
  };
  writeFileSync(pathFor(sessionId), JSON.stringify(lease), {
    flag: "wx",
    mode: 0o600,
  });
  return lease;
}
export function releaseLease(lease: Lease): void {
  const current = readLease(lease.sessionId);
  if (current?.generation !== lease.generation) return;
  try {
    unlinkSync(pathFor(lease.sessionId));
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code !== "ENOENT") throw error;
  }
}
