import { getMarkdownTheme, type ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Box, Markdown, Text } from "@earendil-works/pi-tui";

const ENTRY_TYPE = "pi-memory-write";
const MEMORY_TOOLS = new Set(["memory_add", "memory_replace", "memory_remove"]);

type MemoryWriteInput = {
  target?: string;
  content?: string;
  old_text?: string;
  category?: string;
  failure_reason?: string;
};

type MemoryWriteDetails = {
  success?: boolean;
  message?: string;
  target?: string;
  usage?: string;
  evicted_entries?: string[];
};

type MemoryWriteEntry = {
  action: "added" | "replaced" | "removed";
  target: string;
  content?: string;
  oldText?: string;
  category?: string;
  failureReason?: string;
  message?: string;
  usage?: string;
  evictedEntries?: string[];
};

function actionForTool(toolName: string): MemoryWriteEntry["action"] {
  if (toolName === "memory_replace") return "replaced";
  if (toolName === "memory_remove") return "removed";
  return "added";
}

export default function memoryDisplay(pi: ExtensionAPI): void {
  pi.registerEntryRenderer(ENTRY_TYPE, (entry, _options, theme) => {
    const data = entry.data as MemoryWriteEntry;
    const box = new Box(1, 0, (text: string) => theme.bg("customMessageBg", text));
    const action = data.action[0]?.toUpperCase() + data.action.slice(1);
    const scope = theme.fg("accent", data.target);

    box.addChild(new Text(theme.fg("customMessageLabel", theme.bold(`🧠 Memory ${action}`)), 0, 0));
    box.addChild(new Text(theme.fg("muted", scope + (data.category ? ` · ${data.category}` : "")), 0, 0));

    if (data.action === "removed") {
      box.addChild(new Text(theme.fg("dim", data.oldText ?? ""), 0, 0));
    } else if (data.content) {
      box.addChild(new Markdown(data.content, 0, 0, getMarkdownTheme()));
    }

    if (data.message) box.addChild(new Text(theme.fg("dim", data.message), 0, 0));
    if (data.usage) box.addChild(new Text(theme.fg("dim", data.usage), 0, 0));

    if (data.evictedEntries?.length) {
      box.addChild(new Text(theme.fg("warning", `Rotated ${data.evictedEntries.length} older entr${data.evictedEntries.length === 1 ? "y" : "ies"}.`), 0, 0));
    }

    return box;
  });

  pi.on("tool_result", (event) => {
    if (!MEMORY_TOOLS.has(event.toolName)) return;

    const details = event.details as MemoryWriteDetails | undefined;
    if (details?.success !== true) return;

    const input = event.input as MemoryWriteInput;
    pi.appendEntry(ENTRY_TYPE, {
      action: actionForTool(event.toolName),
      target: details.target ?? input.target ?? "memory",
      content: input.content,
      oldText: input.old_text,
      category: input.category,
      failureReason: input.failure_reason,
      message: details.message,
      usage: details.usage,
      evictedEntries: details.evicted_entries,
    } satisfies MemoryWriteEntry);
  });
}
