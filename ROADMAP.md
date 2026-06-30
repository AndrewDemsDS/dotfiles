# Roadmap

Improvement-first backlog for the widget layer this fork adds on top of
[illogical-impulse](https://github.com/end-4/dots-hyprland). Current focus: **improving the
modules that already exist**, not adding net-new surface. A net-new idea only stays here if the
shell genuinely doesn't already cover it. Most of the original prior-art research backlog turned
out to duplicate something already built and was dropped (see below).

Conventions for any work here: the "done" checklist in [CONTRIBUTING.md](CONTRIBUTING.md) — an
enable flag in `Config.qml`, gating on `Config.ready && enable`, a **Settings → Custom** entry, and
any shelled-out tool recorded in `setup/dependencies.txt`.

Status legend: `[ ]` queued, `[~]` in progress, `[x]` shipped, `[-]` dropped.

## Improving what we already have

The active focus. Pick targets per module; entries get filled in as we scope them.

- _(to be filled in — improvements to existing modules: homelab/HA, recon, hotspot, news, gitea,
  sensors, bar pills, settings UX)_

## Net-new ideas (parked — not redundant, but secondary)

### Eye-care break overlay  `[ ]`
Tiered breaks (20s micro every ~10 min, 5 min every ~30 min) or a 20-20-20 countdown overlay. A
`Timer` + a layer-shell window, suppressed during `gameMode`/fullscreen, reusing the
`idleInhibitor` signal. Genuinely new (nothing equivalent today), low effort.
- Deps: none. Prior art: hovancik/stretchly, nomandhoni-cs/blink-eye.

### PR/issue quick actions  `[ ]`
Add key-bound actions (diff, comment, checkout, open, approve) over `gh`/`tea`. Better framed as
**improving `giteaActivity`** (currently read-only) than a separate module.
- Deps: `gh` (present), `tea`, `jq`. Prior art: dlvhdr/gh-dash.

## Dropped as redundant (already covered by the shell)

From the prior-art research, but each duplicates capability the ii config already has:

- **Command palette / unified launcher** → the **overview** (Super) is already a search-launcher,
  alongside `serviceLauncher` (Super+Alt+L), `reconLauncher` (Super+Alt+P), and `homelabGlance`.
- **Clipboard history + snippets** → `cliphist` already runs (text + images); pickers at **Super+V**
  (overview clipboard) and **Super+Alt+V** (fuzzel), plus a `cliphistService` in-shell.
- **Bar popups + inline graphs** → `SensorSparkline` already renders inline graphs from a Process model.
- **Recon MCP backend** → `reconLauncher` already covers the workflow; the MCP wrapper was uncertain
  even in the research.
- **Secrets surfacing** → overlaps gnome-keyring, browser password managers, and CLI `pass`/`sops`.
  Built then removed (commit `6ce0731`, reverted).

## Sources (retained for the parked ideas)

- gh-dash — https://github.com/dlvhdr/gh-dash
- Stretchly — https://github.com/hovancik/stretchly
- Blink Eye — https://github.com/nomandhoni-cs/blink-eye
