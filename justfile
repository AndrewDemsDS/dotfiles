set shell := ["bash", "-uc"]

# Default: list targets
default:
    @just --list

# qmllint every Quickshell QML changed on this branch (+ uncommitted/untracked)
lint:
    @changed=$( { git diff --name-only main...HEAD -- 'quickshell/**/*.qml'; \
                  git ls-files -m -o --exclude-standard -- 'quickshell/**/*.qml'; } \
                | sort -u | grep . || true ); \
    [ -z "$changed" ] && { echo "no changed QML to lint"; exit 0; }; \
    fail=0; for f in $changed; do [ -f "$f" ] || continue; \
      out="$(qmllint "$f" 2>&1 || true)"; \
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
