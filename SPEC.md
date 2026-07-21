# SPEC — nixos-ollama-devstral-cuda

## §G — goal

Nix flake → bare bootable x86_64 NixOS ISO appliance. ISO embeds ollama + devstral (CUDA on RTX3090). Boot → serve ollama on LAN, announce `devstral.local` via avahi.

Flow: build ISO natively + fast on Ryzen 3800X/RTX3090 box → `dd` ISO to USB on that SAME box (burnable on target host, no Mac roundtrip) → boot USB on same box = the appliance. GitHub = optional light CI only (flake check + lint). NO ISO release (multi-GB, impractical).

## §C — constraints

- C1  Target/build HW: Ryzen 3800X, 32GB RAM, RTX3090 24GB VRAM. x86_64-linux. SAME box builds ISO and boots it as appliance.
- C1b Min GPU: NVIDIA ≥16GB VRAM. Devstral-24B Q4_K_M ≈14GB → fits 16GB (tight ctx), 24GB = headroom.
- C2  allowUnfree = true, cudaSupport = true.
- C3  ollama backend CUDA (`acceleration = "cuda"` / ollama-cuda).
- C4  Model = devstral (Devstral Small 24B, ollama `devstral`, Q4_K_M ~14GB). Embedded in ISO (offline boot, no runtime pull).
- C5  Avahi/mDNS: hostname `devstral`, resolve `devstral.local`, publish ollama service.
- C6  ollama listen `0.0.0.0:11434` — LAN-reachable, not localhost-only.
- C7  Flake output = bootable x86_64 ISO (`nixos-generators` format `iso`, or `isoImage` build target).
- C8  Build host = the Ryzen x86_64 box itself (native). M4 Mac = aarch64-darwin, NOT a build host (no cheap x86_64 build). No Mac nix remote-builder config.
- C9  Unfree (NVIDIA) accepted in flake config.
- C10 ISO multi-GB (model + CUDA libs). Local box has disk — no cloud runner disk limit.
- C11 Reproducible: pinned flake.lock.
- C12 Delivery: `dd result/*.iso` → USB directly on the Ryzen box (target host). No Mac scp roundtrip. Boot USB on same box.
- C13 GitHub Actions OPTIONAL + light only: flake check + lint (statix/deadnix/nixfmt/shellcheck). NO ISO build, NO release. Dev/CI lint+hook layer MATERIALIZED + tended via set-and-setting (not hand-wired). Runtime ISO unaffected. (sibling C17)
- C14 Security: 0.0.0.0 bind = no auth, no TLS. Trusted LAN ONLY. Firewall opens 11434 scoped to LAN subnet, not world. README carries mandatory trusted-network warning. (learned: sibling C5/V14)
- C15 Warm model: appliance keeps devstral resident — `OLLAMA_KEEP_ALIVE=-1` + preload `/api/generate` after boot. First LAN request must not pay ~14GB cold-load. (learned: sibling C15/V18)
- C16 Single client: `OLLAMA_NUM_PARALLEL=1`. One request served at a time; concurrent LAN requests serialize (queue), not run in parallel. Protects 24GB VRAM budget + full-offload latency — no parallel model copies/KV-cache blowup. (diverges from sibling V19 shared-concurrency by design)

## §I — external surfaces

- I.flake      `flake.nix` — inputs (nixpkgs, nixos-generators), outputs (packages.x86_64-linux.iso, nixosConfigurations.devstral)
- I.hostmod    NixOS module — ollama, avahi, nvidia, network, model embed
- I.ollama-api HTTP `:11434` — ollama REST (`/api/generate`, `/api/tags`) + OpenAI-compat `/v1` (`/v1/models`, `/v1/chat/completions`) — target for LAN coding agents
- I.mdns       `devstral.local` mDNS + avahi service (`_ollama._tcp` / `_http._tcp`)
- I.iso        build artifact `result/*.iso` (nix store) on Ryzen box
- I.burn       `dd if=*.iso of=/dev/sdX` on Ryzen box (target host) → USB
- I.ci         (optional) CI + pre-commit hooks materialized via set-and-setting — flake check + lint only, SHA-pinned. NO ISO build in cloud

## §V — invariants

