#!/usr/bin/env bash
# Functional smoke-test of the LIVE Quickshell shell via IPC.
# Asserts each service responds sanely. Run with `just test`.
# Soft (⚠) checks are for features that need external deps (Ollama, an enterprise
# network) and don't fail the run.
set -uo pipefail

PID="$(pgrep -x qs | head -1)"
[ -z "$PID" ] && { echo "No running 'qs' shell found."; exit 1; }

pass=0; fail=0; warn=0
G=$'\033[32m'; R=$'\033[31m'; Y=$'\033[33m'; N=$'\033[0m'
ipc() { qs ipc --pid "$PID" call "$@" 2>/dev/null; }

ck() { # name  regex  ipc-args...
  local name="$1" re="$2"; shift 2
  local out; out="$(ipc "$@")"
  if echo "$out" | grep -qE "$re"; then echo "  ${G}✓${N} $name"; pass=$((pass+1))
  else echo "  ${R}✗${N} $name — ${out:-<no response>}"; fail=$((fail+1)); fi
}
wk() { # soft: warn instead of fail
  local name="$1" re="$2"; shift 2
  local out; out="$(ipc "$@")"
  if echo "$out" | grep -qE "$re"; then echo "  ${G}✓${N} $name"; pass=$((pass+1))
  else echo "  ${Y}⚠${N} $name — ${out:-<needs external dep>}"; warn=$((warn+1)); fi
}

SHOW="$(qs ipc --pid "$PID" show 2>/dev/null)"
tgt() { # assert an IPC target is registered (for services without a status())
  if echo "$SHOW" | grep -qE "target $1( |\$)"; then echo "  ${G}✓${N} IPC target: $1"; pass=$((pass+1))
  else echo "  ${R}✗${N} IPC target: $1 missing"; fail=$((fail+1)); fi
}

echo "Quickshell self-test — pid $PID"
echo "— services —"
ck "Home Assistant online"  'online=true'      homeAssistant status
ck "UPS reading valid"      'valid=true'        ups status
ck "NAS reachable"          'reachable=true'    nas status
ck "News has items"         'items=[1-9]'       news status
ck "VPN status present"     'ssid='             vpnStatus status
ck "Dotfiles drift"         '(clean|changed)'   dotfilesDrift status
ck "Net usage pill"         'iface='            netUsage status
ck "Service health board"   'up=[0-9]'          serviceHealth status
ck "Sensor sparkline"       'sensors=[0-9]'     sensorSparkline status
ck "Deadlines"              'enabled='          deadlines status
ck "Printer (CUPS)"         'default='          printer status
echo "— IPC surface —"
tgt serviceLauncher
tgt homelabGlance
tgt reconLauncher
tgt printer
# timetable/giteaActivity are lazy singletons: their IPC target only registers when the
# feature is enabled+configured (a schedule / a token). Soft-check so the run reflects reality.
wk "Timetable (configured)" '.'  timetable status
wk "Gitea (configured)"     '.'  giteaActivity status
tgt localLlm
tgt wifiEnterprise
tgt homeAssistant
tgt sidebarRight
tgt sidebarLeft
echo "— soft (external deps) —"
if curl -sk -m3 http://localhost:11434/api/tags >/dev/null 2>&1; then
  echo "  ${G}✓${N} Ollama reachable (LLM overlay usable)"; pass=$((pass+1))
else
  echo "  ${Y}⚠${N} Ollama not running — #10 overlay opens but can't run actions"; warn=$((warn+1))
fi

echo
echo "${pass} passed, ${warn} warnings, ${fail} failed"
[ "$fail" -eq 0 ]
