#!/usr/bin/env bash
set -euo pipefail

flake_file=${1:-flake.nix}
spec_file=${2:-SPEC.md}

test "$(grep -Fc 'wantedBy = [ "multi-user.target" ];' "$flake_file")" -eq 2
test "$(grep -Fc 'Restart = "always";' "$flake_file")" -eq 2
grep -Fq 'T19|x|ollama systemd unit enabled + Restart=always' "$spec_file"

printf '%s\n' 'T19 Ollama systemd persistence test passed.'
