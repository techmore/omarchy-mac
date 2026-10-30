#!/bin/bash
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

if [[ ${M4_DISPOSABLE_CHROOT_TEST:-0} != 1 ]]; then
  pass "vendor firmware chroot runtime test skipped (opt in only on a disposable Linux VM)"
  exit 0
fi
require_command busybox
require_command sudo
require_command ldd
sudo -n true || fail "passwordless sudo is required in the disposable test VM"
tmp=$(mktemp -d)
trap 'sudo rm -rf "$tmp"' EXIT
root=$tmp/root
mkdir -p "$root/bin" "$root/usr/bin" "$root/usr/lib/omarchy/initcpio" "$root/test/bin" \
  "$root/proc/device-tree/chosen" "$root/dev/disk/by-partuuid" "$root/dev/disk/by-uuid" \
  "$root/fixture/esp/vendorfw" "$root/fixture/source/vendorfw/apple" "$root/run" "$root/lib/firmware"
cp "$(command -v busybox)" "$root/bin/busybox"
(ldd "$(command -v busybox)" 2>&1 || true) | grep -Fq 'not a dynamic executable' || fail "the fixture needs a static busybox"
cp -L /bin/sh "$root/bin/sh"
while IFS= read -r library; do
  mkdir -p "$root$(dirname "$library")"
  cp -L "$library" "$root$library"
done < <(ldd /bin/sh | awk '/=> \/[^ ]+/ { print $3 } $1 ~ /^\// { print $1 }')
for name in tr cp mkdir sleep cpio cat ln; do ln -s busybox "$root/bin/$name"; done
ln -s /bin/sh "$root/usr/bin/sh"
cp "$ROOT/files/usr/lib/omarchy/initcpio/omarchy-vendorfw-initrd.sh" "$root/usr/lib/omarchy/initcpio/"
cp "$ROOT/files/usr/lib/omarchy/initcpio/omarchy-vendorfw-device.sh" "$root/usr/lib/omarchy/initcpio/"
printf 'test firmware\n' >"$root/fixture/source/vendorfw/apple/firmware.bin"
(cd "$root/fixture/source" && find . -print | busybox cpio -o -H newc >"$root/fixture/esp/vendorfw/firmware.cpio" 2>/dev/null)
cat >"$root/test/bin/mount" <<'SH'
#!/bin/sh
printf 'mount %s\n' "$*" >>/test/calls
[ ! -e /test/fail-mount ] || exit 1
last=
for last; do :; done
case " $* " in *' -t tmpfs '*) exit 0 ;; esac
cp -r /fixture/esp/. "$last"/
SH
cat >"$root/test/bin/umount" <<'SH'
#!/bin/sh
printf 'umount %s\n' "$*" >>/test/calls
SH
cat >"$root/test/bin/sleep" <<'SH'
#!/bin/sh
exit 0
SH
chmod +x "$root/test/bin/"*
printf 'abcdef01-2222\0' >"$root/proc/device-tree/chosen/asahi,efi-system-partition"
touch "$root/dev/disk/by-partuuid/abcdef01-2222" "$root/dev/disk/by-uuid/4F4D-5801"

run_helper() {
  sudo chroot "$root" /bin/sh -c 'PATH=/test/bin:/bin /usr/lib/omarchy/initcpio/omarchy-vendorfw-initrd.sh' \
    >"$tmp/out" 2>"$tmp/err"
}
reset_helper() {
  sudo rm -rf "$root/run/omarchy-vendorfw-esp" "$root/run/omarchy-vendorfw-extract"
  sudo rm -f "$root/run/omarchy-vendorfw-initrd.staged" "$root/run/omarchy-vendorfw-initrd.status" "$root/test/calls"
}

run_helper || fail "the isolated early firmware helper runs"
grep -Fq 'mount -o ro /dev/disk/by-partuuid/abcdef01-2222 ' "$root/test/calls" || fail "chosen ESP is mounted"
[[ $(cat "$root/vendorfw/apple/firmware.bin") == 'test firmware' ]] || fail "firmware was copied"
grep -Fq 'umount /run/omarchy-vendorfw-extract' "$root/test/calls" || fail "firmware tmpfs was cleaned up"

reset_helper
rm "$root/dev/disk/by-partuuid/abcdef01-2222"
run_helper || fail "a missing chosen ESP does not fail the helper"
[[ $(cat "$root/run/omarchy-vendorfw-initrd.status") == missing ]] || fail "missing chosen ESP is recorded"
[[ ! -e $root/test/calls ]] || fail "the helper did not mount the other image ESP"

reset_helper
: >"$root/proc/device-tree/chosen/asahi,efi-system-partition"
run_helper || fail "an empty chosen ESP does not fail the helper"
[[ $(cat "$root/run/omarchy-vendorfw-initrd.status") == missing ]] || fail "empty chosen ESP is recorded"
[[ ! -e $root/test/calls ]] || fail "an empty chosen ESP does not fall back to the image ESP"

reset_helper
rm "$root/proc/device-tree/chosen/asahi,efi-system-partition"
touch "$root/test/fail-mount"
run_helper || fail "a mount failure does not block the prompt"
[[ $(cat "$root/run/omarchy-vendorfw-initrd.status") == missing ]] || fail "mount failure is recorded"
[[ ! -e $root/run/omarchy-vendorfw-initrd.staged ]] || fail "failed mount is not reported as staged"

reset_helper
rm "$root/test/fail-mount"
printf 'invalid archive\n' >"$root/fixture/esp/vendorfw/firmware.cpio"
run_helper || fail "a corrupt firmware archive does not block the prompt"
[[ $(cat "$root/run/omarchy-vendorfw-initrd.status") == missing ]] || fail "corrupt archive is recorded"
grep -Fq 'umount /run/omarchy-vendorfw-esp' "$root/test/calls" &&
  grep -Fq 'umount /run/omarchy-vendorfw-extract' "$root/test/calls" || fail "failed extraction cleans up both mounts"
pass "early firmware runtime chooses the booted ESP and handles missing, unmountable and corrupt inputs"
