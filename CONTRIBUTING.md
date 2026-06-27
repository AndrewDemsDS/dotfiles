# Contributing

The working copy of this repo **is `~/.config`**, so `~/.config/quickshell/ii` is the live shell. It
hot-reloads on every file change, and a QML syntax error there blanks the bar. So there's one rule:
don't edit the live tree directly. Develop in isolation, then deploy on purpose.

## The loop

1. **Branch in a worktree** so the live config stays untouched until you merge:

   ```sh
   git -C ~/.config worktree add -b feat/my-thing ~/dev/dotfiles-dev origin/main
   ```

2. **Lint** the changed QML:

   ```sh
   just lint
   ```

   `qmllint` is the gate. One quirk: some large valid files exit non-zero with no output, which is a
   qmllint bug rather than a real failure. So the gate and the pre-commit hook key on diagnostic text,
   not the exit code. A real syntax error prints diagnostics.

3. **Parse the whole shell** to catch cross-file problems that a single-file lint misses:

   ```sh
   qs -p ~/dev/dotfiles-dev/quickshell/ii
   ```

   Ignore the polkit, UPower, and AiChat warnings. They come from running a second instance.

4. **Deploy** by merging into the live tree. The shell reloads itself:

   ```sh
   git -C ~/.config merge --ff-only feat/my-thing
   ```

   `just rollback` puts the live config back one commit if something looks wrong.

5. **Verify** with the test harness below, or by watching the actual widget.

## Testing

There's no QML test framework here. The harness is a stack of ordinary tools.

| Command | What it does |
|---------|--------------|
| `just test` | Functional smoke test. Asks every service over IPC for its status and asserts. |
| `just test-ui [feature]` | Interactive check. Drives a keybind with `ydotool`, screenshots with `grim`. |
| `just harness` | Loads a single widget in an isolated instance. |

Services expose an `IpcHandler`, so `qs ipc --pid <pid> call <target> status` is the quickest way to
confirm one is alive. `ydotool` simulates input and `grim` captures the result, which exercises the
interactive features without anyone at the keyboard.

## Conventions

A feature is one self-contained thing you can switch on or off. To count as done it needs all of:

1. **A config block** in `quickshell/ii/modules/common/Config.qml`:
   `property JsonObject myFeature: JsonObject { property bool enable: true; … }`, defaults as literals.
2. **Gating**: the service `Timer` runs on `Config.ready && Config.options.myFeature.enable`, and the
   widget, pill, or keybind honours the same flag, so disabling it stops the feature for good.
3. **A settings entry**: a `ContentSection` on the **Custom** page
   (`quickshell/ii/modules/settings/CustomConfig.qml`), enable switch first.
4. **Dependencies recorded**: anything that shells out to a system tool adds its package to
   [`setup/dependencies.txt`](setup/dependencies.txt), with pip deps as a comment. `just deps` installs them.

A few more patterns:

- **Services** are `pragma Singleton` plus a `Timer` on `Config.ready` plus a `Process`/`StdioCollector`
  or an `XMLHttpRequest`. Model them on `services/NasHealth.qml` for a command, `services/VpnStatus.qml`
  for HTTP.
- **Dialogs** are real `FloatingWindow`s, which gives you `Super+Q`, drag, and resize for free. Add a
  hypr `window_rule` (float, center, size, matched by title) in `hypr/hyprland/rules.lua`, and have the
  open keybind call the service's `toggle`. Model: `modules/ii/reconLauncher/ReconLauncherDialog.qml`.
- **Theming** goes through `Appearance.*`. Reuse `MaterialSymbol`, `StyledText`, `RippleButton`.
- **Keep it publication-safe.** No hostnames, IPs, emails, tokens, or entity IDs in committed files.
  Personal values belong in the untracked `config.json`, secrets in `quickshell/secrets/`.

## Before you open a PR

- `just lint` is clean and the full-shell parse loads without errors.
- No personal data in the diff. Grep your changes for IPs, hostnames, and tokens.
- A new feature has its enable flag, gating, and a **Settings → Custom** entry.
- New system tools are in `setup/dependencies.txt`.
- CI is green (qmllint, shellcheck, Lua, secret scan).
