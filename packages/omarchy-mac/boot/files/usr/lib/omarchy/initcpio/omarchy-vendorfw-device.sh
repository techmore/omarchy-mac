#!/bin/sh
# Select the booted OS's ESP; do not use another installation's firmware.
# Arguments: /dev/disk, m1n1's chosen PARTUUID (possibly empty), image UUID.
omarchy_vendorfw_chosen_esp() (
    chosen_dir=$1
    asahi=
    gravity=
    for vendor in asahi gravity; do
        node="$chosen_dir/$vendor,efi-system-partition"
        if [ -e "$node" ]; then
            [ -r "$node" ] || exit 1
            value=$(tr -d '\000' <"$node" | tr 'A-F' 'a-f')
            [ -n "$value" ] || exit 1
            case "$value" in *[!0-9a-f-]*) exit 1 ;; esac
            case "$vendor" in asahi) asahi=$value ;; gravity) gravity=$value ;; esac
        fi
    done
    [ -z "$asahi" ] || [ -z "$gravity" ] || [ "$asahi" = "$gravity" ] || exit 1
    printf '%s\n' "${asahi:-$gravity}"
)

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
