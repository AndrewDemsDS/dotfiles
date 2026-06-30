# Roadmap

Backlog for the widget layer this fork adds on top of
[illogical-impulse](https://github.com/end-4/dots-hyprland). Two streams feed it: **improving the
modules that already exist**, and a set of features **mined from end-4's open issue tracker** (431
open issues, agent-triaged) that the shell doesn't cover yet. Net-new ideas that duplicate existing
capability were dropped (see bottom).

Conventions for any work here: the "done" checklist in [CONTRIBUTING.md](CONTRIBUTING.md) — an
enable flag in `Config.qml`, gating on `Config.ready && enable`, a **Settings → Custom** entry, and
any shelled-out tool recorded in `setup/dependencies.txt` (and the NixOS `home.packages`). Build in
a worktree, parse-gate with `qs -p`, deploy by ff-merge.

Status legend: `[ ]` queued, `[~]` in progress, `[x]` shipped, `[-]` dropped.
Each entry cites its upstream issue (`e4#NNNN` = end-4/dots-hyprland).

---

## Phase 1 — Quick wins (low effort, self-contained warm-ups)

### 1. Hyprshade / screen-shader quick toggle  `[ ]`  (e4#3252) — UNBLOCKED (use `hyprctl eval`)
Screen-shader toggle (blue-light / CRT / vignette). Earlier marked blocked because `hyprshade 4.x`
uses `hyprctl keyword`, which Hyprland 0.55's Lua parser rejects. **Resolved:** the Lua-parser
replacement is `hyprctl eval`, so build the toggle around it directly — **no `hyprshade` binary needed**:
- apply: `hyprctl eval "hl.config({ decoration = { screen_shader = '<path>' } })"`
- clear: same with `screen_shader = '[[EMPTY]]'`
- read:  `hyprctl -j getoption decoration.screen_shader` (dot syntax)
- **Where**: `services/Shader.qml` + toggle in 3 styles; ship a shader or two in `hypr/shaders/`.
- **Config**: `shader.{enable, defaultShader, shaderDir}`. **Deps**: none (hyprctl present). Verify the
  GLSL applies on Hyprland 0.55 first (`getoption` shows the path), per QA.md.
⚠ General rule for this system: any runtime Hyprland option change must use `hyprctl eval
'hl.config({...})'`, NOT `hyprctl keyword` (disabled under the Lua parser). Audit other features.

### 2. Translator history + swap  `[ ]`  (e4#2759) — easy · improves existing
Recent source/target language pairs remembered and pinned to the top; a swap button + hotkey.
- **Where**: extend `services/ScreenTranslator.qml` (persist recent pairs) +
  `modules/ii/screenTranslator/ScreenTranslatorPanel.qml` (recent-pairs row + swap affordance).
- **How**: pure QML state — persist a JSON array of `[src,dst]` to `~/.local/state/quickshell/`
  (the `news_read.json` FileView pattern); swap = exchange two properties. No new deps.
- **Config**: `screenTranslator.recentPairs` (auto-managed). In-panel swap hotkey, no global keybind.

### 3. File results in overview search  `[ ]`  (e4#3104) — low-med · improves existing
Typing a path-ish query (prefix `/`, `~`, or `f:`) surfaces file results next to apps/math.
- **Where**: extend `services/LauncherSearch.qml` (or `AppSearch.qml`) + `modules/ii/overview/
  SearchBar.qml`/`SearchWidget.qml`/`SearchItem.qml`.
- **How**: on a path prefix, `Process` runs `fd --max-results 20 <query> ~` (fd present); render
  results in the same list with a file-type icon; open via `xdg-open`. Debounce input.
- **Config**: `overview.fileSearch.{enable, root, maxResults}`. Dep: `fd` (present).

---

## Phase 2 — Media cluster (shared `MprisController`)

### 4. Media seek bar + multi-player filtering  `[ ]`  (e4#847) — medium · improves existing
A draggable seek bar on the media control, and surface only the active/most-recent player when
several are running.
- **Where**: `services/MprisController.qml` (position polling + seek dispatch, active-player pick) +
  `modules/ii/mediaControls/MediaControls.qml` / `PlayerControl.qml`.
