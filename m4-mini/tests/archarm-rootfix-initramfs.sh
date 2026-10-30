#!/bin/bash
# Build test images only in a marked disposable Arch ARM root in a Linux VM.
set -euo pipefail
[[ ${M4_DISPOSABLE_ARCH_TEST:-} == 1 && $(id -u) == 0 ]] || exit 1
base=$(realpath -e "${1:?fixture base required}")
root=$(realpath -e "$base/root")
[[ $base == /home/*/m4-arch-arm-validation && $root == "$base/root" && $root != / &&
  -f $root/.omarchy-m4-disposable-test && ! -L $root/.omarchy-m4-disposable-test ]] || exit 1
grep -qx 'ID=archarm' "$root/etc/os-release" || exit 1
kver=7.1.13-omarchy-m4-r7-rootfix-ARCH
modules="$root/usr/lib/modules/$kver"
[[ $(cat "$modules/pkgbase") == linux-omarchy-m4-research ]] || exit 1
printf '%s  %s\n' b45421f50feb6a6114d0f1bb694ccc6fbb1763780e9a715291ae1cc584d949fa \
  "$modules/config" | sha256sum -c --status
if [[ ${2:-} != --inside ]]; then
  exec unshare --mount --net --fork --propagation private "$0" "$base" --inside
fi
mount --bind "$root" "$root"
mount -t proc -o nosuid,nodev,noexec proc "$root/proc"
mount -t sysfs -o ro,nosuid,nodev,noexec sysfs "$root/sys"
mount -t tmpfs -o mode=755,nosuid tmpfs "$root/dev"
mount -t tmpfs -o mode=755,nosuid,nodev tmpfs "$root/run"
for spec in 'null 3' 'zero 5' 'random 8' 'urandom 9'; do
  read -r name minor <<<"$spec"
  mknod -m 666 "$root/dev/$name" c 1 "$minor"
done
ln -s /proc/self/fd "$root/dev/fd"
ln -s /proc/self/fd/0 "$root/dev/stdin"
ln -s /proc/self/fd/1 "$root/dev/stdout"
ln -s /proc/self/fd/2 "$root/dev/stderr"

mkdir -p "$root/tmp/m4-rootfix-initramfs"
for kind in default fallback; do
  args=()
  [[ $kind != fallback ]] || args=(-S autodetect)
  chroot "$root" /usr/bin/mkinitcpio --nopost -k "$kver" "${args[@]}" \
    -g "/tmp/m4-rootfix-initramfs/$kind.img" >"$base/rootfix-$kind.log" 2>&1
  ! grep -Eq '^==> ERROR:|^error:' "$base/rootfix-$kind.log" || exit 1
  chroot "$root" /usr/bin/lsinitcpio -l "/tmp/m4-rootfix-initramfs/$kind.img" >"$base/rootfix-$kind.list"
  for module in nvme-apple nvme-core apple-sart dm-mod dm-bufio dm-crypt dm-integrity appledrm asahi-m4 phy-apple-dptx; do
    pattern=${module//-/[-_]}
    grep -F "usr/lib/modules/$kver/" "$base/rootfix-$kind.list" | \
      grep -Eq "/${pattern}\\.ko(\\.(gz|xz|zst))?$" || {
      echo "$kind image lacks $module" >&2
      exit 1
    }
  done
  for path in usr/bin/btrfs usr/bin/cpio usr/bin/cryptsetup usr/bin/systemd-cryptsetup \
    usr/lib/omarchy/initcpio/omarchy-vendorfw-device.sh \
    usr/lib/systemd/system/omarchy-vendorfw-initrd.service \
    usr/lib/systemd/system/omarchy-mac-encrypt.service \
    usr/lib/systemd/system/systemd-cryptsetup@.service.d/omarchy-vendorfw-initrd.conf \
    usr/lib/systemd/system-generators/systemd-cryptsetup-generator; do
    grep -Fxq "$path" "$base/rootfix-$kind.list" || { echo "$kind image lacks $path" >&2; exit 1; }
  done
  # Ask kmod for the actual dependency closure and check it against each image.
  for module in nvme_apple dm_crypt dm_integrity appledrm asahi_m4 phy_apple_dptx; do
    deps="$base/rootfix-$kind-$module-deps.log"
    chroot "$root" /usr/bin/modprobe -S "$kver" --show-depends "$module" >"$deps"
    [[ -s $deps ]] || { echo "no dependencies reported for $module" >&2; exit 1; }
    while read -r action path remainder; do
      [[ $action == insmod && $path == "/lib/modules/$kver/"* && -z $remainder ]] || exit 1
      grep -Fxq "usr${path}" "$base/rootfix-$kind.list" || {
        echo "$kind image lacks a $module dependency: $path" >&2
        exit 1
      }
    done <"$deps"
  done
done
rm -rf "$root/tmp/m4-rootfix-initramfs/extracted"
mkdir -p "$root/tmp/m4-rootfix-initramfs/extracted"
chroot "$root" /bin/bash -c 'cd /tmp/m4-rootfix-initramfs/extracted && lsinitcpio -x ../default.img' \
  >"$base/rootfix-extract.log" 2>&1
chroot "$root" /usr/bin/systemd-analyze --root=/tmp/m4-rootfix-initramfs/extracted --man=no verify \
  omarchy-vendorfw-initrd.service omarchy-vendorfw.service omarchy-mac-encrypt.service \
  >"$base/rootfix-units.log" 2>&1
# sd-encrypt does not ship a static cryptsetup template: its generator writes
# an instance at boot. Exercise the actual generator with a fake LUKS UUID.
extracted="$root/tmp/m4-rootfix-initramfs/extracted"
mkdir -p "$extracted/run/systemd/generator" "$extracted/run/systemd/generator.early" "$extracted/run/systemd/generator.late"
chroot "$extracted" /usr/bin/env SYSTEMD_IN_INITRD=1 \
  SYSTEMD_PROC_CMDLINE='rd.luks.crypttab=0 rd.luks.name=0422663f-9969-4953-900f-b342703b7e84=root' \
  /usr/lib/systemd/system-generators/systemd-cryptsetup-generator \
  /run/systemd/generator /run/systemd/generator.early /run/systemd/generator.late \
  >"$base/rootfix-generator.log" 2>&1
generated="$extracted/run/systemd/generator/systemd-cryptsetup@root.service"
[[ -s $generated ]] && grep -Fq 'ExecStart=/usr/bin/systemd-cryptsetup attach' "$generated" || exit 1
dropin="$extracted/usr/lib/systemd/system/systemd-cryptsetup@.service.d/omarchy-vendorfw-initrd.conf"
grep -Fxq 'Wants=omarchy-vendorfw-initrd.service' "$dropin" && \
  grep -Fxq 'After=omarchy-vendorfw-initrd.service' "$dropin" || exit 1
# Offline --root verification does not search /run/systemd/generator. Copy the
# generated unit into the extracted test root's unit directory for verification.
install -m 644 "$generated" "$extracted/usr/lib/systemd/system/systemd-cryptsetup@root.service"
chroot "$root" /usr/bin/systemd-analyze --root=/tmp/m4-rootfix-initramfs/extracted --man=no verify \
  systemd-cryptsetup@root.service >>"$base/rootfix-units.log" 2>&1
[[ ! -s $base/rootfix-units.log ]] || { cat "$base/rootfix-units.log" >&2; exit 1; }
chroot "$root" /usr/bin/sha256sum /tmp/m4-rootfix-initramfs/default.img /tmp/m4-rootfix-initramfs/fallback.img
echo 'Rootfix Omarchy and Asahi test images passed in the disposable Arch ARM root.'
