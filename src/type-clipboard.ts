import { Clipboard, closeMainWindow, environment, getPreferenceValues, showHUD } from "@raycast/api";
import { execFile } from "node:child_process";
import { chmod, mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";

interface Preferences {
  /** Milliseconds between keystrokes, as a dropdown value. */
  typingSpeed: string;
  /** Milliseconds to wait before the first keystroke, as a dropdown value. */
  startDelay: string;
  /** What to do with line breaks: `type`, `space` or `skip`. */
  newlines: string;
}

const DEFAULT_KEY_DELAY_MS = 20;
const DEFAULT_START_DELAY_MS = 250;

/** A helper that hangs (usually behind a permission prompt nobody answered) must not outlive the run. */
const MINIMUM_TIMEOUT_MS = 30_000;
const PER_CHARACTER_OVERHEAD_MS = 100;

/** The Swift helper's own exit codes, which say more than the message it printed. */
const ACCESSIBILITY_DENIED = 77;

export default async function Command() {
  const preferences = getPreferenceValues<Preferences>();
  const text = await Clipboard.readText();

  if (!text) {
    await showHUD("Clipboard is empty — nothing to type");
    return;
  }

  const keyDelay = milliseconds(preferences.typingSpeed, DEFAULT_KEY_DELAY_MS);
  const startDelay = milliseconds(preferences.startDelay, DEFAULT_START_DELAY_MS);
  const newlines = newlineMode(preferences.newlines);

  // The palette is non-activating, so hiding it hands focus straight back to the app the user was in.
  // The start delay then lets the hotkey's modifiers come up before the first character lands.
  await closeMainWindow();

  const helper = join(environment.assetsPath, "typer");
  const workDirectory = await mkdtemp(join(tmpdir(), "tinycast-typer-"));
  const textPath = join(workDirectory, "text.txt");

  try {
    // An install from a folder can lose the executable bit; `chmod` costs nothing and prevents it.
    await chmod(helper, 0o755).catch(() => undefined);
    await writeFile(textPath, normalise(text), "utf8");

    await run(
      helper,
      [textPath, String(keyDelay), String(startDelay), newlines],
      // The slowest setting is 300 ms per character, so the budget has to grow with the chosen delay.
      MINIMUM_TIMEOUT_MS + text.length * (keyDelay + PER_CHARACTER_OVERHEAD_MS),
    );
  } catch (error) {
    await showHUD(explain(error));
  } finally {
    await rm(workDirectory, { recursive: true, force: true }).catch(() => undefined);
  }
}

/** CRLF and lone CR both become a linefeed, which the helper types as one Return press. */
function normalise(text: string): string {
  return text.replace(/\r\n?/g, "\n");
}

function milliseconds(raw: string | undefined, fallback: number): number {
  const value = Number.parseInt(raw ?? "", 10);
  return Number.isFinite(value) && value >= 0 ? value : fallback;
}

function newlineMode(raw: string | undefined): "type" | "space" | "skip" {
  return raw === "space" || raw === "skip" ? raw : "type";
}

interface ProcessError extends Error {
  code?: number | string;
  killed?: boolean;
  stderr?: string;
}

function run(file: string, args: string[], timeout: number): Promise<{ stdout: string; stderr: string }> {
  return new Promise((resolve, reject) => {
    execFile(file, args, { timeout, maxBuffer: 1024 * 1024 }, (error, stdout, stderr) => {
      if (error) {
        reject(Object.assign(error, { stdout, stderr }));
        return;
      }
      resolve({ stdout, stderr });
    });
  });
}

/** Turns the failures people actually hit into something actionable. */
function explain(error: unknown): string {
  const failure = error as ProcessError;
  const stderr = typeof failure?.stderr === "string" ? failure.stderr : "";
  const message = stderr || failure?.message || String(error);

  if (failure?.code === ACCESSIBILITY_DENIED || /accessibility permission/i.test(message)) {
    return "Grant Tinycast Accessibility in System Settings › Privacy & Security › Accessibility";
  }
  if (/ENOENT/.test(message)) {
    return "The typing helper is missing — rebuild the extension with npm run build";
  }
  if (failure?.killed || /timed out|ETIMEDOUT/i.test(message)) {
    return "Typing timed out";
  }
  return `Typing failed: ${firstLine(message)}`;
}

function firstLine(value: string): string {
  const line = value.trim().split("\n")[0] ?? "";
  return line.length > 120 ? `${line.slice(0, 117)}…` : line;
}