- **How**: read `Position`/`Length` (MPRIS or `playerctl position`/`metadata mpris:length`); seek via
  `SetPosition`/`playerctl position <s>`; poll ~1s only while playing + visible. Rank players by
  playback status + last-active. Dep: `playerctl` (present).
- **Config**: `mediaControls.{showSeekBar, singlePlayer}`.

### 5. MPRIS controls on the lock screen  `[ ]`  (e4#2042) — medium
Compact now-playing + play/pause/skip on the lock surface.
- **Where**: `modules/ii/lock/LockSurface.qml` — add a small media widget bound to `MprisController`.
- **How**: reuse the existing MPRIS service; controls call play/pause/next. **Security**: show only
  title/artist/art and transport — no notifications, no seek to arbitrary content; gate behind
  `lock.showMedia`. Render below the auth field, never stealing focus from it.
- **Config**: `lock.showMedia` (default true).

### 6. Fullscreen "now playing" + synced lyrics  `[ ]`  (e4#2045, e4#3109) — medium
A Spotify-style overlay: large art, controls, and time-synced lyrics.
- **Where**: new `modules/ii/nowPlaying/NowPlaying.qml` (FloatingWindow or layer overlay) registered
  in `IllogicalImpulseFamily`, + `services/Lyrics.qml`.
- **How**: data from `MprisController`; lyrics via an `XMLHttpRequest` to **lrclib.net**
  (`/api/get?artist=&track=&duration=`), matched to `Position` for the active line. Keybind to open.
- **Config**: `nowPlaying.{enable, lyrics}`. No binary dep (HTTP API). Keybind e.g. `Super+Alt+N`.

---

## Phase 3 — System & QoL

### 7. Audio output-port selector  `[ ]`  (e4#3332) — medium
Switch headphone ⇄ speaker (ports on one sink) from the volume popup.
- **Where**: extend `modules/ii/sidebarRight/volumeMixer/VolumeDialogContent.qml` /
  `AudioDeviceSelectorButton.qml` + `services/Audio.qml`.
- **How**: enumerate ports `pactl -f json list sinks` (ports[].name/availability); switch
  `pactl set-sink-port <sink> <port>`. Distinguish port-vs-sink cleanly. Dep: `pactl` (present).
- **Config**: none needed beyond the existing audio panel.

### 8. Bluetooth battery popup  `[ ]`  (e4#3060) — easy-med
Transient Material-You popup with device name + battery % on connect.
- **Where**: new `services/BluetoothBattery.qml` + a reuse of the OSD popup
  (`modules/ii/onScreenDisplay/`).
- **How**: watch `org.bluez` via Quickshell DBus (`Battery1.Percentage`, device Connected signal);
  3-5s auto-dismiss popup. No binary dep (native DBus).
- **Config**: `bluetoothBattery.enable`.

### 9. Auto dark/light by time  `[ ]`  (e4#1691) — easy-med
Flip the colour scheme at sunrise/sunset (or fixed times).
- **Where**: new `services/AutoTheme.qml` (Timer) calling the existing dark/light switch
  (`services/Wallpapers.qml` + `scripts/colors/applycolor.sh`, same path `DarkModeToggle` uses).
- **How**: compute sunrise/sunset from `Weather.qml` coords (or config lat/long), else fixed
  `lightAt`/`darkAt`; a Timer checks every few minutes and switches once per boundary. No new dep.
- **Config**: `autoTheme.{enable, mode: sun|fixed, lightAt, darkAt}`.

### 10. Workspace QoL  `[ ]`  (e4#2196, e4#2914) — easy
Special-workspace (scratchpad) indicator in the bar, and per-monitor workspace filtering.
- **Where**: `modules/ii/bar/` workspace widget.
- **How**: Hyprland IPC — `activespecial` event → badge; filter the workspace `Repeater` by
  `monitor === thisScreen` using `hyprctl monitors -j`. No new dep.
- **Config**: `bar.workspaces.{showSpecial, perMonitor}`.

