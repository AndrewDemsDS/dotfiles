# dotfiles

A Hyprland desktop built on [end-4's illogical-impulse](https://github.com/end-4/dots-hyprland), with
a set of extra Quickshell widgets I use to run a homelab and my day-to-day machine.

The base shell, theming, and most of the `quickshell/` and `hypr/` trees come from illogical-impulse
(GPL-3.0). This repo adds a layer of self-contained widgets on top: a Home Assistant panel, a battery
gauge fed by a BMS, a NAS guard, a printer queue, an RSS reader, and a few launchers. You turn each one
on and configure it from the settings app.

> Looking for the upstream project? Go to
> [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland). This is a personal fork. It tracks
> upstream and isn't a drop-in replacement.

## What's added

Each widget has an `enable` flag and a section in **Settings → Custom**. You don't edit files. Personal
values live in an untracked `config.json`; the repo ships empty defaults.

**Bar**

- **Network / VPN pill**: current SSID, VPN state, and whether the network is one you trust.
- **Battery / UPS gauge**: reads a battery's charge from Home Assistant and warns when mains drops.
- **Data usage**: live up/down throughput plus a running monthly total with a cap warning.
- **Next class**: the next item from a local `.ics`/`.json` timetable, with a countdown.
- **Printer**: shows up when there's a job or a fault. Click it for the queue.

**Sidebars**

- **Home Assistant**: a tab of entity tiles (lights, climate, locks, media) with per-entity controls.
- **News**: an RSS/Atom reader with a full-article view. Text and images are extracted server-side.
- **Cards**: dotfiles drift, NAS free space and container health, assignment deadlines, self-hosted
  service health, recent git activity, and live sensor sparklines.

**Launchers**

Real floating windows: `Super+Q` closes them, and you can drag and resize.

| Key | Opens |
|-----|-------|
| `Super+Alt+L` | Service launcher (homelab apps open in a browser app-window) |
| `Super+Alt+G` | Homelab glance (UPS, NAS, news, weather in one panel) |
| `Super+Alt+I` | Local-LLM text actions on the selection (Ollama) |
| `Super+Alt+H` | Home Assistant dashboard |
| `Super+Alt+K` | Printer queue |
| `Super+Alt+P` | Recon launcher (owner-allowlisted, for your own hosts) |

The network list also handles 802.1X (enterprise Wi-Fi) inline, and you can drag to reorder quick toggles.

## Install

This forks illogical-impulse, so run the
[upstream install](https://end-4.github.io/dots-hyprland-wiki/) first. It pulls in Hyprland, Quickshell,
and the base config. Then point it at this repo, or clone over the top of `~/.config` (the repo is laid
out as `~/.config`).

The extra widgets need a few system tools beyond the base:

```sh
just deps              # core tools (cups, wl-clipboard, grim, …)
just deps --optional   # also the security/recon tools
```

The package list lives in [`setup/dependencies.txt`](setup/dependencies.txt).

## Configuration

- **Settings → Custom** has a section per widget. The enable switch comes first, then the options.
- Secrets (a Home Assistant token, a git API token) go in `quickshell/secrets/`, which is gitignored.
- The repo commits nothing personal. Defaults ship empty and you fill them in from the settings app.

## Development

[CONTRIBUTING.md](CONTRIBUTING.md) covers the worktree → lint → test → deploy loop and the conventions.
The short version:

```sh
just lint        # qmllint the changed QML
just test        # functional smoke test against the running shell
just test-ui     # interactive checks (drives input, screenshots)
just rollback    # revert the live config to the previous commit
```

## Credits

- [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland): the illogical-impulse base.
- [Quickshell](https://quickshell.org/): the QtQuick shell toolkit.
- [Hyprland](https://hyprland.org/): the compositor.

## AI assistance

A good part of the added widget code, and this README, were written with AI assistance.
I run and maintain the result as my daily desktop and tested what shipped, but it's fair
to be upfront that it came together as fast as it did with that help.

## License

GPL-3.0, the same as upstream. See [LICENSE](LICENSE). As a derivative of illogical-impulse it has to be.
