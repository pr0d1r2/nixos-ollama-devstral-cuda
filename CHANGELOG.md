# Changelog

All notable changes to this project are documented here.

## Unreleased

- Refresh `nixpkgs-lock` pin (nixpkgs c56a87d -> ac588ef). ruby is still 3.4.11 (CVE-2026-97229) upstream; re-run `nix flake update nixpkgs-lock` once pr0d1r2/nixpkgs-lock#94 lands.
  ruby is exposed via the optional `devShells.<system>.ruby` shell inherited from set-and-setting; whether it reaches the appliance runtime closure is unconfirmed.
