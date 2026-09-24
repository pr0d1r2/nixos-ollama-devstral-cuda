# Boot smoke

Run these checks after booting the ISO on the Ryzen/NVIDIA target host. The
commands under **Appliance console** run on the appliance; the commands under
**LAN peer** run on another machine on the same trusted LAN. Do not use
`localhost` for the LAN checks: they must prove that Ollama is reachable over
the network.

## Appliance console

Confirm that Ollama and Avahi are running and that the appliance has the
expected name:

```sh
systemctl is-active --quiet ollama
systemctl is-active --quiet avahi-daemon
hostname --short
```

The first two commands must exit successfully, and `hostname --short` must
print `devstral`. Confirm that the bundled model is present without pulling it
from the network:

```sh
ollama list
```

The output must include `devstral` (or `devstral:latest`). Confirm the NVIDIA
driver sees the GPU:

```sh
nvidia-smi
```

Keep this output for the smoke record. It must show the NVIDIA GPU and at least
16 GiB of VRAM. After Ollama has served a request, confirm that the model is
resident and using the GPU:

```sh
curl --fail --silent --show-error \
  http://devstral.local:11434/api/generate \
  -H 'Content-Type: application/json' \
  -d '{"model":"devstral","prompt":"Reply with OK.","stream":false}' \
  >/tmp/devstral-smoke.json
ollama ps
nvidia-smi
```

The request must succeed over the appliance's mDNS name, `ollama ps` must show
`devstral`, and `nvidia-smi` must show Ollama using GPU memory. A CPU-only
result does not pass the smoke.

Finally, verify the listener rather than inferring it from configuration:

```sh
listeners=$(ss -lntp | awk '$4 == "0.0.0.0:11434" { print }')
test -n "$listeners"
! ss -lntp | awk '$4 == "127.0.0.1:11434" { found = 1 } END { exit !found }'
```

The first check must find `0.0.0.0:11434`; the second must succeed because no
listener is bound to `127.0.0.1:11434`.

## LAN peer

Resolve the mDNS name and verify both the Ollama tag endpoint and the LAN
socket. Run these commands from a different machine on the same LAN:

```sh
getent hosts devstral.local
curl --fail --silent --show-error \
  http://devstral.local:11434/api/tags
curl --fail --silent --show-error \
  http://devstral.local:11434/api/generate \
  -H 'Content-Type: application/json' \
  -d '{"model":"devstral","prompt":"Reply with OK.","stream":false}'
```

`getent hosts` must resolve `devstral.local`, `/api/tags` must list
`devstral` (or `devstral:latest`), and the generate request must return a
successful response. If the LAN curl fails while a curl to `127.0.0.1` works,
the appliance fails this smoke: fix the bind before proceeding.
