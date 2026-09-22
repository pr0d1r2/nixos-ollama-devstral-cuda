#!/usr/bin/env bash
set -euo pipefail

export HOME="$TMPDIR/home"
out="${out:?output path is required}"
export OLLAMA_MODELS="$out"
mkdir -p "$HOME" "$out"
ollama serve >"$TMPDIR/ollama.log" 2>&1 &
server=$!
trap 'kill "$server"' EXIT
until curl --fail --silent http://127.0.0.1:11434/api/tags >/dev/null; do
  sleep 1
done
ollama pull devstral:latest
