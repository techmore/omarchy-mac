#!/usr/bin/sh
set -eu
. /usr/lib/omarchy/initcpio/omarchy-vendorfw-device.sh
esp=$(omarchy_vendorfw_chosen_esp /proc/device-tree/chosen) || exit 0
[ -n "$esp" ] || exit 0
mnt=/run/omarchy-vendorfw-esp
mkdir -p "$mnt"
mount -o ro "PARTUUID=$esp" "$mnt"
if [ -f "$mnt/vendorfw/firmware.cpio" ]; then
    (cd / && cpio -i <"$mnt/vendorfw/firmware.cpio")
fi
umount "$mnt"
[ -d /vendorfw ] || exit 0
dst=/sysroot/lib/firmware/vendor
mkdir -p "$dst"
mount -t tmpfs -o mode=0755 vendorfw "$dst"
cp -r /vendorfw/. "$dst"/
