#!/bin/sh
# Starts a local Kev server (https://github.com/jaredpalmer/kev) on 127.0.0.1:8009 for the Kev column.
# Kev serves the same /v1/systemone API as TypeSafe's Jev. Defaults to Kev-4B (Qwen3), the fast choice
# on Apple Silicon; override with KEV_RUN (e.g. jaredpalmer/kev-4b for the Qwen3.5 generation).
set -e
KEV_DIR="${KEV_DIR:-$HOME/.cache/kev}"
KEV_RUN="${KEV_RUN:-jaredpalmer/kev-4b@qwen3}"
KEV_PORT="${KEV_PORT:-8009}"
if [ ! -d "$KEV_DIR/.git" ]; then
  git clone --depth 1 https://github.com/jaredpalmer/kev "$KEV_DIR"
fi
cd "$KEV_DIR"
uv sync --extra serve
KEV_DTYPE="${KEV_DTYPE:-bf16}" exec uv run --extra serve python -m kev.serve --run "$KEV_RUN" --port "$KEV_PORT"
