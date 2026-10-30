#!/bin/bash

set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

# omarchy-mac-initramfs-hooks resolves HOOKS as mkinitcpio -P does for the
# kernel's default preset (omarchy-mx-mac #248).
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
systemd="$ROOT/test/fixtures/mkinitcpio/systemd.conf"
busybox="$ROOT/test/fixtures/mkinitcpio/busybox-encrypt.conf"
mkdir -p "$tmp/conf.d" "$tmp/presets" "$tmp/bin"
export OMARCHY_MKINITCPIO_CONF_DIR="$tmp/conf.d" OMARCHY_MKINITCPIO_PRESET_DIR="$tmp/presets"

hooks() {
  OMARCHY_MKINITCPIO_CONF="${CONF:-$busybox}" OMARCHY_MKINITCPIO_KERNEL="${KERNEL:-linux-asahi}" \
    "$ROOT/bin/omarchy-mac-initramfs-hooks"
}
preset() { printf 'PRESETS=(default)\n%s\n' "$@" >"$tmp/presets/linux-asahi.preset"; }

[[ $(hooks) == "base asahi udev autodetect microcode modconf kms keyboard keymap consolefont block encrypt filesystems fsck" ]] ||
  fail "mkinitcpio.conf alone gives its HOOKS"
printf 'HOOKS=(base systemd block sd-encrypt filesystems)\n' >"$tmp/conf.d/91-test.conf"
printf 'HOOKS+=(fsck)\n' >"$tmp/conf.d/100-local.conf"
[[ $(hooks) == "base systemd block sd-encrypt filesystems fsck" ]] || fail "drop-ins join in version order" "$(hooks)"
rm "$tmp/conf.d"/*.conf
pass "mkinitcpio.conf is joined by its drop-ins in version order"

preset "default_config=$systemd"
[[ " $(hooks) " == *" systemd "* ]] || fail "a preset default_config decides"
preset "default_config=$busybox" "default_options=(-c $systemd)"
[[ " $(hooks) " == *" systemd "* ]] || fail "a -c in default_options wins over default_config"
preset 'default_options="-A systemd"'
[[ $(CONF=$busybox hooks) == *" fsck systemd" ]] || fail "-A appends hooks"
preset "default_config=$systemd" "default_options=(--skiphooks=systemd,sd-encrypt -A encrypt)"
[[ $(hooks) == "base asahi autodetect microcode modconf kms keyboard sd-vconsole block filesystems fsck encrypt" ]] ||
  fail "-S drops and -A appends hooks" "$(hooks)"
printf 'HOOKS="base systemd block sd-encrypt filesystems"\n' >"$tmp/scalar.conf"
preset "default_config=$tmp/scalar.conf" "default_options=(-vS systemd,sd-encrypt -Audev,encrypt)"
[[ $(hooks) == "base block filesystems udev encrypt" ]] || fail "a scalar HOOKS and bundled -vS resolve as mkinitcpio does" "$(hooks)"
preset "default_config=$systemd" "default_options=(-S autodetect -- -S systemd)"
[[ $(hooks) == "base systemd asahi microcode modconf kms keyboard sd-vconsole block sd-encrypt filesystems fsck" ]] ||
  fail "-- ends the options, as parseopts does" "$(hooks)"
preset 'default_options="--skip systemd"'
[[ " $(CONF=$systemd hooks) " != *" systemd "* ]] || fail "a unique long prefix (--skip) is --skiphooks"
for options in "(-c $busybox)" "(-c$busybox)" "\"-c $busybox\"" "(--config=$busybox)" "(--conf $busybox)"; do
  preset "default_config=$systemd" "default_options=$options"
  [[ $(hooks) == "base asahi udev autodetect microcode modconf kms keyboard keymap consolefont block encrypt filesystems fsck" ]] ||
    fail "default_options=$options selects the busybox configuration" "$(hooks)"
done
pass "the preset's configuration and options decide the hooks as mkinitcpio parses them"

preset 'default_options="-x"'
if hooks >/dev/null; then fail "an option mkinitcpio does not know leaves the hooks unknown"; fi
rm "$tmp/presets/linux-asahi.preset"
if CONF="$tmp/missing.conf" hooks >/dev/null; then fail "an unreadable configuration is unknown"; fi
printf 'MODULES=()\n' >"$tmp/nohooks.conf"
if CONF="$tmp/nohooks.conf" hooks >/dev/null; then fail "a configuration without HOOKS is unknown"; fi
pass "an unknown option, an unreadable configuration or no HOOKS exit 1"

cat >"$tmp/bin/pacman" <<'SH'
#!/bin/bash
[[ $* == "-Qq" ]] || exit 1
[[ ${QUERY_FAIL:-0} == 0 ]] || exit 1
printf '%s\n' "${PACKAGES-linux-aurora}"
SH
chmod +x "$tmp/bin/pacman"
printf 'PRESETS=(default)\ndefault_config=%s\n' "$systemd" >"$tmp/presets/linux-aurora.preset"
[[ " $(PATH="$tmp/bin:$ROOT/bin:$PATH" OMARCHY_MKINITCPIO_CONF=$busybox "$ROOT/bin/omarchy-mac-initramfs-hooks") " == *" systemd "* ]] ||
  fail "the installed kernel's preset is read"
pass "the preset follows the installed Apple Silicon kernel"

printf 'PRESETS=(default)\ndefault_config=%s\n' "$busybox" >"$tmp/presets/linux-asahi.preset"
for packages in '' linux $'linux-aurora\nlinux-omarchy-m4-research' $'linux-asahi\nlinux-aurora'; do
  if PACKAGES="$packages" PATH="$tmp/bin:$ROOT/bin:$PATH" OMARCHY_MKINITCPIO_CONF=$busybox \
    "$ROOT/bin/omarchy-mac-initramfs-hooks" >/dev/null 2>&1; then
    fail "ambiguous installed kernels do not silently select the linux-asahi preset"
  fi
done
if QUERY_FAIL=1 PATH="$tmp/bin:$ROOT/bin:$PATH" OMARCHY_MKINITCPIO_CONF=$busybox \
  "$ROOT/bin/omarchy-mac-initramfs-hooks" >/dev/null 2>&1; then
  fail "an unreadable package database does not silently select a preset"
fi
if PATH="$tmp/bin:$ROOT/bin:$PATH" OMARCHY_MKINITCPIO_CONF=$busybox OMARCHY_MKINITCPIO_KERNEL='../other' \
  "$ROOT/bin/omarchy-mac-initramfs-hooks" >/dev/null 2>&1; then
  fail "an explicit kernel cannot traverse outside the preset directory"
fi
printf 'PRESETS=(default)\ndefault_config=%s\n' "$systemd" >"$tmp/presets/linux-omarchy-m4-research.preset"
[[ " $(PACKAGES=$'linux-aurora\nlinux-omarchy-m4-research' PATH="$tmp/bin:$ROOT/bin:$PATH" \
  OMARCHY_MKINITCPIO_CONF=$busybox OMARCHY_MKINITCPIO_KERNEL=linux-omarchy-m4-research \
  "$ROOT/bin/omarchy-mac-initramfs-hooks") " == *" systemd "* ]] ||
  fail "an explicit M4 preset is inspected even when another kernel is installed"
pass "ambiguous or unreadable kernel selection fails closed, while an explicit safe preset is supported"
