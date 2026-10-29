import { execFileSync } from "node:child_process";
import { cp, mkdir, rm } from "node:fs/promises";
import { build } from "esbuild";

// `dist/` is exactly what Tinycast expects from an installed extension: `package.json`, one
// `<command>.js` beside it, and `assets/`. No node_modules: everything is inlined except
// `@raycast/api`, which the host supplies.
const output = "dist";

// The typer is a compiled Swift helper, not a script: every character is a unicode key event, which
// is the only way to type accents, CJK and emoji without going through the keyboard layout.
execFileSync("bash", ["Scripts/build-typer.sh"], { stdio: "inherit" });

await rm(output, { recursive: true, force: true });
await mkdir(`${output}/assets`, { recursive: true });

await build({
  entryPoints: ["src/type-clipboard.ts"],
  outfile: `${output}/type-clipboard.js`,
  bundle: true,
  format: "cjs",
  platform: "node",
  target: "node22",
  external: ["@raycast/api", "react", "react/jsx-runtime", "node:*"],
  legalComments: "none",
  logLevel: "info",
});

await cp("package.json", `${output}/package.json`);
await cp("assets", `${output}/assets`, { recursive: true });
