#!/usr/bin/env bash
# Per-feature interactive/visual test: trigger → assert → screenshot → cleanup.
# INTRUSIVE (drives input, opens UI). Usage: just test-ui <feature>
#   features: llm | news | enterprise | ha-dashboard | bar | all
set -uo pipefail

PID="$(pgrep -x qs | head -1)"; [ -z "$PID" ] && { echo "No running 'qs' shell."; exit 1; }
export YDOTOOL_SOCKET="${YDOTOOL_SOCKET:-$XDG_RUNTIME_DIR/.ydotool_socket}"
G=$'\033[32m'; R=$'\033[31m'; N=$'\033[0m'
ipc(){ qs ipc --pid "$PID" call "$@" 2>/dev/null; }
ok(){ echo "  ${G}✓${N} $1"; }; bad(){ echo "  ${R}✗${N} $1"; FAILED=1; }
layer(){ hyprctl layers -j 2>/dev/null | grep -c "$1" || true; }
client(){ hyprctl clients -j 2>/dev/null | grep -c "$1" || true; }
reset_state(){ # close any open overlays/sidebars so tests don't interfere
  ipc localLlm close >/dev/null 2>&1
  ipc news close >/dev/null 2>&1
  ipc wifiEnterprise open "" >/dev/null 2>&1
  ipc sidebarLeft close >/dev/null 2>&1
  ipc sidebarRight close >/dev/null 2>&1
  sleep 0.4
}
shot(){ # name → /tmp/qs-ui-<name>.png (focused monitor)
  local geo; geo="$(hyprctl monitors -j | python3 -c "import json,sys;m=json.load(sys.stdin)[0];print('%d,%d %dx%d'%(m['x'],m['y'],m['width'],m['height']))")"
  grim -g "$geo" "/tmp/qs-ui-$1.png" 2>/dev/null && echo "    shot → /tmp/qs-ui-$1.png"
}

t_llm(){ reset_state;
  echo "[llm] AI text-actions overlay (Super+Alt+I)"
  ydotool key 125:1 56:1 23:1 23:0 56:0 125:0; sleep 1.2          # Super+Alt+I
  [ "$(layer textActions)" -ge 1 ] && ok "overlay opened" || bad "overlay did not open"
  shot llm; ipc localLlm close >/dev/null 2>&1; sleep 0.3
}
t_news(){ reset_state;
  echo "[news] article reader floating window"
  ipc news open "https://blog.rust-lang.org/2024/09/05/Rust-1.81.0.html" >/dev/null 2>&1; sleep 5
  [ "$(client 'Article Reader')" -ge 1 ] && ok "reader window opened" || bad "no reader window"
  shot news; ipc news close >/dev/null 2>&1; sleep 0.3
}
t_enterprise(){ reset_state;
  echo "[enterprise] WPA3-Enterprise 802.1X form"
  ipc wifiEnterprise open eduroam >/dev/null 2>&1; sleep 2
  [ "$(layer enterpriseWifi)" -ge 1 ] && ok "form opened" || bad "form did not open"
  shot enterprise; ipc wifiEnterprise open "" >/dev/null 2>&1; sleep 0.3
}
t_ha_dashboard(){ reset_state;
  echo "[ha-dashboard] HA Lovelace app window (Super+Alt+H)"
  ydotool key 125:1 56:1 35:1 35:0 56:0 125:0; sleep 5            # Super+Alt+H
  [ "$(client 'dashboard-overview')" -ge 1 ] && ok "dashboard window opened" || bad "no dashboard window"
  shot ha-dashboard
  hyprctl clients -j | python3 -c 'import json,sys; [print(c["address"]) for c in json.load(sys.stdin) if "dashboard-overview" in (c.get("class") or "")]' \
    | while read -r a; do hyprctl dispatch closewindow "address:$a" >/dev/null 2>&1; done
}
t_bar(){ reset_state;
  echo "[bar] indicators (visual — inspect for VPN / UPS pills)"
  shot bar; ok "bar screenshot taken"
}

FAILED=0
case "${1:-all}" in
  llm) t_llm;; news) t_news;; enterprise) t_enterprise;; ha-dashboard) t_ha_dashboard;; bar) t_bar;;
  all) t_llm; t_news; t_enterprise; t_bar;;   # ha-dashboard excluded (launches a browser)
  *) echo "usage: just test-ui <llm|news|enterprise|ha-dashboard|bar|all>"; exit 1;;
esac
echo
[ "$FAILED" -eq 0 ] && echo "${G}test-ui ok${N}" || { echo "${R}test-ui had failures${N}"; exit 1; }
