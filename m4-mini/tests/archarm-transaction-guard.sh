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
coexistence_hook="$root/usr/share/libalpm/hooks/06-omarchy-mac-m4-coexistence-guard.hook"
coexistence_guard="$root/usr/lib/omarchy-mac/boot/m4-coexistence-guard"
for path in "$hook" "$guard" "$coexistence_hook" "$coexistence_guard"; do
  [[ ! -e $path && ! -L $path ]] || exit 1
done
install -Dm644 "$base/05-omarchy-mac-m4-research-guard.hook" "$hook"
install -Dm755 "$base/m4-research-transaction-guard" "$guard"
install -Dm644 "$base/06-omarchy-mac-m4-coexistence-guard.hook" "$coexistence_hook"
install -Dm755 "$base/m4-coexistence-guard" "$coexistence_guard"
baseline_db="" research_record=""
cleanup() {
  umount "$root/var/lib/pacman" 2>/dev/null || :
  rm -f "$hook" "$guard" "$coexistence_hook" "$coexistence_guard" \
    "$root/usr/lib/asahi-boot/m4-guard-fixture" \
    "$root/usr/share/omarchy-platform/dtb-overlays/m4-guard-fixture/test.dtbo"
  [[ -z $baseline_db ]] || rm -rf -- "$baseline_db"
  [[ -z $research_record ]] || rm -rf -- "$research_record"
}
trap cleanup EXIT
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
  case $package in
    m1n1-*) pkgname=m1n1-omarchy-m4-research ;;
    linux-*) pkgname=linux-omarchy-m4-research ;;
  esac
  for operation in install upgrade remove; do
    args=()
    if [[ $operation == install ]]; then
      # An empty disposable database makes pacman treat this as a fresh install.
      # Existing fixture files are ignored; the hook must abort before writes.
      args=(--dbpath /tmp/m4-guard-db --nodeps --nodeps --overwrite '*')
    fi
    log="$base/guard-$operation-${package%%-*}.log"
    if [[ $operation == remove ]]; then
      args=(--nodeps --nodeps -R --noconfirm "$pkgname")
    else
      args+=(-U --noconfirm "/tmp/m4-transaction/$package")
    fi
    if chroot "$root" /usr/bin/pacman "${args[@]}" >"$log" 2>&1; then
      echo "guard did not abort $operation of $package" >&2
      exit 1
    fi
    grep -Fq 'M4 research package installation, upgrade and removal are not qualified.' "$log" ||
      { cat "$log" >&2; exit 1; }
  done
done

# An unrelated package that touches an Asahi loader path triggers the existing
# m1n1 hook too. With M4 installed, it must be stopped before that hook runs.
fixture="$root/tmp/m4-transaction/guard-fixture"
mkdir -p "$fixture/usr/lib/asahi-boot" "$fixture/usr/share/omarchy-platform/dtb-overlays/m4-guard-fixture"
printf 'fixture\n' >"$fixture/usr/lib/asahi-boot/m4-guard-fixture"
printf 'fixture\n' >"$fixture/usr/share/omarchy-platform/dtb-overlays/m4-guard-fixture/test.dtbo"
cat >"$fixture/.PKGINFO" <<'PKG'
pkgname = m4-guard-fixture
pkgbase = m4-guard-fixture
pkgver = 1-1
pkgdesc = Disposable package hook fixture
arch = aarch64
builddate = 0
packager = fixture
size = 8
PKG
tar -czf "$root/tmp/m4-transaction/m4-guard-fixture-1-1-aarch64.pkg.tar.gz" -C "$fixture" .PKGINFO usr
if chroot "$root" /usr/bin/pacman -U --noconfirm \
  /tmp/m4-transaction/m4-guard-fixture-1-1-aarch64.pkg.tar.gz >"$base/guard-coexistence.log" 2>&1; then
  echo 'guard did not stop an unrelated m1n1-triggering package' >&2
  exit 1
fi
grep -Fq 'An unqualified M4 research package is installed' "$base/guard-coexistence.log"
[[ ! -e $root/usr/lib/asahi-boot/m4-guard-fixture &&
  $(sha256sum "$stage2" | cut -d' ' -f1) == "$stage2_hash" &&
  $(sha256sum "$updates" | cut -d' ' -f1) == "$updates_hash" ]] || exit 1

# Hide the real fixture database in this namespace and retain only cpio's
# record, to test the normal no-M4 case without changing the original DB.
baseline_db=$(mktemp -d "$root/tmp/m4-guard-baseline-db.XXXXXX")
mkdir -p "$baseline_db/local"
cp -a "$root"/var/lib/pacman/local/cpio-* "$baseline_db/local/"
cp -a "$root/var/lib/pacman/local/ALPM_DB_VERSION" "$baseline_db/local/"
research_record=$(mktemp -d "$root/tmp/m4-guard-research-record.XXXXXX")
cp -a "$root"/var/lib/pacman/local/linux-omarchy-m4-research-* "$research_record/"
mount --bind "$baseline_db" "$root/var/lib/pacman"
chroot "$root" /usr/bin/pacman --nodeps --nodeps -U --noconfirm \
  /tmp/m4-transaction/m4-guard-fixture-1-1-aarch64.pkg.tar.gz >"$base/guard-baseline.log" 2>&1
[[ -f $root/usr/lib/asahi-boot/m4-guard-fixture &&
  $(sha256sum "$updates" | cut -d' ' -f1) != "$updates_hash" ]] || exit 1
# Simulate a later M4 install in this disposable database, then prove that a
# package upgrade and removal which touch an overlay are stopped too.
cp -a "$research_record"/linux-omarchy-m4-research-* "$baseline_db/local/"
baseline_updates_hash=$(sha256sum "$updates" | cut -d' ' -f1)
for operation in upgrade remove; do
  if [[ $operation == upgrade ]]; then
    args=(--nodeps --nodeps -U --noconfirm /tmp/m4-transaction/m4-guard-fixture-1-1-aarch64.pkg.tar.gz)
  else
    args=(--nodeps --nodeps -R --noconfirm m4-guard-fixture)
  fi
  if chroot "$root" /usr/bin/pacman "${args[@]}" >"$base/guard-overlay-$operation.log" 2>&1; then
    echo "guard did not stop overlay $operation" >&2
    exit 1
  fi
  grep -Fq 'An unqualified M4 research package is installed' "$base/guard-overlay-$operation.log"
done
[[ -f $root/usr/share/omarchy-platform/dtb-overlays/m4-guard-fixture/test.dtbo &&
  $(sha256sum "$updates" | cut -d' ' -f1) == "$baseline_updates_hash" ]] || exit 1
umount "$root/var/lib/pacman"
rm -f "$root/usr/lib/asahi-boot/m4-guard-fixture" \
  "$root/usr/share/omarchy-platform/dtb-overlays/m4-guard-fixture/test.dtbo"

# An unrelated installed package must still be able to upgrade/reinstall.
chroot "$root" /usr/bin/pacman -U --noconfirm \
  /var/cache/pacman/pkg/cpio-2.15-3-aarch64.pkg.tar.xz >"$base/guard-unrelated.log" 2>&1
! grep -Fq 'M4 research package installation, upgrade and removal are not qualified' "$base/guard-unrelated.log"
[[ $(sha256sum "$stage2" | cut -d' ' -f1) == "$stage2_hash" ]] || exit 1
echo 'Research install, upgrade and removal, and other m1n1 triggers with M4 installed, were blocked; baseline fixture and unrelated cpio reinstall passed.'
