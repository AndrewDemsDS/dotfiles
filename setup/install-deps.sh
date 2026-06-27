#!/usr/bin/env bash
# Install the extra system packages this config's custom features need
# (see setup/dependencies.txt). Idempotent: skips already-installed packages.
# Arch only — uses an AUR helper (paru/yay) if present, else pacman for repo pkgs.
#   just deps            # core deps
#   just deps --optional # core + the optional security/recon tools
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIST="$HERE/dependencies.txt"
[ -f "$LIST" ] || { echo "no dependencies.txt next to this script"; exit 1; }

WANT_OPTIONAL=0
[ "${1:-}" = "--optional" ] && WANT_OPTIONAL=1

# AUR helper (for nuclei etc.); fall back to pacman for repo packages.
HELPER=""
for h in paru yay; do command -v "$h" >/dev/null 2>&1 && { HELPER="$h"; break; }; done

# Collect wanted packages, honoring the "optional" section boundary.
pkgs=()
optional=0
while IFS= read -r line; do
  case "$line" in
    *"optional: security"*) optional=1; continue ;;
    *"pip,"*) break ;;            # stop at the pip section (venv-managed, not system)
  esac
  # strip trailing inline comment + whitespace
  pkg="${line%%#*}"; pkg="$(echo -n "$pkg" | tr -d '[:space:]')"
  [ -z "$pkg" ] && continue
  [ "$optional" = 1 ] && [ "$WANT_OPTIONAL" = 0 ] && continue
  pkgs+=("$pkg")
done < "$LIST"

# Which are missing?
missing=()
for p in "${pkgs[@]}"; do
  pacman -Qq "$p" >/dev/null 2>&1 || missing+=("$p")
done

if [ "${#missing[@]}" -eq 0 ]; then
  echo "✓ all ${#pkgs[@]} packages already installed"
else
  echo "Installing ${#missing[@]} missing: ${missing[*]}"
  if [ -n "$HELPER" ]; then
    "$HELPER" -S --needed "${missing[@]}"
  else
    echo "  (no AUR helper found — using pacman; AUR-only pkgs like nuclei may fail)"
    sudo pacman -S --needed "${missing[@]}"
  fi
fi

# Enable CUPS so printing works.
if pacman -Qq cups >/dev/null 2>&1 && ! systemctl is-active --quiet cups; then
  echo "Enabling cups.service…"
  sudo systemctl enable --now cups
fi

echo
echo "Note: pip deps (trafilatura) live in their own venv — see the commented block in dependencies.txt."
