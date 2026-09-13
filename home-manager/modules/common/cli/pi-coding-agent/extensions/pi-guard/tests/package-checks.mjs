// Run with Node; optional args compare original source and repository settings.
import assert from "node:assert/strict";
import { existsSync, readFileSync, readdirSync, realpathSync } from "node:fs";
import { createRequire } from "node:module";
import { homedir } from "node:os";
import { extname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("../", import.meta.url));
const agentDir =
  process.env.PI_CODING_AGENT_DIR || join(homedir(), ".pi", "agent");
const modules = join(agentDir, "npm", "node_modules");
const json = (path) => JSON.parse(readFileSync(path, "utf8"));
const manifest = json(join(root, "package.json"));
assert.equal(manifest.name, "pi-guard");
assert.deepEqual(manifest.pi.extensions, ["./index.ts"]);
assert(
  !existsSync(join(root, "..", "pi-subagent-permission-forwarding")),
  "the replaced forwarding bridge must not be packaged",
);
const plugins = ["@gotgenes/pi-permission-system", "pi-subagents"];
for (const name of plugins) {
  assert.equal(
    manifest.peerDependencies[name],
    "*",
    "release numbers are not a compatibility gate",
  );
  assert.equal(json(join(modules, name, "package.json")).name, name);
}
const require = createRequire(join(agentDir, "npm", "package.json"));
for (const [specifier, entry] of [
  ["pi-subagents", "pi-subagents/index.ts"],
  ["pi-subagents/background-work", "pi-subagents/src/api/background-work.ts"],
  [
    "@gotgenes/pi-permission-system",
    "@gotgenes/pi-permission-system/src/service.ts",
  ],
]) {
  assert.equal(
    realpathSync(require.resolve(specifier)),
    realpathSync(
      join(
        modules,
        entry.replace(/\.ts$/, extname(require.resolve(specifier))),
      ),
    ),
    "entrypoints must belong to the configured Pi installation",
  );
}

let compared = 0;
function checkSource(source, relative = "") {
  for (const entry of readdirSync(join(source, relative), {
    withFileTypes: true,
  })) {
    if (entry.name === "node_modules") continue;
    const path = join(relative, entry.name);
    if (entry.isDirectory()) checkSource(source, path);
    else {
      const original = readFileSync(join(source, path));
      assert.deepEqual(
        readFileSync(join(root, path)),
        original,
        `packaging must not rewrite ${path}`,
      );
      compared++;
    }
  }
}
if (process.argv[2]) checkSource(process.argv[2]);
if (process.argv[3]) {
  const packages = json(process.argv[3]).packages;
  for (const name of plugins) {
    const entries = packages.filter((entry) =>
      (typeof entry === "string" ? entry : entry.source).startsWith(
        `npm:${name}@`,
      ),
    );
    assert.equal(entries.length, 1, `one settings pin for ${name}`);
    const entry = entries[0];
    if (name === "pi-subagents")
      assert.deepEqual(
        entry.extensions,
        [],
        "only the adapter loads Nico's entrypoint",
      );
  }
}
console.log(
  JSON.stringify({
    packageLayout: true,
    legacyBridgeAbsent: true,
    pluginsPresent: true,
    sameDependencyInstallation: true,
    sourceDependencyLink: existsSync(join(root, "node_modules")),
    sourceFilesCompared: compared,
  }),
);