- V1  `nix flake check` pass. Pure eval.
- V2  `nix build .#iso` on x86_64 produce bootable `.iso` file.
- V3  ISO boot → ollama systemd service active.
- V4  On boot `ollama list` shows devstral — no network pull (model bundled in ISO/nix store). Tag exact: `/api/tags` AND `/v1/models` return the tag agents request (`devstral` or `devstral:latest`) — no mismatch that 404s agent calls. (learned: sibling V28)
- V5  avahi-daemon active, hostname `devstral`, `devstral.local` resolvable via mDNS on LAN.
- V6  ollama bind `0.0.0.0:11434` — `curl http://devstral.local:11434/api/tags` from LAN peer returns devstral.
- V7  NVIDIA driver loads, `nvidia-smi` sees GPU (≥16GB), ollama uses CUDA (GPU offload) not CPU-only. 16GB → full offload (14GB<16GB).
- V8  allowUnfree + cudaSupport set — build not license-blocked, CUDA libs present.
- V9  Build runs natively on Ryzen x86_64 box (not Mac). Command documented + reproducible.
- V10 ISO `dd`-burnable to USB on the target host (Ryzen box) itself, boots on that box.
- V11 flake.lock committed + pinned — rebuild reproducible.
- V12 (optional CI) flake check + lint green on Actions. No ISO artifact produced in cloud.
- V13 Firewall opens 11434 to LAN subnet only (not 0.0.0.0/0). README states no-auth/no-TLS, trusted-network-only. avahi mDNS (5353/udp) likewise LAN-scoped.
- V14 `OLLAMA_KEEP_ALIVE=-1` set in service env; systemd `ExecStartPost` primes model via `/api/generate`. After boot settles, devstral resident (nvidia-smi VRAM used); first real LAN request returns without cold-load latency.
- V15 `OLLAMA_NUM_PARALLEL=1` set. Two concurrent LAN requests serialize (second waits), never run parallel. No VRAM OOM from parallel copies.
- V16 Bind verified, not assumed: boot smoke `ss -lntp | grep 11434` shows `0.0.0.0:11434` (NOT `127.0.0.1`). Healthcheck curls LAN IP / `devstral.local`, never localhost — localhost-only bind must fail the check. (sibling B1: host set but ollama bound 127.0.0.1, LAN refused)
- V17 OpenAI-compat surface live: `curl devstral.local:11434/v1/models` from LAN peer lists devstral. LAN agents (opencode/pi/codex) target base `.../v1`, model `devstral`, dummy key `ollama`. Codex gotchas: `wire_api="responses"` on recent ollama; `--oss` hardcodes localhost. (sibling V25/V28/T24-27)
- V18 Service persistence declarative: ollama systemd unit enabled (`wantedBy multi-user.target`) + `Restart=always`. Survives reboot; crash auto-restarts. NixOS equivalent of sibling LaunchAgent RunAtLoad+KeepAlive. (learned: sibling V3)

## §T — tasks

id|status|task|cites
T1|.|flake.nix skeleton: inputs nixpkgs + nixos-generators, x86_64-linux, nixosConfigurations.devstral|V1,I.flake
T2|.|nixpkgs config: allowUnfree + cudaSupport|C2,C9,V8
T3|.|nvidia module: hardware.nvidia + driver, hardware.graphics/opengl|C2,V7
T4|.|ollama module: acceleration=cuda, host 0.0.0.0:11434|C3,C6,V6,V7,I.ollama-api
T5|.|embed devstral into image (offline, no runtime pull)|C4,V4
T6|.|avahi module: hostname devstral, mdns nss, publish `_ollama`/`_http` service|C5,V5,I.mdns
T7|.|ISO output: nixos-generators format iso (or isoImage target)|C7,V2,I.iso
T8|.|networking: DHCP + firewall allow 11434 + 5353/udp mdns|C6,C5,V5,V6
T9|.|build on Ryzen: `nix build .#iso`, document command|C8,V2,V9
T10|.|delivery doc: dd result/*.iso → USB on Ryzen box (target host), no Mac roundtrip|C12,V10,I.burn
T11|.|nix flake check + local build smoke|V1,V2
T12|.|commit + pin flake.lock|C11,V11
T13|.|(optional) materialize dev/CI lint+hook layer via set-and-setting (flake check + statix/deadnix/nixfmt/shellcheck, SHA-pinned); NOT hand-wired|C13,V12,I.ci
T14|.|boot smoke doc: ollama active, devstral.local, nvidia-smi, GPU offload, LAN curl + `ss -lntp` shows 0.0.0.0:11434 (not 127.0.0.1)|V3,V4,V5,V6,V7,V16
T15|.|firewall scope 11434 to LAN subnet + README trusted-network/no-auth/no-TLS warning|C14,V13
T16|.|warm model: OLLAMA_KEEP_ALIVE=-1 in ollama env + systemd ExecStartPost preload /api/generate|C15,V14
T17|.|single client: OLLAMA_NUM_PARALLEL=1 in ollama env|C16,V15
T18|.|verify /v1 OpenAI-compat (`/v1/models` lists devstral) + README LAN-agent-target doc (base /v1, model devstral, key ollama; codex wire_api=responses, avoid --oss)|V17,I.ollama-api
T19|.|ollama systemd unit enabled + Restart=always (persist reboot, auto-restart crash)|V18

## §B — bugs

id|date|cause|fix
B1|2026-07-21|markdownlint-agentic broken on non-agentic docs: placeholder (agentic#23) + missing is-markdown-agentic classifier (markdownlint#31) + no non-agentic guard (agentic#27)|skip in gitignored `lefthook-local.yml`; loop drops skip when upstream lands
B2|2026-07-21|pinned CI action removed `HOME` from its pure install-stage environment, causing Git-backed dev-shell setup to fail|give dev-shell hooks a temporary `HOME` fallback before Git-backed setup runs
B3|2026-07-21|markdown wrappers omitted the shared classifier and left the agentic config placeholder unsubstituted, making lefthook exit 4|package the classifier in both wrappers and substitute the pinned agentic config path
B4|2026-07-21|install-nix-action v27 collided with pre-existing Nix build-user records on macOS 15, failing with eDSRecordAlreadyExists before checks ran|upgrade and SHA-pin install-nix-action v31.11.0, whose macOS installer handles the runner image
B5|2026-07-21|the referenced guardrails workflow invoked `nix run .#confirm`, but the migrated leaf flake neither exported the required confirm app nor materialized the fragment-specific lefthook configuration expected by it|export the standard confirm app with its materialization inputs and wrappers, and materialize lefthook from the same shared fragment list as the checks
