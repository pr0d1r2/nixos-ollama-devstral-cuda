#!/usr/bin/env bash
set -euo pipefail

flake_file=${1:-flake.nix}

test "$(grep -Fc 'OLLAMA_NUM_PARALLEL = "1";' "$flake_file")" -eq 2
grep -Fq 'OLLAMA_KEEP_ALIVE = "-1";' "$flake_file"

printf '%s\n' 'T17 Ollama environment test passed.'
