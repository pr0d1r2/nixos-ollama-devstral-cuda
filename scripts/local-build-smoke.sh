#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' 'Checking the flake without building CI-only outputs...'
nix --extra-experimental-features 'nix-command flakes' flake check --no-write-lock-file

printf '%s\n' 'Building the native x86_64 ISO...'
nix --extra-experimental-features 'nix-command flakes' build .#iso

mapfile -t isos < <(find result -maxdepth 1 -type f -name '*.iso' -print)
if [ "${#isos[@]}" -ne 1 ]; then
  printf 'expected exactly one ISO in result/, found %d\n' "${#isos[@]}" >&2
  exit 1
fi

iso=${isos[0]}
if [ ! -s "$iso" ]; then
  printf 'ISO is empty: %s\n' "$iso" >&2
  exit 1
fi

printf 'local build smoke passed: %s\n' "$iso"
