# M4 Arch ARM boot transaction audit

This is local research, not a deployment procedure. The original R7 research
packages must not be installed on a Mac: the bootloader transaction and the
complete Omarchy initramfs are not yet safe. Nothing in these tests wrote to
the mini or a real ESP.

## Test environment

An isolated ARM64 Linux VM held a disposable root made from the generic
[Arch Linux ARM image](https://archlinuxarm.org/about/downloads), SHA-256
`42a4eeaa038994ffd31fa173256ef2f0ef511358eeb41b9ea1f8626391b9b319`.
Its detached signature verified against the published Arch Linux ARM key
`68B3537F39A313B3E574D06777193F152BDBE6A6`. This is a generic root, not an
Omarchy image or an Apple machine. The package transactions ran in private
mount and network namespaces with a fake ESP and a recording stub in place of
`update-m1n1`. The candidate packages were the earlier R7 artifacts, not a
new release: kernel SHA-256
`9d485130c9446873b1d413bd947b8607be4da9a2d4226c6ecfcc4b4a33696122`, loader
SHA-256 `368409870fe34921b7e4ba667f5af619616428195f286bf648b750e15c5f80c3`.

## m1n1 package hooks

Real pacman install and reinstall transactions called the recording stub for
both packages. The reason is the Asahi
[`95-m1n1-install.hook`](https://github.com/asahi-alarm/asahi-scripts/blob/20261023/libalpm/hooks/95-m1n1-install.hook):
its path triggers include both kernel DTBs and files below
`usr/lib/asahi-boot`, even when a package has no install script. The tested
Asahi source archive had SHA-256
`64c7e8d50f7ad37d58a64d1f1bc7c8848d7507093f40172e6dbce75c72b26ce4`.
An initial fixture omitted `/dev/stdin`; it was corrected and the transactions
were rerun without initramfs errors using the minimal M4 storage drop-in.

The Asahi Arch packaging inserts a default DTB selection based on the highest
versioned `*-ARCH` module directory. In a separate fixture using the real
updater and fake contents, a baseline kernel and the newer research kernel
made that default select the research release. The package's nested J773g
DTB did not match the default flat glob, so the attempted update failed and
the fake active image remained unchanged. Flattening that fake DTB alone made
the updater combine the baseline loader with the research DTB. This is a
simulation of the tested default, not an observation of the mini's updater or
configuration.

In the disposable root only, a temporary same-name `/dev/null` hook override
prevented the two tested transactions from invoking the recording stub; the
override was removed at the end. [ALPM's hook documentation](https://man.archlinux.org/man/alpm-hooks.5)
describes that override mechanism. This experiment is not a safe production
transaction: it does not cover other hooks, interrupted operations, future
package updates or a coordinated selection of the matching stage 2, device
tree, kernel and recovery chain. A persistent mask is not a solution.

The local Omarchy boot payload now includes pre-transaction guards for the
two named research packages and for the known m1n1-triggering paths when an M4
research package is already installed. With the guards already present in the
disposable root, real pacman refused simulated fresh installations, upgrades
and removals of both research packages, and refused another package touching
an Asahi bootloader path. Removal is blocked because a safe rollback for an
active research kernel is not yet established. A temporary database also
exercised an overlay package upgrade and removal with the research kernel
recorded as installed. None of
those blocked transactions reached the recording updater. A baseline fixture
with no research package and an unrelated `cpio` reinstall passed. The
fresh-install and temporary-database cases disabled dependency checks to reach
the hooks. The test is in `m4-mini/tests/archarm-transaction-guard.sh` and
needs the marked disposable fixture and pinned archives described above.

This is a brake, not an activation mechanism. ALPM reads pre-transaction hooks
before installing packages, so a guard installed in the same transaction as a
research package cannot protect that transaction. An uninstalled, overridden
or bypassed hook, a differently named package, an updater invoked outside these
known hooks, a nonstandard pacman database and interrupted operations still
need a coherent solution. Do not use these guards as evidence that the
packages can be installed. In particular, an Arch-side guard cannot stop an
updater run by the existing Gravity installation.

Asahi's [boot-process guide](https://github.com/AsahiLinux/docs/blob/main/docs/alt/boot-process-guide.md)
describes stage 1's fixed system-ESP selection and stage 2's shared
`m1n1/boot.bin`. Its [platform guidance](https://asahilinux.org/docs/platform/quirks/)
also says that, when multiple OSes use one UEFI partition for experimental or
recovery purposes, only one OS should own and update its system ESP. A
separate installation with its own Apple boot entry and system ESP is the
normal multi-OS model; a shared-ESP experiment instead needs a coordinated
single owner that neither distro can overwrite independently. Neither layout
has been designed or tested for this mini here, and no partition or stage-1
changes are authorized by this audit.

## Full Omarchy initramfs

The minimal transaction tests built default and fallback archives containing
Apple NVMe, NVMe core and Apple SART. They did not use the full Omarchy hook
set. Staging the actual Omarchy boot payload and Asahi hooks into the root
exposed additional failures with the original R7 kernel:

* `CONFIG_DM_CRYPT` and `CONFIG_DM_INTEGRITY` were disabled, although the
  Omarchy encryption and systemd encryption hooks request those modules.
* The generic root lacked `cpio` and `btrfs-progs`; the staged hooks require
  them. `cryptsetup` was also checked. The tested payload was copied into the
  root without installing its package. The inspected [Omarchy boot package
  recipe](https://github.com/omacom/omarchy-pkgs/blob/a92bcd62d9d9c76de6f005bb03ff487dec569fa0/pkgbuilds/omarchy-mac-boot/PKGBUILD)
  explicitly declares all three dependencies, so the missing generic-root
  tools are not evidence of an Omarchy package metadata defect.
* With the original `mkinitcpio 41-4`, the Asahi hook produced empty-module
  errors in this fixture. After installing signed `mkinitcpio 42.2-1`,
  `cpio 2.15-3` and `btrfs-progs 7.3-1`, the empty-module errors no longer
  appeared in the repeated default-image run; the missing `dm-crypt` and
  `dm-integrity` errors remained. This establishes the observed result, not
  the first fixed version or the underlying cause of the empty-module errors.

The root was partially updated for this test, not upgraded as a complete
Omarchy system. One dependency transaction returned success while its
post-transaction initramfs hook logged errors. Therefore an installer or
release test must check hook output and resulting artifacts, not just pacman's
exit status. The default image also warned that firmware for `dockchannel_hid`
may be missing; `modinfo` identifies `apple/tpmtfw-*.bin`. The generic root
has no Mac-specific firmware bundle, so actual device firmware availability
and input functionality remain unverified. In the separately rebuilt J773g
DTB (SHA-256 `734a8c22d441f3f00fc510289af273542dba9e59da06ab623b0816aa7950a1b3`),
both `/soc/fifo@394b14000` and its `input@0` node report `status = "disabled"`.
The driver's source says a firmware name is required only for some devices.
This explains why the generic module-metadata warning alone does not establish
that the mini needs this firmware. It does not account for bootloader fixups,
other Apple firmware requirements or external keyboard and pointing-device
behavior on hardware.

The separate `--rootfix` configuration enables the device-mapper encryption
drivers for a new research build. It does not make the old package installable
and does not address the m1n1 transaction or prove real boot, HDMI, firmware,
encryption or recovery on the mini.
