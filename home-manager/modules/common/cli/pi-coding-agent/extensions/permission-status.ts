import { readFileSync } from "node:fs";
import { join } from "node:path";
import { getAgentDir, type ExtensionAPI, type ExtensionContext } from "@earendil-works/pi-coding-agent";

const STATUS_KEY = "permissions";
const GLOBAL_CONFIG_PATH = join(
  getAgentDir(),
  "extensions",
  "pi-permission-system",
  "config.json",
);

const COLORS = {
  guard: "\x1b[1;38;2;142;192;124m",
  yolo: "\x1b[1;38;2;251;73;52m",
  reset: "\x1b[0m",
};

function readBooleanOption(path: string): boolean | undefined {
  try {
    const raw = readFileSync(path, "utf8");
    const parsed = JSON.parse(raw) as { yoloMode?: unknown };
    return typeof parsed.yoloMode === "boolean" ? parsed.yoloMode : undefined;
  } catch {
    return undefined;
  }
}

function isYoloMode(ctx: ExtensionContext): boolean {
  let yoloMode = readBooleanOption(GLOBAL_CONFIG_PATH) ?? false;
  if (ctx.isProjectTrusted()) {
    yoloMode =
      readBooleanOption(join(ctx.cwd, ".pi/extensions/pi-permission-system/config.json")) ??
      yoloMode;
  }
  return yoloMode;
}

let lastStatus: string | undefined;
let statusPoller: ReturnType<typeof setInterval> | undefined;

function publishStatus(ctx: ExtensionContext): void {
  if (!ctx.hasUI) return;

  const yolo = isYoloMode(ctx);
  const label = yolo ? "yolo" : "guard";
  const color = yolo ? COLORS.yolo : COLORS.guard;
  const status = `${color}${label}${COLORS.reset}`;
  if (status === lastStatus) return;

  ctx.ui.setStatus(STATUS_KEY, status);
  lastStatus = status;
}

export default function permissionStatus(pi: ExtensionAPI): void {
  pi.on("session_start", (_event, ctx) => {
    publishStatus(ctx);
    if (!ctx.hasUI) return;

    if (statusPoller) clearInterval(statusPoller);
    statusPoller = setInterval(() => publishStatus(ctx), 500);
  });
  pi.on("resources_discover", (_event, ctx) => publishStatus(ctx));
  pi.on("turn_start", (_event, ctx) => publishStatus(ctx));
  pi.on("session_shutdown", (_event, ctx) => {
    if (statusPoller) clearInterval(statusPoller);
    statusPoller = undefined;
    lastStatus = undefined;
    if (ctx.hasUI) ctx.ui.setStatus(STATUS_KEY, undefined);
  });
}
