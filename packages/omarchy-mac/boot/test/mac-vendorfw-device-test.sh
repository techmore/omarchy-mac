#!/bin/bash
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"
selector=$ROOT/files/usr/lib/omarchy/initcpio/omarchy-vendorfw-device.sh
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/disk/by-partuuid" "$tmp/disk/by-uuid" "$tmp/bin"
cat >"$tmp/bin/blkid" <<'SH'
#!/bin/sh
printf 'called\n' >> "$TEST_CALLS"
[ "$1" = -U ] && [ "$2" = 4F4D-5801 ] || exit 1
printf '/dev/test-esp\n'
SH
chmod +x "$tmp/bin/blkid"
export PATH="$tmp/bin:$PATH" TEST_CALLS="$tmp/calls"
source "$selector"
touch "$tmp/disk/by-partuuid/abcdef01-2222" "$tmp/disk/by-uuid/4F4D-5801"
[[ $(omarchy_vendorfw_device "$tmp/disk" ABCDEF01-2222 4F4D-5801) == "$tmp/disk/by-partuuid/abcdef01-2222" ]] ||
  fail "m1n1's chosen ESP takes priority over the image UUID"
[[ ! -e $tmp/calls ]] || fail "the selector did not query the unrelated image UUID"
rm "$tmp/disk/by-partuuid/abcdef01-2222"
if omarchy_vendorfw_device "$tmp/disk" abcdef01-2222 4F4D-5801 >/dev/null; then
  fail "a missing chosen ESP must not fall back to a different installation"
fi
if omarchy_vendorfw_device "$tmp/disk" '../other' 4F4D-5801 >/dev/null; then
  fail "an invalid PARTUUID is rejected"
fi
[[ $(omarchy_vendorfw_device "$tmp/disk" '' 4F4D-5801) == "$tmp/disk/by-uuid/4F4D-5801" ]] ||
  fail "the image UUID is used when m1n1 did not supply a PARTUUID"
rm "$tmp/disk/by-uuid/4F4D-5801"
[[ $(omarchy_vendorfw_device "$tmp/disk" '' 4F4D-5801) == "/dev/test-esp" ]] ||
  fail "blkid remains a fallback when the image UUID symlink is missing"
pass "vendor firmware follows the chosen ESP and never falls back to another OS when it is missing"
