export HOME="${HOME:-${TMPDIR:-/tmp}/nix-lefthook-home}"
@SETTING@/bin/sync-setting .
@SET@/bin/sync-set .
cp -f @LEFTHOOK@/lefthook.yml lefthook.yml
