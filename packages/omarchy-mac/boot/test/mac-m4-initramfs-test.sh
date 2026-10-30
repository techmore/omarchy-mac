#!/bin/bash
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
conf=$ROOT/files/etc/mkinitcpio.conf.d/95-omarchy-mac-m4-research.conf
repo=$(cd -- "$ROOT/../../.." && pwd)
preset=$repo/m4-mini/arch-research/linux-omarchy-m4-research.preset
kver=7.1.13-omarchy-m4-r7-ARCH
mkdir -p "$tmp/bin" "$tmp/root/lib/modules/$kver" "$tmp/info"
printf 'linux-omarchy-m4-research\n' >"$tmp/root/lib/modules/$kver/pkgbase"
cat >"$tmp/bin/modinfo" <<'SH'
#!/bin/bash
[[ $1 == -b && $2 == "$TEST_MODULE_ROOT" && $3 == -k && $4 == "$TEST_KERNEL" && $5 == -F && $6 == filename ]] || exit 2
[[ -f $TEST_MODINFO/$7 ]] || exit 1
cat "$TEST_MODINFO/$7"
SH
chmod +x "$tmp/bin/modinfo"
printf '/lib/modules/%s/kernel/drivers/nvme/host/nvme-apple.ko\n' "$kver" >"$tmp/info/nvme-apple"
printf '(builtin)\n' >"$tmp/info/apple-mailbox"
printf '(builtin)\n' >"$tmp/info/apple-dart"

run_conf() {
  PATH="$tmp/bin:$PATH" TEST_MODULE_ROOT="$tmp/root" TEST_KERNEL="$kver" TEST_MODINFO="$tmp/info" \
    KERNELVERSION="${1:-$kver}" bash -c '
      set -u
      _optmoduleroot=$1
      MODULES=(btrfs)
      source "$2" || exit 1
      printf "%s\n" "${MODULES[*]}"
    ' bash "$tmp/root" "$conf"
}
[[ $(run_conf) == "btrfs nvme-apple" ]] || fail "M4 adds Apple NVMe and skips built-in mailbox and DART"
[[ $(run_conf 6.17.0-aurora1-ARCH) == "btrfs" ]] || fail "other kernels are not changed"
rm "$tmp/info/nvme-apple"
if run_conf >/dev/null 2>&1; then fail "missing M4 NVMe is refused"; fi
printf '(builtin)\n' >"$tmp/info/nvme-apple"
[[ $(run_conf) == "btrfs" ]] || fail "built-in M4 NVMe does not become a module entry"
printf 'linux-aurora\n' >"$tmp/root/lib/modules/$kver/pkgbase"
if run_conf >/dev/null 2>&1; then fail "a different package identity is refused"; fi
pass "M4 storage selection is target-scoped, supports built-ins and refuses missing drivers"

source "$preset"
[[ ${PRESETS[*]} == "default fallback" ]] || fail "both initramfs images are enabled"
[[ $ALL_kver == "/boot/vmlinuz-linux-omarchy-m4-research" ]] || fail "the preset names the copied research kernel"
[[ $default_image == "/boot/initramfs-linux-omarchy-m4-research.img" &&
   $fallback_image == "/boot/initramfs-linux-omarchy-m4-research-fallback.img" &&
   $fallback_options == "-S autodetect" ]] || fail "fallback keeps a distinct image and skips autodetection"
pass "the M4 preset builds separate default and fallback initramfs images"
