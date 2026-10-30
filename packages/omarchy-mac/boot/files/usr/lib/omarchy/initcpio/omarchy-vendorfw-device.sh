#!/bin/sh
# Select the booted OS's ESP; do not use another installation's firmware.
# Arguments: /dev/disk, m1n1's chosen PARTUUID (possibly empty), image UUID.
omarchy_vendorfw_device() {
    disk_dir=$1
    partuuid=$2
    image_uuid=$3
    if [ -n "$partuuid" ]; then
        case "$partuuid" in *[!0-9a-fA-F-]*) return 1 ;; esac
        partuuid=$(printf '%s' "$partuuid" | tr 'A-F' 'a-f')
        candidate="$disk_dir/by-partuuid/$partuuid"
        [ -e "$candidate" ] || return 1
        printf '%s\n' "$candidate"
        return 0
    fi
    candidate="$disk_dir/by-uuid/$image_uuid"
    if [ -e "$candidate" ]; then
        printf '%s\n' "$candidate"
        return 0
    fi
    if command -v blkid >/dev/null 2>&1; then
        candidate=$(blkid -U "$image_uuid" 2>/dev/null) || return 1
        [ -n "$candidate" ] || return 1
        printf '%s\n' "$candidate"
        return 0
    fi
    return 1
}
