#!/usr/bin/sh
# Unpack ESP vendorfw/firmware.cpio before cryptsetup so MTP firmware is
# on /lib/firmware/vendor for the sd-encrypt passphrase prompt.
# Does not overlay sysroot; omarchy-vendorfw.service still copies onto
# the unlocked root after sysroot.mount.
#
# Missing ESP or firmware.cpio is loud and recorded, but this helper
# still exits 0: a blocked passphrase prompt is worse than a trackpad
# without firmware (the keyboard needs none). The late unit and a boot
# check can read /run/omarchy-vendorfw-initrd.status.
set -eu

image_esp_uuid=4F4D-5801
. /usr/lib/omarchy/initcpio/omarchy-vendorfw-device.sh
mnt=/run/omarchy-vendorfw-esp
extract=/run/omarchy-vendorfw-extract
record=/run/omarchy-vendorfw-initrd.staged
status=/run/omarchy-vendorfw-initrd.status
esp_mounted=0
extract_mounted=0

cleanup() {
    [ "$esp_mounted" -eq 0 ] || umount "$mnt" 2>/dev/null || true
    [ "$extract_mounted" -eq 0 ] || umount "$extract" 2>/dev/null || true
}
trap cleanup EXIT

if [ -e "$record" ]; then
    exit 0
fi

# One journal line; the unit has no console, and the status record is what
# the late unit and the boot check read.
log_missing() {
    printf 'omarchy-vendorfw-initrd: %s; continuing so the passphrase prompt is not blocked\n' "$1" >&2
    printf 'missing\n' >"$status"
    exit 0
}

esp=$(omarchy_vendorfw_chosen_esp /proc/device-tree/chosen) ||
    log_missing "the booted system has invalid or conflicting EFI partition identifiers; vendor firmware was not staged"

# The chosen partition is authoritative. If it is slow or missing, never
# substitute another installed OS's image ESP just because its UUID exists.
dev=
i=0
while [ "$i" -lt 150 ]; do
    dev=$(omarchy_vendorfw_device /dev/disk "$esp" "$image_esp_uuid" || true)
    [ -z "$dev" ] || break
    sleep 0.1
    i=$((i + 1))
done
[ -n "$dev" ] || log_missing "EFI system partition ${esp:-$image_esp_uuid} is not available; vendor firmware was not staged"

mkdir -p "$mnt" || log_missing "cannot prepare the EFI mount directory"
mount -o ro "$dev" "$mnt" || log_missing "cannot mount EFI system partition $dev"
esp_mounted=1
if [ ! -f "$mnt/vendorfw/firmware.cpio" ]; then
    log_missing "ESP $dev has no vendorfw/firmware.cpio; vendor firmware was not staged"
fi

mkdir -p "$extract" || log_missing "cannot prepare the firmware extraction directory"
mount -t tmpfs -o mode=0755 omarchy-vendorfw-extract "$extract" || log_missing "cannot mount firmware extraction tmpfs"
extract_mounted=1
(cd "$extract" && cpio -i <"$mnt/vendorfw/firmware.cpio") || log_missing "cannot extract firmware.cpio from $dev"
umount "$mnt" || log_missing "cannot unmount EFI system partition $dev"
esp_mounted=0

src=$extract/vendorfw
if [ ! -d "$src" ]; then
    src=$extract
fi

vendor=/lib/firmware/vendor
if [ -L "$vendor" ]; then
    dest=/vendorfw
    mkdir -p "$dest" || log_missing "cannot prepare $dest"
elif [ -d "$vendor" ]; then
    dest=$vendor
else
    mkdir -p /lib/firmware || log_missing "cannot prepare /lib/firmware"
    dest=/vendorfw
    mkdir -p "$dest" || log_missing "cannot prepare $dest"
    ln -s /vendorfw "$vendor" || log_missing "cannot link $vendor"
fi
# Copy into the destination; never mount tmpfs over an existing vendor tree.
cp -r "$src"/. "$dest"/ || log_missing "cannot copy vendor firmware to $dest"

{
    printf 'dev=%s\n' "$dev"
    printf 'dest=%s\n' "$dest"
} >"$record"

if command -v udevadm >/dev/null 2>&1; then
    udevadm trigger --action=add --subsystem-match=hid --subsystem-match=input --subsystem-match=spi --subsystem-match=platform || true
    udevadm settle --timeout=10 || true
fi
