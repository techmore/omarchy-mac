#!/bin/bash
# Test only in a disposable Arch ARM root inside an isolated Linux VM.
set -euo pipefail
[[ ${M4_DISPOSABLE_ARCH_TEST:-} == 1 && $(id -u) == 0 ]] || exit 1
base=$(realpath -e "${1:?fixture base required}")
root=$(realpath -e "$base/root")
[[ $base == /home/*/m4-arch-arm-validation && $root == "$base/root" && $root != / &&
  -f $root/.omarchy-m4-disposable-test && ! -L $root/.omarchy-m4-disposable-test ]] || exit 1
grep -qx 'ID=archarm' "$root/etc/os-release" || exit 1
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

hook="$root/usr/share/libalpm/hooks/05-omarchy-mac-m4-research-guard.hook"
guard="$root/usr/lib/omarchy-mac/boot/m4-research-transaction-guard"
[[ ! -e $hook && ! -L $hook && ! -e $guard && ! -L $guard ]] || exit 1
install -Dm644 "$base/05-omarchy-mac-m4-research-guard.hook" "$hook"
install -Dm755 "$base/m4-research-transaction-guard" "$guard"
trap 'rm -f "$hook" "$guard"' EXIT
mkdir -p "$root/tmp/m4-guard-db/local"
stage2="$root/boot/efi/m1n1/boot.bin"
updates="$root/tmp/m4-transaction/m1n1-hook.log"
[[ -s $stage2 && -f $updates ]] || exit 1
stage2_hash=$(sha256sum "$stage2" | cut -d' ' -f1)
updates_hash=$(sha256sum "$updates" | cut -d' ' -f1)
printf '%s  %s\n' \
  368409870fe34921b7e4ba667f5af619616428195f286bf648b750e15c5f80c3 \
  "$root/tmp/m4-transaction/m1n1-omarchy-m4-research-1.6.1.r1-1-aarch64.pkg.tar.gz" \
  9d485130c9446873b1d413bd947b8607be4da9a2d4226c6ecfcc4b4a33696122 \
  "$root/tmp/m4-transaction/linux-omarchy-m4-research-7.1.13.r7-1-aarch64.pkg.tar.gz" | sha256sum -c --status

for package in m1n1-omarchy-m4-research-1.6.1.r1-1-aarch64.pkg.tar.gz \
  linux-omarchy-m4-research-7.1.13.r7-1-aarch64.pkg.tar.gz; do
  [[ -f $root/tmp/m4-transaction/$package ]] || exit 1
  for operation in install upgrade; do
    args=()
    if [[ $operation == install ]]; then
      # An empty disposable database makes pacman treat this as a fresh install.
      # Existing fixture files are ignored; the hook must abort before writes.
      args=(--dbpath /tmp/m4-guard-db --nodeps --nodeps --overwrite '*')
    fi
    log="$base/guard-$operation-${package%%-*}.log"
    if chroot "$root" /usr/bin/pacman "${args[@]}" -U --noconfirm \
      "/tmp/m4-transaction/$package" >"$log" 2>&1; then
      echo "guard did not abort $operation of $package" >&2
      exit 1
    fi
    grep -Fq 'M4 research packages are not qualified for installation or upgrade.' "$log" ||
      { cat "$log" >&2; exit 1; }
  done
done

# An unrelated installed package must still be able to upgrade/reinstall.
chroot "$root" /usr/bin/pacman -U --noconfirm \
  /var/cache/pacman/pkg/cpio-2.15-3-aarch64.pkg.tar.xz >"$base/guard-unrelated.log" 2>&1
! grep -Fq 'M4 research packages are not qualified' "$base/guard-unrelated.log"
[[ $(sha256sum "$stage2" | cut -d' ' -f1) == "$stage2_hash" &&
  $(sha256sum "$updates" | cut -d' ' -f1) == "$updates_hash" ]] || exit 1
echo 'Fresh install and upgrade of both research packages were blocked before the updater; unrelated cpio reinstall passed.'
