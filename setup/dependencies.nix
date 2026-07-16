# Nix mirror of dependencies.txt — extra system tools the CUSTOM features shell out to.
# Consumed by flake.nix (devShell). Keep in sync with dependencies.txt.
{
  # core feature deps (printer integration, test harness, clipboard, JSON)
  # dnsmasq: NM's ipv4.method=shared spawns it for the hotspot's DHCP/DNS; qrencode: hotspot join QR.
  core = [ "cups" "system-config-printer" "ydotool" "grim" "slurp" "wl-clipboard" "jq" "dnsmasq" "qrencode" ];

  # optional: security / recon launcher (Super+Alt+P)
  optional = [ "nuclei" "whatweb" "ffuf" "nmap" ];
}
