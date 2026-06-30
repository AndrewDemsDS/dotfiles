# Roadmap

Feature backlog for the widget layer this fork adds on top of
[illogical-impulse](https://github.com/end-4/dots-hyprland). Derived from a survey of prior art
across Quickshell/AGS/eww rices, macOS power tools (Raycast, Sketchybar, Übersicht), Windows
PowerToys, and KDE/GNOME, then filtered to what the `ii` config here does **not** already have.

Each item is sized against the "done" checklist in [CONTRIBUTING.md](CONTRIBUTING.md): an enable
flag in `Config.qml`, gating on `Config.ready && enable`, a **Settings → Custom** entry, and any
shelled-out tool recorded in `setup/dependencies.txt`.

Status legend: `[ ]` queued, `[~]` in progress, `[x]` shipped.

## Build order

| # | Feature | Value | Effort | Keybind |
|---|---------|-------|--------|---------|
| 1 | Command palette + Quicklinks | quick action | M-H | `Super+Alt+Space` |
| 2 | Clipboard history + snippets | quick action / dev | M | `Super+Alt+V` |
| 3 | PR/issue quick-action board | dev | M | `Super+Alt+R` |
| 4 | Eye-care break overlay | ambient | L | `Super+Alt+B` (snooze) |
| 5 | ~~Secrets surfacing~~ — dropped (redundant) | dev / security | M | — |
| 6 | Bar popups + inline graphs | glanceable | L-M | n/a (bar) |
| 7 | Recon MCP backend (reconLauncher) | security | M | existing `Super+Alt+P` |

---

## 1. Command palette + Quicklinks  `[ ]`

One `Super+Alt+Space` fuzzy surface over apps, files, open windows, emoji, a calculator, the
clipboard, and user-defined commands. The single strongest gap: this config has separate launchers
(`serviceLauncher`, `reconLauncher`, homelab glance) but no unified `>`-prefixed palette. The
**Quicklinks** layer is the multiplier: one entry type targeting a URL, file, app deeplink, or
parameterized search, with `{argument}`, `{clipboard}`, date, and calc-result placeholders
substituted at run time (e.g. `gitea repo {argument}`, `recon target {clipboard}`).

- **Module**: `modules/ii/commandPalette/` + `services/CommandPalette.qml`. A search-filtered
  `ListView` with a pluggable provider list, each provider a `Process`/`StdioCollector`. Reuse the
  existing overview/launcher fuzzy list rather than reimplementing.
- **Providers**: apps (desktop entries), files (`fd`), windows (`hyprctl clients -j`), calc
  (`qalc`, already present), clipboard (feature 2), quicklinks (user config).
- **Interim**: shell out to `fuzzel`/`walker`/`rofi` 2.0 to get the workflow before the native core
  lands, then swap the backend.
- **Deps**: `fd`, `libqalculate` (qalc). `wl-clipboard` shared with feature 2.
- **Prior art**: DankMaterialShell (Quickshell, ships exactly this), PowerToys Command Palette,
  Raycast Quicklinks + dynamic placeholders.
- **Effort**: medium-high core, then each provider is incremental.

## 2. Clipboard history + snippets  `[ ]`

Scrollable clipboard history with text and image-thumbnail previews, plus pinned snippets. Front-end
over `cliphist`, which is picker-agnostic by design
(`cliphist list | <picker> | cliphist decode | wl-copy`), so the Quickshell UI replaces the picker.

- **Module**: `modules/ii/clipboard/` + `services/Clipboard.qml`. A `wl-paste --watch cliphist store`
  service feeds the history; the module shells `cliphist list`/`decode` and renders entries. Pinned
  snippets live in `config.json`.
- **Stretch**: transform-on-paste (plain text / Markdown / JSON), the PowerToys "Advanced Paste"
  pattern.
- **Deps**: `cliphist`, `wl-clipboard`.
- **Prior art**: sentriz/cliphist, DankMaterialShell clipboard (image previews in Quickshell),
  PowerToys Advanced Paste.
- **Effort**: medium.

## 3. PR/issue quick-action board  `[ ]`

A `gh-dash`-style board: per-repo PR/issue sections from `config.json`, with key-bound actions
(diff, comment, checkout, open, approve). Complements `giteaActivity`, which surfaces activity but
does not act.

- **Module**: `modules/ii/prBoard/` + `services/PrBoard.qml`. `Process` runs `gh pr list --json ...`
  per configured GitHub repo and `tea` (or the Gitea API) for Gitea; render a list, bind keys to the
  CLI subcommands.
- **Deps**: `gh` (present), `tea` (Gitea CLI), `jq`.
- **Prior art**: dlvhdr/gh-dash (per-repo YAML sections, custom workflow actions).
- **Effort**: medium.

## 4. Eye-care break overlay  `[ ]`

Tiered break reminders: a 20s micro-break every ~10 min and a longer 5 min break every ~30 min, or
the 20-20-20 full-screen countdown. Lowest-effort item and a good warm-up.

- **Module**: `services/BreakReminder.qml` + a layer-shell overlay window. A `Timer` drives the
  schedule; the overlay shows a countdown. Suppress during `gameMode`/fullscreen and reuse the
  `idleInhibitor` signal so it never fires mid-presentation. `Super+Alt+B` snoozes.
- **Deps**: none (native Timer + layer-shell).
- **Prior art**: hovancik/stretchly (tiered schedule), nomandhoni-cs/blink-eye (20-20-20 overlay).
- **Effort**: low.

## 5. Secrets surfacing (pass/command)  `[-]`  — dropped (built, then removed as redundant)

Built and shipped 2026-06-30, then removed at the owner's call: a desktop secrets picker
overlaps existing tooling (gnome-keyring / browser password managers / `sops`+`pass` on the CLI)
and didn't earn its surface area. Kept here only so it isn't re-proposed. Reference implementation
lives in git history (commit `6ce0731`, reverted) if it's ever wanted back.

## 6. Bar popups + inline graphs  `[ ]`

Generalize `sensorSparkline` into a reusable pattern: bar items that show a glanceable value and
expand into a small popup with a live graph (network throughput, NAS I/O, HA quick scenes). The
Sketchybar model, where any element changes from a script event.

- **Module**: a shared `BarPopup` + `Sparkline` component (`Canvas`/`ShapePath`) fed by a
  `Process` data model; add popup expansions on existing bar delegates.
- **Deps**: none extra.
- **Prior art**: FelixKratz/SketchyBar (event-driven elements, arbitrary graphs, on-demand popups).
- **Effort**: low-medium per widget.

## 7. Recon MCP backend for reconLauncher  `[ ]`  (optional)

Enhance the existing owner-allowlisted `reconLauncher` to query an authorization-gated MCP server
(`cybersec-toolkit`: 580+ tool registry, `check_installed`, `suggest_for_ctf`, gated
`run_tool`/`run_pipeline` with allowlist + sanitization + rate limits).

- **Caveat**: it speaks JSON-RPC over stdio, not a plain CLI, so wrap/invoke the server rather than
  shelling out. Open question whether this beats calling the underlying tools directly, given the
  launcher already exists. Evaluate before committing.
- **Deps**: the MCP server (python/uv), kept behind the existing allowlist gate.
- **Prior art**: 26zl/cybersec-toolkit.
- **Effort**: medium.

---

## Notes

- **Quickshell version**: this config is pinned to a 0.2.1-era rev. Quickshell is pre-1.0, so verify
  `Process`/`StdioCollector` signal names and `Services.*` type APIs against the installed build
  before coding (the survey cited v0.2.1/v0.3.0 docs).
- **Substrate**: every item above is `Process`/`StdioCollector` plus, where useful, native DBus
  service bindings (MPRIS, StatusNotifier, Notifications, UPower, PipeWire, PAM). No external glue.
- **Refuted lead**: claims that the sh1zicus `ii` fork ships a Timer Manager and native
  ChatGPT/Gemini sidebar did not survive verification. Not prior art for those.

## Sources

- Quickshell docs — https://quickshell.org/docs/guide/introduction/
- DankMaterialShell (Quickshell launcher + clipboard) — https://github.com/AvengeMedia/DankMaterialShell
- PowerToys (Command Palette, Run, Advanced Paste) — https://github.com/microsoft/PowerToys
- Raycast Quicklinks + placeholders — https://manual.raycast.com/quicklinks
- Hyprland launchers — https://wiki.hypr.land/Useful-Utilities/App-Launchers/
- cliphist — https://github.com/sentriz/cliphist
- gh-dash — https://github.com/dlvhdr/gh-dash
- Stretchly — https://github.com/hovancik/stretchly
- Blink Eye — https://github.com/nomandhoni-cs/blink-eye
- SketchyBar — https://github.com/FelixKratz/SketchyBar
- cybersec-toolkit — https://github.com/26zl/cybersec-toolkit
