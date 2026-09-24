#!/usr/bin/env bash
set -euo pipefail

flake_file=${1:-flake.nix}
readme_file=${2:-README.md}
smoke_file=${3:-docs/BOOT-SMOKE.md}

test "$(grep -Fc 'host = "0.0.0.0";' "$flake_file")" -eq 2
test "$(grep -Fc 'port = 11434;' "$flake_file")" -eq 2
test "$(grep -Fc '{\"model\":\"devstral\"' "$flake_file")" -eq 2

grep -Fq 'http://devstral.local:11434/v1' "$readme_file"
grep -Fq 'model: devstral' "$readme_file"
grep -Fq 'API key: ollama' "$readme_file"
grep -Fq 'wire_api = "responses"' "$readme_file"
grep -Fq "Do not use Codex \`--oss\`" "$readme_file"
grep -Fq 'models=$(curl --fail --silent --show-error' "$smoke_file"
grep -Fq 'grep -Eq '\''"id":"devstral(:latest)?"'\'' <<<"$models"' "$smoke_file"

printf '%s\n' 'T18 OpenAI-compatible LAN target test passed.'
