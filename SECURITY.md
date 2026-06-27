# Security

This is a desktop config, not a network service, so the attack surface is small. Still, a few things
are worth stating, since some widgets read tokens and run local commands.

## Reporting

Found something? Open a private security advisory on the repo, or email the address on my GitHub
profile. Please don't file a public issue for anything exploitable until there's a fix.

## How secrets are handled

- Tokens (Home Assistant, a git API key) live in `quickshell/secrets/`, which is gitignored. They are
  read at runtime and never logged or committed.
- Personal config (hostnames, IPs, entity IDs) lives in an untracked `config.json`. The tracked
  defaults are empty.
- CI runs a secret scan (gitleaks) on every push to catch anything that slips through.

## The recon launcher

`Super+Alt+P` opens a launcher that runs read-only recon tools (`nuclei`, `whatweb`, `ffuf`) against a
target from the clipboard. It is **disabled by default** and gated by an owner allowlist: the buttons
stay disabled unless the target host matches a prefix you've added to `reconLauncher.allowlist`. Only
add hosts you own or are authorised to test. Nothing runs without an explicit click.

## Command execution

Widgets that shell out use argument arrays (`execDetached([...])`), never interpolated shell strings, so
clipboard or config values can't inject commands. Secrets are passed via environment or request bodies,
not on the command line.
