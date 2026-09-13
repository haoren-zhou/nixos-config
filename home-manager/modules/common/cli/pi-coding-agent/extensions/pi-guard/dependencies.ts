import { readFileSync, realpathSync } from "node:fs";
import { join } from "node:path";
import { getAgentDir } from "@earendil-works/pi-coding-agent";

export type Plugin = "pi-subagents" | "@gotgenes/pi-permission-system";

// These are installed Pi plugins, not dependencies beside this source file.
// Canonical paths keep symlink deployments in the same Pi loader graph.
// Return paths only; the caller's import() must use Pi's existing loader.
export function dependencyPath(plugin: Plugin, file: string): string {
  const root = join(getAgentDir(), "npm", "node_modules", plugin);
  if (file.endsWith(".ts")) {
    const manifest = JSON.parse(
      readFileSync(join(root, "package.json"), "utf8"),
    );
    const exported = manifest.exports?.["."];
    const entry = typeof exported === "string" ? exported : exported?.default;
    // Follow the package's runtime layout, not its release number. Do not fall
    // back per file: mixing source and compiled factories can split authority.
    if (typeof entry === "string" && entry.endsWith(".js")) {
      file = file.slice(0, -3) + ".js";
    }
  }
  // Resolve the entry too: packages can contain symlinked files/directories.
  // Distinct lexical paths to one factory would split its loader identity.
  return realpathSync(join(root, file));
}
