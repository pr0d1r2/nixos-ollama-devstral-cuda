export HOME="${HOME:-${TMPDIR:-/tmp}/nix-lefthook-home}"
@SETTING@/bin/sync-setting .
@SET@/bin/sync-set .
cp -f @LEFTHOOK_FILES@/lefthook.yml lefthook.yml
