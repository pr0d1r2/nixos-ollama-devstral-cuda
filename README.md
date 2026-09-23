# __REPO__

<!-- hallucinogen:autonomy-disclaimer start -->
> Read [LLM-DISCLAIMER](docs/LLM-DISCLAIMER.md) first. This repository is
> tended by an autonomous loop, and that file says what the loop may do here,
> what it may not, and what to check before trusting anything in this tree.
<!-- hallucinogen:autonomy-disclaimer end -->

[![CI](https://github.com/__OWNER__/__REPO__/actions/workflows/ci.yml/badge.svg)](https://github.com/__OWNER__/__REPO__/actions/workflows/ci.yml) [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

<!-- Fill in __OWNER__ and __REPO__ when the repository coordinates are known. -->

## What it is

This flake builds a bootable x86_64 NixOS ISO appliance with Ollama,
Devstral, CUDA support, and Avahi service discovery. The ISO is intended to
be built and booted on the Ryzen/NVIDIA target host itself. The model and
runtime are embedded in the image, so the appliance does not need to pull the
model after boot.

## Usage

Build the ISO natively on the Ryzen x86_64-linux host:

```sh
nix build .#iso
```

The command leaves the generated artifact under `result/` (the ISO filename
is provided by `nixos-generators`). This build is intentionally not part of
the lightweight GitHub Actions checks, and the aarch64-darwin Mac is not a
supported ISO build host.

To write the ISO to a USB drive, stay on the same Ryzen host and follow
[the USB delivery procedure](docs/DELIVERY.md). It verifies the target disk
before using `dd`; there is no Mac roundtrip.

The appliance serves Ollama on `devstral.local:11434` and publishes the
`_ollama._tcp` and `_http._tcp` Avahi services. Port 11434 has no
authentication or TLS; connect it only to a trusted LAN.

## License

Licensed under the MIT License. See [LICENSE](LICENSE).
