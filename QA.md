# Verification & QA

How every feature gets verified before it ships. Layered, fast → thorough; **the running shell is
the source of truth** and rigor scales to risk (a service that shells out and parses CLI output gets
the full treatment; a static widget gets the fast path). Built from a research pass on QML/Quickshell/
Wayland test tooling (June 2026); see the tool table at the bottom.

## The per-feature QA loop

Apply top-to-bottom. Stop early for trivial widgets; run all of it for anything that parses output,
shells out, handles IPC, or touches untrusted input.

### 0. While developing — hot-reload
Edit in a worktree (`~/dev/dotfiles-dev`), watch the live instance:
```sh
qs -c ii log -f        # follow; or: qs -c ii log | tail
```
⚠ **The running instance's log keeps STALE lines.** After a fix, don't trust the live buffer — confirm
with a fresh isolated parse (step 2). This burned us once (the AndroidQuickToggleButton/HA spam).

### 1. Static gate — `just lint` (now authoritative)
`just lint` feeds qmllint the session `$QML_IMPORT_PATH` (`-I …`) so QtQuick/Quickshell types resolve
(false positives drop ~16→2 per file) and filters the categories that stay structurally unresolvable
on NixOS (the `qs.*` config imports + project singletons). What survives is real — it catches a typo'd
property (`heigth`) that the old noisy lint buried. Also grep the injection antipattern:
```sh
grep -rnE '"bash".*"-c".*\+' --include='*.qml' .   # value concatenated into a shell string = injection
```

### 2. Load gate — full-shell parse (authoritative "did it load")
There is no parse-only flag and QML errors do NOT exit the process, so the gate is: load the whole
shell in an isolated instance and assert it reaches "Configuration Loaded" with no errors in your files.
```sh
qs -p ~/dev/dotfiles-dev/quickshell/ii > /tmp/parse.log 2>&1 &   # then grep, then kill
grep -iE 'Configuration Loaded' /tmp/parse.log          # must appear
grep -iE '<YourFile>|error|is not a type|cannot assign' /tmp/parse.log   # must be empty
```
Ignore the polkit / UPower / AiChat / KeyringStorage warnings — duplicate-instance artifacts.

### 3. Service logic — deterministic parse tests (the bug-catcher)
For anything parsing `nmcli`/`pactl`/`playerctl`/leases output: **test the parse against canned output**,
not live hardware. Two ways:
- **Fake-bin PATH shim** — drop a fake `nmcli` printing a known line into a temp dir on `$PATH`, run the
  service, assert. (Quickshell `Process` calls `execve` and inherits `$PATH`, so this intercepts even
  `bash -c "nmcli …"`.)
- **Pure-function unit test** — split the parse into a plain JS function and run it under
  `qmltestrunner -platform offscreen` (or even `node`/`python` for a quick check).

This is the layer that catches the substring-class bugs (`includes("activated")` matching
`"deactivated"`; `includes("connected")` matching `"disconnected"`). When a feature depends on a tool's
exact output, **run the tool and look** — don't assume (the `:activated` severity was over-rated because
an agent assumed the nmcli output).

### 4. IPC liveness — `qs ipc`
```sh
qs ipc --pid $(pgrep -f 'quickshell -c ii') call <target> status   # service alive + sane state
qs ipc show                                                        # list all IpcHandler targets
```
Every service should expose a `status()` IpcHandler returning its key state.

### 5. Interactive + visual (UI features)
```sh
just test-ui <feature>                 # ydotool drives the keybind, grim screenshots, Read the PNG
```
Assert the layer surface actually exists with the right geometry (Hyprland IPC):
```sh
hyprctl -j layers   | jq '.. | objects | select(.namespace? | startswith("quickshell:"))'
hyprctl -j monitors | jq '.[] | select(.focused) | .reserved'   # bar exclusive zone
```
Optional **visual regression**: `grim -g "<geom>" actual.png` then `odiff golden.png actual.png diff.png
--aa --threshold 0.05 --fail-on-layout` (the `--aa` skips antialiased font noise).

### 6. Adversarial review (before ship)
Run the multi-agent review on the diff (Sonnet, cost-controlled):
the `qa-session-review` workflow — finders per dimension (bugs/vulns/races/redundancy) → each finding
adversarially verified. It found the real hotspot bugs this layer is meant to catch.

### 7. Security
- Injection: the grep in step 1; **always pass tainted values via the Process `environment` map**, never
  interpolate into `bash -c`.
- `shellcheck` on any helper `.sh`.
- `gitleaks detect --no-banner` for secrets (stronger than a hand grep); keep committed files
  publication-safe (no hostnames/IPs/tokens — `example.com` placeholders).
- Any externally-controlled string in a `StyledText` → `textFormat: Text.PlainText` (StyledText defaults
  to AutoText = HTML; a DHCP hostname could inject markup).

## Tooling

Already in the loop: `qmllint` (now `-I`-fed), `qs -p` / `qs ipc` / `qs log`, `just test` (IPC selftest),
`just test-ui` (ydotool + grim), `hyprctl -j layers/monitors`, `dbus-monitor`.

Worth adding (NixOS `home.packages` / a devShell):

| Tool | Nix attr | Use |
|---|---|---|
| qmltestrunner, qmlformat, qmlls, qmlprofiler | `kdePackages.qtdeclarative` | unit-test pure QML logic offscreen; format; editor LSP; perf |
| **GammaRay** | `gammaray` | attach to the running shell, inspect the live QML object tree / bindings / signals — best bug-hunting tool |
| **shellcheck** | `shellcheck` | lint the helper `.sh` scripts (none today) |
| **gitleaks** | `gitleaks` | secret scanning, pre-commit + CI |
| **odiff** | `odiff` (npm `odiff-bin` if not yet in channel) | visual-regression diffing, AA-tolerant |
| statix, deadnix | `statix`, `deadnix` | lint the NixOS flake (separate repo) |

Input-injection note: `ydotool` (uinput, what we use) is compositor-agnostic and reliable; `wtype` is a
zero-privilege wlroots alternative; `wlrctl` adds mouse + window-focus targeting for wlroots — handy if a
test needs to focus a specific window before typing.

## Headless CI (future)
Fully-automated UI tests can run in a NixOS VM with Hyprland headless: `HYPRLAND_HEADLESS_ONLY=1`, QEMU
`-vga none -device virtio-gpu-pci` (LLVMpipe software GL), then `hyprctl output create headless`, drive
with ydotool, capture with grim, assert with `hyprctl -j` + odiff. Hyprland's own `nix/tests` is the
reference recipe. Involved — current practice is the local loop above; this is the upgrade path.

## Lessons baked in (hotspot QA cycle, 2026-06-30)
- Verify a CLI's real output empirically before parsing it.
- Field-exact parsing, never substring `includes()` on status strings.
- Tainted values via `environment`, never shell-string interpolation.
- `Text.PlainText` for any externally-controlled string.
- The live log lies (stale lines) — confirm fixes with a fresh `qs -p`.
