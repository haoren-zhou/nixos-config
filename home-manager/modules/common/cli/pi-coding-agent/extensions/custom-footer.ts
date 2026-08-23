import type { AssistantMessage } from "@earendil-works/pi-ai";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

const SEPARATOR = "  ";
const PERMISSION_STATUS_KEY = "pi-permission-system";

export function formatTokens(count: number): string {
  if (count < 1_000) return `${count}`;
  if (count < 10_000) return `${(count / 1_000).toFixed(1)}k`;
  if (count < 1_000_000) return `${Math.round(count / 1_000)}k`;
  if (count < 10_000_000) return `${(count / 1_000_000).toFixed(1)}M`;
  return `${Math.round(count / 1_000_000)}M`;
}

export function calculateCacheHitRate(
  input: number,
  cacheRead: number,
  cacheWrite: number,
): number | undefined {
  const promptTokens = input + cacheRead + cacheWrite;
  return promptTokens > 0 ? (cacheRead / promptTokens) * 100 : undefined;
}

export function wrapSegments(segments: string[], width: number): string[] {
  if (segments.length === 0 || width <= 0) return [];

  const lines: string[] = [];
  let current = "";

  for (const segment of segments) {
    const bounded = truncateToWidth(segment, width);
    const candidate = current ? `${current}${SEPARATOR}${bounded}` : bounded;

    if (!current || visibleWidth(candidate) <= width) {
      current = candidate;
      continue;
    }

    lines.push(current);
    current = bounded;
  }

  if (current) lines.push(current);
  return lines;
}

export function formatThinkingLevel(level: string | undefined): string {
  return level ?? "off";
}

function formatCwd(cwd: string): string {
  const home = process.env.HOME || process.env.USERPROFILE;
  if (!home) return cwd;
  if (cwd === home) return "~";
  return cwd.startsWith(`${home}/`) ? `~${cwd.slice(home.length)}` : cwd;
}

export default function customFooter(pi: ExtensionAPI): void {
  pi.on("session_start", async (_event, ctx) => {
    if (ctx.mode !== "tui") return;

    ctx.ui.setFooter((tui, theme, footerData) => {
      const unsubscribeBranch = footerData.onBranchChange(() => tui.requestRender());

      return {
        dispose: unsubscribeBranch,
        invalidate() {},
        render(width: number): string[] {
          let input = 0;
          let output = 0;
          let latestCacheHitRate: number | undefined;

          for (const entry of ctx.sessionManager.getBranch()) {
            if (entry.type !== "message" || entry.message.role !== "assistant") continue;

            const message = entry.message as AssistantMessage;
            input += message.usage.input;
            output += message.usage.output;
            latestCacheHitRate = calculateCacheHitRate(
              message.usage.input,
              message.usage.cacheRead,
              message.usage.cacheWrite,
            );
          }

          const branch = footerData.getGitBranch();
          const usage = ctx.getContextUsage();
          const contextPercent = usage?.percent;
          const contextColor =
            contextPercent === null || contextPercent === undefined
              ? "muted"
              : contextPercent >= 90
                ? "error"
                : contextPercent >= 70
                  ? "warning"
                  : "success";
          const context =
            contextPercent === null || contextPercent === undefined
              ? "?"
              : `${Math.round(contextPercent)}%/${formatTokens(usage.contextWindow)}`;

          const statuses = footerData.getExtensionStatuses();
          const yolo = statuses.get(PERMISSION_STATUS_KEY) === "yolo";
          const model = [
            theme.fg("accent", ctx.model?.id ?? "no-model"),
            theme.fg("dim", ":"),
            theme.fg("warning", formatThinkingLevel(ctx.thinkingLevel)),
          ].join("");

          const segments = [
            theme.bold(theme.fg("accent", formatCwd(ctx.cwd))),
            ...(branch ? [theme.fg("success", branch)] : []),
            model,
            theme.fg(contextColor, context),
            theme.fg("muted", `↑${formatTokens(input)} ↓${formatTokens(output)}`),
            theme.fg(
              "dim",
              latestCacheHitRate === undefined
                ? "CH?"
                : `CH${latestCacheHitRate.toFixed(1)}%`,
            ),
            yolo
              ? theme.bold(theme.fg("error", "yolo"))
              : theme.fg("success", "guard"),
          ];

          return wrapSegments(segments, width);
        },
      };
    });
  });
}
