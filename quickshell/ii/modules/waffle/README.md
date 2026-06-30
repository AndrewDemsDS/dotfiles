# Waffle

A Windows-style shell variant, recreated in Quickshell. Work in progress; currently just the bar.

## Switching to it

- Full illogical-impulse install: press `Super+Alt+W` to switch styles.
- Config-only install: run the shell with `qs -c ii`, then `qs -c ii ipc call panelFamily cycle`.

## Notes on the Quickshell port

This replaces an earlier EWW version. The Quickshell rewrite gained a few things:

- **Expanded click targets.** QtQuick `Button` exposes `topInset`/`bottomInset`/`leftInset`/`rightInset`,
  so clickable regions extend past the button background without wrapping content in an eventbox.
- **Transforms.** QtQuick applies `rotation` and `scale` almost anywhere, so bouncy icons and rotating
  chevrons are straightforward. GTK3 CSS has no transform support.
- **Built-in system tray.** Quickshell ships a tray service, so the layout no longer needs Waybar for
  the tray.
- **Live style switching.** A `Loader` swaps this style in and out from the main style without
  restarting the widget system.
- **Fixed sizing.** Sizes are hardcoded, scaled at runtime through Qt's `QT_SCALE_FACTOR`.

## Known friction

- QtQuick `Rectangle` has no per-side borders like CSS. Directional borders are drawn manually.
- Fluent Icons are harder to use than Material Symbols: no searchable codepoint cheatsheet, no
  ligatures, and the names describe shapes rather than actions (the reload icon is `arrow-sync`).
  The icons here are individual SVGs from fluenticon.com and fluenticons.co. Per Fluent Design's
  [iconography guidance](https://fluent2.microsoft.design/iconography), the names are literal
  metaphors for the shape, not the function.
