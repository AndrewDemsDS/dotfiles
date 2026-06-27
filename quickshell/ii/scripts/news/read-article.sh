#!/usr/bin/env bash
# Reader extractor wrapper. Uses the reader venv if present, else system python3.
# Set up once: python3 -m venv ~/.local/state/quickshell/reader-venv \
#              && ~/.local/state/quickshell/reader-venv/bin/pip install 'trafilatura[all]'
VENV="$HOME/.local/state/quickshell/reader-venv/bin/python"
PY="$VENV"
[ -x "$PY" ] || PY="python3"
exec "$PY" "$(dirname "$0")/read_article.py" "$@"
