set shell := ["bash", "-uc"]

# Default: list targets
default:
    @just --list

# qmllint every Quickshell QML changed on this branch (+ uncommitted/untracked).
# Authoritative mode: feed qmllint the session's $QML_IMPORT_PATH (-I) so QtQuick/Quickshell
# types resolve (cuts the false-positive flood ~16->2 per file), then filter the categories that
# stay structurally unresolvable on NixOS — the `qs.*` config-relative imports and the project's
# own singletons (Translation/Config/Appearance/...), plus the Process.exited signal-param noise.
# What survives the filter is real signal (e.g. a typo'd property). See QA.md.
lint:
    @changed=$( { git diff --name-only main...HEAD -- 'quickshell/**/*.qml'; \
                  git ls-files -m -o --exclude-standard -- 'quickshell/**/*.qml'; } \
                | sort -u | grep . || true ); \
    [ -z "$changed" ] && { echo "no changed QML to lint"; exit 0; }; \
    iflags=""; for p in $(echo "${QML_IMPORT_PATH:-}" | tr ':' ' '); do [ -n "$p" ] && iflags="$iflags -I $p"; done; \
    [ -z "$iflags" ] && echo "⚠ QML_IMPORT_PATH unset — lint runs in noisy mode (run from the graphical session, or export it in CI)"; \
    filt='\[import\]|\[unqualified\]|\[signal-handler-parameters\]|Warnings occurred while importing|not found on type "(Translation|Config|Appearance|GlobalStates|Directories|FileUtils|ColorUtils|MaterialThemeLoader)"'; \
    fail=0; for f in $changed; do [ -f "$f" ] || continue; \
      out="$(qmllint $iflags "$f" 2>&1 | grep -iE 'warning:|error:' | grep -vE "$filt" || true)"; \
      if [ -n "${out//[[:space:]]/}" ]; then echo "✗ $f"; echo "$out" | sed 's/^/    /'; fail=1; \
      else echo "✓ $f"; fi; done; \
    exit $fail

# Run the isolated dev preview (loads quickshell/ii/Harness.qml only, separate instance)
harness:
    qs -p {{justfile_directory()}}/quickshell/ii/Harness.qml

# Install the extra system packages the custom features need (setup/dependencies.txt).
# `just deps` = core; `just deps --optional` also installs the security/recon tools.
deps *FLAGS:
    @bash {{justfile_directory()}}/setup/install-deps.sh {{FLAGS}}

# Deploy merged changes into the LIVE ~/.config; quickshell hot-reloads on file change
deploy:
    git -C "$HOME/.config" pull --ff-only
    @echo "deployed → live shell hot-reloads automatically"

# Roll the LIVE config back to the previous commit (instant recovery)
rollback:
    git -C "$HOME/.config" reset --hard 'HEAD@{1}'
    @echo "rolled back → live shell hot-reloads automatically"

# Smoke-test the live shell: IPC functional checks for every service (non-intrusive)
test:
    @bash {{justfile_directory()}}/quickshell/ii/scripts/dev/selftest.sh

# Per-feature visual/interactive check (INTRUSIVE: drives input + screenshots).
# Usage: just test-ui [llm|news|enterprise|ha-dashboard|bar|all]
test-ui feature="all":
    @bash {{justfile_directory()}}/quickshell/ii/scripts/dev/testui.sh {{feature}}
