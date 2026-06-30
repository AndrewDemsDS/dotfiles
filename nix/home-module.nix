# home-manager module: the ii/Quickshell/Hyprland desktop RUNTIME only.
# Provides packages + the iiPython venv activation + GTK dark-mode dconf seeding.
# It does NOT manage the dotfiles themselves (no home.file/xdg.configFile for hypr or
# quickshell) — those stay the live ~/.config git checkout so Quickshell hot-reload works.
{ config, lib, pkgs, ... }:
let
  # The interpreter that backs ii's python scripts. end-4 builds a mutable venv at
  # $ILLOGICAL_IMPULSE_VIRTUAL_ENV; here it's a Nix env + a --system-site-packages venv built from
  # it (see home.activation.iiVenv) so the venv-shebang scripts resolve these libs.
  iiPython = pkgs.python3.withPackages (ps: with ps; [
    pillow materialyoucolor trafilatura
    curl-cffi python-docx matplotlib openpyxl
    # end-4's venv also ships these (the *-venv.sh wrappers + venv-shebang .py expect them):
    #   scripts/images/*.py (find-regions / least-busy-region / text-color) -> opencv (cv2) + numpy
    #   scripts/thumbnails/thumbgen -> click, loguru, tqdm, pygobject3 (gi GnomeDesktop typelib via
    #     gnome-desktop + GI_TYPELIB_PATH in configuration.nix)
    opencv4 numpy click loguru tqdm pygobject3
  ]);
