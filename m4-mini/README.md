# M4 Mac mini kernel research candidate

This is an isolated J773g research lane for Omarchy Mac, not an installer or a supported release. The mini currently runs Gravity Linux and has not booted this Omarchy candidate. Do not enable it in an installer, release, channel, or update path on the strength of these sources.

The [locked kernel branch](https://github.com/techmore/linux-m1pro-touchid/tree/m4-mini-gravity) starts from Gravity's M4 source and applies the two existing [M-series kernel patches](https://github.com/techmore/ElementaryOS_MSeries-Kernel/tree/main/gravity): GPU notification-timeout recovery (0066) and a T8132 SMC reboot node (0067). It also carries four ARM64 helper exports from [Gravity's packaging source](https://github.com/GravityLinux/packages/tree/711c2a110416d28010ccdd118b83111776bff207), needed when appledrm is modular. The M4 mini has run the GPU fix as a module and booted with the reboot device tree; a successful reboot has not been demonstrated. The full kernel in this branch built locally but has not booted.

The mini's installed `7.1.13-509.gravity.fc44.aarch64+16k` kernel and Gravity Mesa are the observed baseline. Gravity's packaging source pins kernel `dea38a96aa86679d5e24da16b799030fe07ad2f6`; the candidate instead uses the later development source `4fc326f6c25ccceb7515e2635c22e01fde5d3bac`. The running binary has not been reproduced from those sources in this work. Keep the matched bootloader, firmware, J773g device tree, kernel and Mesa together; this is not a claim that the newer source is a replacement for the working stack.

The J773g device tree enables the main DCP HDMI-A output and PHY 4. Its DCP driver expects firmware 26.6.2; its GPU has its own firmware and loader handoff requirements. Omarchy integration additionally needs compatible Arch ARM packaging, boot and initramfs handling, Mesa and a separately tested recovery path. An earlier comparison with a different Aurora M4 revision found 53 of 65 Gravity changes conflicted; this candidate does not merge those trees. The separate [Aurora baseline branch](https://github.com/techmore/linux-m1pro-touchid/tree/aurora-m4-integration) records the current Aurora source for future review.

To check a clean checkout of the exact candidate and an optional resolved, out-of-tree kernel configuration:

```sh
python3 scripts/m4-mini-source-check /path/to/kernel-checkout --config /path/to/build/.config
```

The checker requires the locked commit, clean source, seven matching source hashes, Apple ARM64 and 16 KiB pages, Rust, the Apple display driver, the M4 GPU driver and the Apple DPTX PHY. Omitting `--config` checks source only. It neither builds nor installs anything, and passing is not proof of boot, HDMI, GPU operation or recovery.

The candidate J773g device tree compiled locally with Apple clang and dtc; its readback contains HDMI-A on PHY 4 and the SMC reboot node. Warnings, commands and the output hash are recorded in [the build receipt](dtb-build-2026-10-30.json). The resulting DTB has not been installed or booted.

For a repeatable source-only build on a case-sensitive ARM64 Linux environment, install the kernel build prerequisites including clang, GNU linker, Rust with matching `rust-src` and `rustfmt`, and `bindgen` (at least 0.71.1). Put the Rust tools on `PATH`, then run:

```sh
scripts/m4-mini-build --config-only /path/to/clean-kernel /path/to/new-build-dir
scripts/m4-mini-build /path/to/clean-kernel /path/to/another-new-build-dir 3
```

The first command resolves and checks the configuration only; the second builds the kernel image, modules and device trees. Each requires a new output directory outside the source checkout and does not install anything. The configuration fragments come from the existing [M-series research branch](https://github.com/techmore/ElementaryOS_MSeries/tree/c6fd172c1abc1a31dbf9c70eef79c3bd7896cd8c/mseries/m4-mini/gravity). A local ARM64 Linux VM reproduced the same resolved configuration as the initial build attempt; see [the configuration receipt](config-check-2026-10-30.json). A successful source build still requires matching graphics and boot components and hardware qualification.

The M4 GPU, Apple display driver and Apple DPTX PHY objects compiled in a local ARM64 Linux VM; hashes and limitations are recorded in [the object-build receipt](display-objects-2026-10-30.json). These relocatable objects are not finished kernel modules, and this does not establish display output.

The planned Apple and Logitech keyboard, mouse and trackpad pairing experience is tracked in [the input release goal](INPUT-RELEASE-GOAL.md). It is not yet implemented or qualified on the mini.

The [deeper upstream desktop audit](audits/2026-10-30-upstream-desktop.md) records the current Omarchy and Aurora branch differences, missing candidate configuration and a scheduler patch-placement conflict.

The [desktop applications follow-up](SIGNAL-RELEASE-GOAL.md) tracks the owner’s separate SDK Messages/Signal app and F5 speech workflow for review after M4 bring-up.

The original candidate completed a full local Image, modules and device-tree build; [the build receipt](kernel-build-2026-10-30.json) records hashes, warnings and configuration gaps. It booted a minimal initramfs under generic ARM64 QEMU, without emulating Apple hardware. This build does not include the reconciled scheduler/idle/Bluetooth work described in the audit and has not been installed or booted on the mini.

## R7 integration candidate

A separate [R7 research kernel branch](https://github.com/techmore/linux-m1pro-touchid/tree/m4-mini-aurora-r7-research) adds the M-series scheduler, M4 idle and BCM4388 Bluetooth adaptations to the baseline. The previously misplaced context-free insertions were reconciled before publication; all 18 published source files were checked against the locally compiled scratch version. This branch is not a qualified kernel or an installer input.

The `--r7` build option selects its separate source lock and the [M-series target fragment](https://github.com/techmore/ElementaryOS_MSeries/blob/c6fd172c1abc1a31dbf9c70eef79c3bd7896cd8c/mseries/m4-mini/gravity/elementary-target.config), including both Ethernet driver options, a built-in Apple watchdog and the live-media options. A local config-only run passed; [the receipt](r7-config-2026-10-30.json) identifies its exact configuration. For example:

```sh
scripts/m4-mini-build --config-only --r7 /path/to/r7-checkout /path/to/new-r7-build
```

Remove `--config-only` and use a different new output directory to attempt the full build. The R7 Image, modules and DTBs built locally; a minimal generic ARM64 QEMU boot also passed. All 1,597 modules were staged with dependency metadata in a local research archive. See [the local build receipt](r7-build-2026-10-30.json). This is not an Arch package. Apple firmware handoff, native boot, HDMI, networking and recovery remain untested.

The additional `--arch-research` option, used with `--r7`, sets the `-ARCH` release suffix required by Omarchy's boot-tool discovery; [the configuration receipt](r7-arch-config-2026-10-30.json) records its local check. An incremental build, generic QEMU boot, loading of five key modules without Apple hardware, and local research package inspection completed. A separate clean output build also completed with matching configuration and DTB and booted the generic QEMU fixture; see [the original package receipt](arch-package-build-2026-10-30.json). The packages were made on Ubuntu with dependency checks skipped and must not be installed on a real system until Arch packaging, boot, initramfs and recovery are qualified.

The later [Arch ARM transaction audit](audits/2026-10-30-archarm-boot-transactions.md) found that Asahi's pacman hook can rebuild stage 2 when either original research package is installed. It also found missing encryption drivers in the original kernel. A generic-root test initially lacked tools that the Omarchy boot package recipe explicitly declares. Do not install those research packages. New pre-transaction guards block the named packages and known m1n1-triggering updates with a research package installed, when the guards are already present. They cannot protect a transaction that first installs the guards alongside the packages, and they are not a safe activation path. The separate `--r7 --arch-research --rootfix` build option adds the encrypted-root drivers under a distinct kernel release; its [config-only receipt](r7-rootfix-config-2026-10-30.json) records the resolved options. It does not yet provide a safe package transaction or activation path.

## Boot and recovery integration under test

The local boot checker now recognizes the private research kernel and loader, requires the J773g mini, verifies the J773g device tree and private loader files, and checks Apple NVMe and device-mapper encryption drivers in both default and fallback initramfs images. For Limine it also inspects the initramfs embedded in both UKIs, checks the fallback entry and hash, and verifies that the files are on the system ESP. Limine requests a fallback UKI and retains an existing GRUB recovery entry and EFI file in this research lane. The firmware helper prefers the system ESP named by m1n1 over the image's fixed UUID. These changes passed isolated fixtures; real mkinitcpio also built minimal default and fallback test archives with the storage modules and rejected a missing driver. Those minimal archives are not bootable release images, and none of the checks is native boot qualification. [The integration receipt](boot-integration-2026-10-30.json) records the local test and package scope.

Stage 1 reads a fixed `m1n1/boot.bin`. Before the M4 Limine leaf writes boot files, it requires the mounted system ESP and a separately saved prior stage-two image with a matching SHA-256 record; the boot checker verifies the saved image too. That file is **manual recovery material**, not an automatic rollback or proof that the prior boot chain is usable. Recovery can also depend on the previous EFI loader, menu, kernel, initramfs, filesystem and firmware. No previous system has been captured here, and no restoration has been exercised.

`scripts/m4-mini-recovery-capsule` can copy regular files from already-captured local ESP and boot snapshots into a new, checksum-inventoried capsule, including the saved-stage-two files expected by the checker. It accepts an independently supplied ESP PARTUUID and stage-two hash and refuses links, special files, missing essential inputs, an existing output or mismatched bytes. `verify` rechecks the identity and every copied file. It does not preserve empty directories, ownership, permissions or extended attributes. This is an offline research aid, not a mount, installer or restore tool; checksums do not authenticate a snapshot or prove it boots. Capture and restore procedures still need to be tested on the actual machine before considering activation.

The kernel-selection helper can resolve an explicitly named installed kernel with `--select`, without changing any boot file; its automatic mode still refuses to choose when multiple Apple kernel packages are installed. Coexistence of the known-good and M4 research kernels therefore still needs an explicit, safe activation path that coordinates the chosen kernel with its m1n1 and device tree. The M4 Limine check accepts only a narrow default-menu layout and does not inspect one-shot EFI variables. The M4 check refuses to certify GRUB because it does not yet interpret GRUB's default or saved selection. Initramfs module checks establish presence, not a byte-for-byte comparison with the packaged modules. The packages and boot files have not been installed on the mini. The [KVM warning investigation](audits/2026-10-30-hyp-data-warning.md) traces the observed warning to an empty linker section in the examined build, without claiming hardware KVM validation.

## Wi-Fi DMA research

The separate [Broadcom DMA research pull request](https://github.com/techmore/linux-m1pro-touchid/pull/2) carries three upstream fixes together, with the includes adapted to Gravity's source. The modified object compiled in the local ARM64 VM and its DMA selection logic passed a host test; see [the receipt](wifi-dma-research-2026-10-30.json). It changes mapping behavior for other devices as well, and the mini's radio identity and hardware behavior still need verification. It is not part of the R7 build above.

## Matching Mesa source

The [M4 Mesa 6 research branch](https://github.com/techmore/mesa/tree/m4-mini-mesa6-research) carries the existing M-series graphics fixes on Gravity's pinned Mesa source. It retains the eight original upstream commits and their authorship. The eleven reviewed source files match the earlier Mesa 6 recipe; see [the Mesa source receipt](mesa-source-lock.json). A new local ARM64 build passed the AGX compiler groups, the existing regression fixtures and an llvmpipe software test; see [the build receipt](mesa-build-2026-10-30.json). This is not yet an Arch package or an M4 GPU/HDMI hardware result.

`scripts/m4-mini-run-mesa` is the existing M-series private-prefix launcher. When placed in a compatible Mesa prefix's `bin` directory, it selects that prefix for one command and adds Gravity's `ASAHI_MESA_DEBUG=nocompress` workaround without replacing other debug flags. It passed an isolated software test and temporary Vulkan manifest check; it does not configure the greeter or compositor automatically and has not been tested with the M4 GPU.

## Bootloader research build

The [Gravity bootloader fork](https://github.com/techmore/bootloader/tree/f02d4a52017915febb222539636b5b025a70407a) is separate from the installed bootloader. `scripts/m4-mini-build-bootloader` builds both stages from a fresh pinned checkout, with `NO_DISPLAY=1`, and cleans its generated build directory before switching stage settings. The earlier wrapper reused the first configuration; the corrected builder caught and avoids that failure. Two local runs produced matching bytes and passed stage-configuration checks; [the receipt](bootloader-build-2026-10-30.json) records the scope. Neither stage has been installed or tested on the M4.

Gravity's pinned U-Boot source also built twice locally with matching bytes using `scripts/m4-mini-build-uboot`, copied from the M-series project. A further GCC 15.2 build reproduced the earlier configuration exactly; only compiler identification fields differ from the GCC 13 configuration. Details are in [the U-Boot receipt](uboot-build-2026-10-30.json).

`scripts/m4-mini-assemble-boot-research` assembled the locally built bootloader stages, exact GCC 15 U-Boot and R7 J773g tree into a byte-checked research bundle. [The receipt](boot-bundle-2026-10-30.json) records readback and negative controls. It does not install anything, and the loader, firmware handoff, boot and recovery remain unqualified on the mini.