### 11. Wallpaper rotation + change hook  `[ ]`  (e4#2477, e4#1936) — easy
Auto-cycle wallpapers from a folder; run a user script after each change.
- **Where**: extend `services/Wallpapers.qml`.
- **How**: Timer cycles a configured folder at an interval, calling the existing wallpaper-set path;
  after the color-generation step, `Process` runs `wallpaper.{hookScript}` (for OpenRGB / terminal
  sync). No new dep.
- **Config**: `wallpaper.{rotateFolder, rotateMinutes, hookScript}`.

---

## Phase 4 — Bigger / maker bets

### 12. Voice-to-text on a keybind  `[ ]`  (e4#2955) — medium
Hold-to-record → transcribe → inject into the focused field.
- **Where**: new `services/VoiceInput.qml` + a recording OSD indicator.
- **How**: keybind starts capture; `Process` pipes mic (PipeWire) to `whisper.cpp` (or `vosk`);
  result typed via `wtype`/`ydotool` (present). Recording indicator while active.
- **Config**: `voiceInput.{enable, model}`. Dep: `whisper-cpp` (add). Keybind e.g. `Super+Alt+V`.

### 13. Captive-portal launcher  `[ ]`  (e4#3257) — medium · fits your network/VPN work
Detect a captive portal and open the login page.
- **Where**: extend `services/VpnStatus.qml` (already does connectivity/trust) or new
  `services/CaptivePortal.qml`; a notification action.
- **How**: probe `http://nmcheck.gnome.org/` (or NM `CONNECTIVITY=portal`); on portal, notify +
  `xdg-open` the redirect URL. Ties into the existing trusted/untrusted-network logic.
- **Config**: `captivePortal.enable`. No new dep.

### 14. Floating AI overlay  `[ ]`  (e4#2966) — medium
Summon the AI assistant as a dismiss-on-blur floating window (not the sidebar).
- **Where**: new `modules/ii/aiOverlay/AiOverlay.qml` (FloatingWindow, the reconLauncher pattern) +
  reuse `services/Ai.qml`.
- **How**: keybind toggles a centered floating window over the current workspace; `GlobalFocusGrab`
  or onVisibleChanged dismiss; reuses the AI backend + the local-LLM text-action plumbing.
- **Config**: `aiOverlay.enable`. Keybind e.g. `Super+Alt+C`.

---

## Also queued (earlier, still valid)

- **Eye-care break overlay** `[ ]` — tiered breaks / 20-20-20 countdown; `Timer` + layer-shell window,
  suppressed during `gameMode`/fullscreen, reusing `idleInhibitor`. Easy. (stretchly, blink-eye)
- **giteaActivity → PR/issue quick actions** `[ ]` — key-bound diff/comment/checkout/open over
  `gh`/`tea`. Improves the existing read-only card. (gh-dash)

## New dependencies these introduce

Add to `setup/dependencies.txt` + NixOS `home.packages` when the owning feature is built:
- `hyprshade` (#1), `whisper-cpp` (#12). Already present: `fd`, `playerctl`, `pactl`, `ydotool`,
  `wtype`, `sensors`. HTTP-only (no binary): lrclib lyrics (#6).

## Dropped as redundant (already covered by the shell)

- **Command palette** → overview is already a search-launcher (+ serviceLauncher/reconLauncher/homelabGlance).
- **Clipboard history** → `cliphist` runs; pickers at Super+V and Super+Alt+V + `cliphistService`.
- **Bar popups + inline graphs** → `SensorSparkline` already renders inline graphs.
- **Recon MCP backend** → `reconLauncher` already covers it.
- **Secrets surfacing** → overlaps gnome-keyring / browser PW managers / CLI pass+sops (built then reverted `6ce0731`).
- **Pomodoro bar widget** (e4#3272) → already have a `pomodoro` module.
- Large rewrites skipped: Niri support (e4#1745), "windoes" flavor (e4#2342), modular bar / hefty-hype
  (e4#3072), GPU/resource monitoring (e4#1472 — end-4 is waiting on a Quickshell stats API).

## Sources

- end-4 issue tracker — https://github.com/end-4/dots-hyprland/issues
- gh-dash — https://github.com/dlvhdr/gh-dash · Stretchly — https://github.com/hovancik/stretchly · Blink Eye — https://github.com/nomandhoni-cs/blink-eye · lrclib — https://lrclib.net
