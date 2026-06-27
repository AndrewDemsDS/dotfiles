# Changelog

Notable changes to the widgets this fork adds. The base shell follows
[illogical-impulse](https://github.com/end-4/dots-hyprland) and isn't tracked here.

The format follows [Keep a Changelog](https://keepachangelog.com/).

## [0.1.0] - 2026-06-26

First tagged release: the custom widget layer, a settings page that drives all of it, and a dev
harness.

### Added

- **Bar**: network/VPN pill, battery/UPS gauge (from Home Assistant), data-usage meter with a monthly
  cap, next-class timetable pill, printer pill.
- **Sidebars**: Home Assistant entity panel, RSS reader with a full-article view, and cards for
  dotfiles drift, NAS health, deadlines, self-hosted service health, git activity, and sensor sparklines.
- **Launchers** (`Super+Alt+L/G/I/H/K/P`): service launcher, homelab glance, local-LLM text actions,
  Home Assistant dashboard, printer queue, and an owner-allowlisted recon launcher.
- Inline 802.1X (enterprise Wi-Fi) entry in the network list; drag-to-reorder quick toggles.
- A **Custom** settings page that enables and configures every widget, no file editing.
- Dev tooling: `just lint/test/test-ui/deps/rollback`, a pre-commit lint hook, and CI (qmllint,
  shellcheck, Lua syntax, secret scan).
- `setup/dependencies.txt` + `just deps` to install the extra system tools.