in
{
  # ---- illogical-impulse / ii Quickshell runtime (from docs/09 dep map) ----
  home.packages = with pkgs; [
    # Quickshell: plain nixpkgs build, now 0.3.0 (Polkit service + all services + Qt QML wrapping
    # are built in upstream — the 0.2.1-source override with -DCRASH_REPORTER=OFF + polkit-qt-1 is
    # no longer needed). The ii config is 0.3-ready (docs/13 Phase 1: all per-monitor Variants use
    # `required modelData`, shell.qml has `//@ pragma ShellId ii`).
    quickshell
    qt6.qtbase qt6.qtdeclarative qt6.qtsvg qt6.qt5compat qt6.qtimageformats
    qt6.qtmultimedia qt6.qtpositioning qt6.qtquicktimeline qt6.qtsensors
    qt6.qttools qt6.qttranslations qt6.qtvirtualkeyboard qt6.qtwayland
    kdePackages.kirigami kdePackages.kdialog kdePackages.syntax-highlighting
    kdePackages.qqc2-desktop-style
    # Hyprland ecosystem tools the dots call
    hypridle hyprlock hyprpicker hyprshot hyprsunset
    wl-clipboard cliphist
    # launcher / terminal / theming
    fuzzel kitty matugen wlogout
    # audio / backlight / media
    cava pavucontrol playerctl brightnessctl ddcutil
    # screen capture / OCR
    grim slurp swappy wf-recorder tesseract hyprpicker
    # input automation (dots' test loop + binds)
    wtype ydotool
    # misc utilities the ii scripts use
    imagemagick translate-shell libqalculate songrec
    bc ripgrep jq yq-go rsync wget curl fd bat fzf xdg-user-dirs
    # ii runtime deps that have no other provider on a minimal NixOS:
    #   libnotify -> notify-send  (23 execDetached call-sites across the shell)
    #   file      -> mime/type sniffing in several scripts
    libnotify file
    # Found by the on-hardware feature audit (dual-boot, real GPU) — the only 3 binaries
    # the running ii config referenced that were missing from PATH:
    #   glib      -> gsettings  (switchwall.sh: GTK light/dark + theme-follows-wallpaper)
    #   psmisc    -> killall    (ConflictKiller kills kded6/mako/dunst; keyring unlock.sh)
    #   pulseaudio-> pactl      (SongRec recognize-music.sh + record.sh with-sound; client
    #                            talks to pipewire-pulse, no daemon pulled in)
    glib psmisc pulseaudio
    # python3 for the ii scripts. The color/image scripts run via PLAIN `python3` (not the
    # $ILLOGICAL_IMPULSE_VIRTUAL_ENV venv), so bundle their imports into the interpreter:
    #   generate_colors_material.py -> PIL (pillow) + materialyoucolor
    #   scheme_for_image / image region scripts -> pillow
    #   scripts/news/read_article.py -> trafilatura (article text/image extraction; read-article.sh
    #     falls back to system python3 when no reader-venv exists, so bundle it here)
    #   plus user python libs explicit on Arch: curl-cffi, python-docx, matplotlib, openpyxl
    iiPython   # defined in the top-level `let` (also backs the $ILLOGICAL_IMPULSE_VIRTUAL_ENV venv)
    # KDE bits (polkit agent, file manager) + theming + shells
    # overskride = DE/WM-agnostic Bluetooth manager; it's what the ii "Details" button
    # launches (config.json apps.bluetooth). end-4 defaults to `kcmshell6 kcm_bluetooth`,
    # but kcmshell6 (kdePackages.kcmutils) isn't installed here and standalone KDE KCM
    # plugin-discovery is fragile outside Plasma — overskride is a self-contained binary.
    overskride
    kdePackages.bluedevil kdePackages.polkit-kde-agent-1 kdePackages.dolphin
    # plasma-integration provides the "kde" Qt platform-theme plugin that hypr/env.lua selects via
    # QT_QPA_PLATFORMTHEME=kde — without it Qt apps log "Could not load platform theme 'kde'" and
    # fall back to unthemed dialogs/fonts.
    kdePackages.plasma-integration
    gnome-keyring adw-gtk3 bibata-cursors eza fish starship
    # GTK icon theme (the dots don't ship one — GTK apps fall back to no/odd icons otherwise);
    # MoreWaita is the end-4 community default, adwaita-icon-theme is its inherited fallback.
    morewaita-icon-theme adwaita-icon-theme
    # Session bits the ii hypr config execs/scripts expect:
    #   easyeffects  -> hyprland/execs.lua `easyeffects --hide-window --service-mode`
    #   mpvpaper + ffmpeg -> switchwall.sh / __restore_video_wallpaper.sh video wallpapers
    #   gnome-desktop -> GnomeDesktop GObject-introspection typelib for the thumbnail generator
    easyeffects mpvpaper ffmpeg gnome-desktop
  ];

  # ---- GTK dark mode + theme seeding ----
  # The ii dots only set these dconf keys at runtime (scripts/colors/switchwall.sh, on a
  # wallpaper/color switch). On a fresh login they're unset, so GTK apps render LIGHT while the
  # ii shell is dark. Seed them declaratively so GTK is dark from first login; switchwall still
  # overrides gtk-theme/color-scheme on light/dark toggle (same keys — no conflict). adw-gtk3 +
  # MoreWaita icons + Bibata cursor are all in home.packages, so GTK can resolve the names.
  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";
    gtk-theme = "adw-gtk3-dark";
    icon-theme = "MoreWaita";
    cursor-theme = "Bibata-Modern-Classic";
    cursor-size = lib.hm.gvariant.mkUint32 24;
  };

  # ---- ii python venv ($ILLOGICAL_IMPULSE_VIRTUAL_ENV) ----
  # The dots' venv-shebang scripts run `source $venv/bin/activate && exec python`. With NO venv that
  # `&&` short-circuits and the script silently no-ops — e.g. hyprconfigurator.py, run by-path from
  # services/HyprlandConfig.qml, which backs the ii Settings UI's Hyprland options. Build the venv
  # with --system-site-packages from iiPython so `activate` succeeds AND the bundled libs (pillow,
  # cv2, materialyoucolor, gi, …) still resolve. Recreated only when iiPython's store path changes.
  home.activation.iiVenv = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    venv="$HOME/.local/state/quickshell/.venv"
    want="$(readlink -f "${iiPython}/bin/python")"
    have="$(readlink -f "$venv/bin/python" 2>/dev/null || true)"
    if [ "$have" != "$want" ]; then
      run rm -rf "$venv"
      run ${iiPython}/bin/python -m venv --system-site-packages "$venv"
    fi
  '';
}
