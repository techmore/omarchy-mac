#!/bin/bash
# Produce a disposable generic-QEMU module smoke-test initramfs; never install.
set -euo pipefail
if (( $# != 2 )); then
  echo "Usage: $0 STAGED_ROOTFIX_KERNEL NEW_INITRAMFS_FILE" >&2
  exit 2
fi
stage=$(realpath -e "$1")
output=$(realpath -m -- "$2")
[[ ! -e $output && ! -L $output && ! -e $stage/INCOMPLETE ]] || exit 1
case "$output/" in "$stage/"*) echo 'Output must be outside the staging tree' >&2; exit 1;; esac
kver=7.1.13-omarchy-m4-r7-rootfix-ARCH
modules="$stage/usr/lib/modules/$kver"
[[ -f $stage/receipt.json && -f $modules/modules.dep && $(cat "$modules/pkgbase") == linux-omarchy-m4-research ]] || exit 1
printf '%s  %s\n' b45421f50feb6a6114d0f1bb694ccc6fbb1763780e9a715291ae1cc584d949fa \
  "$modules/config" | sha256sum -c --status
busybox=$(command -v busybox)
file "$busybox" | grep -Fq 'statically linked' || { echo 'A static ARM64 busybox is required' >&2; exit 1; }
file "$busybox" | grep -Fq 'ARM aarch64' || { echo 'A static ARM64 busybox is required' >&2; exit 1; }
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/root/bin" "$tmp/root/proc" "$tmp/root/sys" "$tmp/root/dev" "$tmp/root/lib/modules"
cp "$busybox" "$tmp/root/bin/busybox"
ln -s busybox "$tmp/root/bin/sh"
cp -a "$modules" "$tmp/root/lib/modules/"
cat >"$tmp/root/init" <<'SH'
#!/bin/sh
PATH=/bin
export PATH
busybox mount -t proc proc /proc
busybox mount -t sysfs sysfs /sys
failures=0
for name in asahi_m4 appledrm phy_apple_dptx nvme_apple dm_crypt dm_integrity; do
  if busybox modprobe "$name"; then
    echo "M4_MODULE_LOADED $name"
  else
    echo "M4_MODULE_FAILED $name"
    failures=$((failures + 1))
  fi
done
if [ "$failures" -eq 0 ]; then echo M4_ROOTFIX_QEMU_OK; else echo M4_ROOTFIX_QEMU_FAILED; fi
busybox poweroff -f
SH
chmod 755 "$tmp/root/init"
(cd "$tmp/root" && find . -print0 | cpio --null -o -H newc 2>"$tmp/cpio.log" | gzip -1 >"$tmp/initramfs.cpio.gz")
mv -- "$tmp/initramfs.cpio.gz" "$output"
sha256sum "$output"
echo 'Generic QEMU module test only; no Apple hardware or real boot qualification.'
