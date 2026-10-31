# M4 mini boot integration for Aurora WIP5

This is an uninstalled draft for the J773g Mac mini. Its kernel base is revision
7 of the M-series `unified72` series: Aurora commit
`2f725546d6ac6afe0bd5abfa1a844971519f0076` and that series' five ordered
patches. The kernel port maintained on the Gravity machine adds J773g changes
on top of this base. The older Gravity 7.1 research image is a separate,
obsolete candidate and must not be used as the WIP5 kernel or loader.

The draft boot-package contract uses these distinct names:

- Kernel package and module `pkgbase`: `linux-omarchy-m4-wip5`.
- Loader package: `m1n1-omarchy-m4-wip5`, with its own m1n1 and U-Boot under
  `/usr/lib/asahi-boot/omarchy-m4-wip5/`.
- Kernel-owned board tree: `apple/t8132-j773g.dtb`, selected explicitly from
  that kernel's module directory rather than the newest version-sorted tree.
- Separate default and fallback initramfs images, as specified by the preset
  beside this document.

The actual kernel release is supplied by the WIP5 build; example release names
in fixtures are not a built artifact. Runtime selection requires both J773g
compatibility and the running module directory's exact package identity. The
initramfs draft requests the WIP5 `asahi` module, not Gravity's `asahi_m4`,
alongside the boot-critical storage, mailbox, DART and display modules. Missing
required modules fail the initramfs build. The pinned WIP5 base does not yet
include the M4 G16 backend: integrating it is a prerequisite, and the boot check
requires a package-owned resolved config with `CONFIG_DRM_ASAHI_G16=y`. The
module and config alone do not establish that the mini's HDMI or GPU works.

The mini-side storage draft requires a matching J773g-aware m1n1 handoff and a
matching U-Boot path. The loader and the rest of the WIP5 J773g stack are not
yet qualified. An actual installation additionally requires a separately
verified Gravity recovery capsule and an isolated boot entry, so the existing
Gravity and macOS/Recovery paths remain available. No WIP5 stage-one,
stage-two, kernel or image hashes have been authorized by this draft. In
particular, do not reuse the old Gravity image adapter's pinned hashes.

To prepare the boot source without installing it:

```sh
scripts/m4-mini-prepare-upstream-boot \
  --checkout /path/to/omarchy-mac-pkgs-at-061be4d \
  --output /path/to/new-output-directory
```

The script records the patch digest. Its result is source for integration, not
a bootable or hardware-tested image.
