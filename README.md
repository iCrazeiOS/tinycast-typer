# Tinycast Typer

A [Tinycast](https://github.com/abue-ammar/tinycast) extension (Raycast-compatible) that **types your clipboard
into the frontmost app, one character at a time**. Nothing is pasted: the clipboard is left untouched, no ⌘V is sent,
and the receiving app sees real keystrokes.

It installs as **Clipboard Typer**, with a single command, **Type Clipboard**.

```
hotkey → read clipboard → hide palette → type each character into the app you were in
```

## Why a compiled helper

Tinycast runs extensions in JavaScriptCore, which has no keyboard API. The conventional escape hatch is AppleScript's
`System Events` `keystroke`, but on macOS 26/27 it maps every non-ASCII character through the active keyboard layout
and falls back to `a`, so `é`, `→`, `世界` and emoji come out as garbage.

So `assets/typer` is a small Swift binary (`Scripts/typer.swift`, universal, ~60 KB per architecture) that posts one
unicode `CGEvent` key down/up pair per character. That is layout-independent, fast, and types accents, CJK and emoji
exactly. The extension writes the clipboard to a private temp file, hands it to the helper with the speed settings,
and deletes it afterwards.

## Install

Requires macOS 26 or later (Tinycast's own minimum). Tinycast must have **Accessibility** permission
(System Settings → Privacy & Security → Accessibility) — Tinycast already asks for it to paste, and the typing helper
runs under the same permission.

```sh
npm install
npm run build      # compiles assets/typer, then emits the installable extension into dist/
```

Building the helper needs the Xcode command line tools (`swiftc`); it is compiled locally from
`Scripts/typer.swift` and is not committed.

Then, in Tinycast:

1. Settings → Extensions → enable extensions, if you haven't.
2. **Install New → Add from folder** → choose this project's `dist/` folder.
3. Find **Type Clipboard** in the launcher, open its Actions, and bind a global hotkey (e.g. ⌃⌥⌘V).
   Raycast-style deeplinks work too: `tinycast://extensions/local/tinycast-typer/type-clipboard`.

`dist/` is the whole extension: `package.json`, `type-clipboard.js` and `assets/` (icon + helper). It is also the
folder to hand to any other Tinycast install route (GitHub / folder) — it needs no `node_modules`.

## Preferences

Settings → Extensions → Clipboard Typer → Type Clipboard → Configure:

| Preference | Default | What it does |
| --- | --- | --- |
| **Typing Speed** | 20 ms | Delay between characters, 0–300 ms in 17 steps. `Instant` types as fast as the events post. |
| **Start Delay** | 250 ms | Wait before the first keystroke, 0–3 s in 15 steps, so the hotkey's modifiers come up and focus settles. |
| **Line Breaks** | Type them | Typing a line break is faithful, but it sends a chat message or runs a command in Terminal. Choose *space* or *skip* to flatten multi-line text. |

Typing time is linear: roughly `characters × (speed + ~2 ms)`. A 1,000-character clipboard at the default speed takes
about 25 seconds.

## Behaviour notes

- **Focus** — the palette is a non-activating panel, so hiding it returns focus to the app you were in; nothing is
  activated or brought forward. Text is typed into whatever holds focus at that moment.
- **Empty clipboard** — a HUD says so and nothing is typed. Image-only clipboards count as empty (no text).
- **Clipboard is not modified**, and the temp file holding the text is deleted after every run.
- **Permission failure** — the HUD points at the exact System Settings pane. If macOS attributes the helper
  separately from Tinycast, add `assets/typer` from the installed extension to Accessibility as well.
- Apps that refuse synthetic events (some password fields and games) will ignore the typing, as with any
  automation tool.

## Development

```
package.json          Raycast manifest: one no-view command + its preferences
src/type-clipboard.ts the command: clipboard → temp file → helper, error → HUD
Scripts/typer.swift   the CGEvent typing helper
Scripts/build-typer.sh  universal build + ad-hoc sign → assets/typer
Scripts/make-icon.swift regenerates assets/icon.png (512×512)
build.mjs             esbuild → dist/ (helper + bundle + manifest + assets)
```

```sh
npm run typecheck   # tsc --noEmit
npm run build       # helper + bundle + dist/
```

The bundle keeps `@raycast/api`, `react` and `node:*` external, which is what Tinycast supplies at run time.
