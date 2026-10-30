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

The `--r7` build option selects its separate source lock and the [M-series target fragment](https://github.com/techmore/ElementaryOS_MSeries/blob/c6fd172c1abc1a31dbf9c70eef79c3bd7896cd8c/mseries/m4-mini/gravity/elementary-target.config), including both Ethernet driver options, a built-in Apple watchdog and the live-media options. Its lock also pins the Asahi GPU UAPI shared with the Mesa source. A local config-only run passed; [the receipt](r7-config-2026-10-30.json) identifies its exact configuration. For example:

```sh
scripts/m4-mini-build --config-only --r7 /path/to/r7-checkout /path/to/new-r7-build
```

Remove `--config-only` and use a different new output directory to attempt the full build. The R7 Image, modules and DTBs built locally; a minimal generic ARM64 QEMU boot also passed. All 1,597 modules were staged with dependency metadata in a local research archive. See [the local build receipt](r7-build-2026-10-30.json). This is not an Arch package. Apple firmware handoff, native boot, HDMI, networking and recovery remain untested.

The additional `--arch-research` option, used with `--r7`, sets the `-ARCH` release suffix required by Omarchy's boot-tool discovery; [the configuration receipt](r7-arch-config-2026-10-30.json) records its local check. An incremental build, generic QEMU boot, loading of five key modules without Apple hardware, and local research package inspection completed. A separate clean output build also completed with matching configuration and DTB and booted the generic QEMU fixture; see [the original package receipt](arch-package-build-2026-10-30.json). The packages were made on Ubuntu with dependency checks skipped and must not be installed on a real system until Arch packaging, boot, initramfs and recovery are qualified.

The later [Arch ARM transaction audit](audits/2026-10-30-archarm-boot-transactions.md) found that Asahi's pacman hook can rebuild stage 2 when either original research package is installed. It also found missing encryption drivers in the original kernel. A generic-root test initially lacked tools that the Omarchy boot package recipe explicitly declares. Do not install those research packages. New pre-transaction guards block installation, upgrade or removal of the named packages and known m1n1-triggering updates with a research package installed, when the guards are already present. They cannot protect a transaction that first installs the guards alongside the packages, and they are not a safe activation or recovery path. The separate `--r7 --arch-research --rootfix` build option adds the encrypted-root drivers under a distinct kernel release; its [config-only receipt](r7-rootfix-config-2026-10-30.json) records the resolved options. It does not yet provide a safe package transaction or activation path.

The rootfix kernel, its 1,603 modules and J773g DTB have now built and been staged; a generic QEMU boot loaded its display, NVMe and encryption modules, and the full Omarchy/Asahi hooks built default and fallback initramfs images in a disposable Arch ARM root. A local, unsigned research kernel package was also built. [The build receipt](r7-rootfix-build-2026-10-30.json) records the artifacts, warnings and test boundaries. This is still not a qualified install or a hardware HDMI result.

`scripts/m4-mini-stage-arch-research --rootfix` and `scripts/m4-mini-package-arch-research --rootfix` select this distinct release and configuration. The package records the Omarchy boot payload and the tested mkinitcpio version as dependencies, but its transaction still triggers Asahi's updater unless the separately installed guards block it. The package is research material, not an installation path.

## Boot and recovery integration under test

The local boot checker now recognizes the private research kernel and loader, requires the J773g mini, verifies the J773g device tree and private loader files, and checks Apple NVMe, device-mapper encryption and M4 display drivers and their modular dependency closure in both default and fallback initramfs images. For Limine it also inspects the initramfs embedded in both UKIs, checks the fallback entry and hash, and verifies that the files are on the system ESP. Limine requests a fallback UKI and retains an existing GRUB recovery entry and EFI file in this research lane. The firmware helper prefers the system ESP named by m1n1 over the image's fixed UUID. The earlier default initramfs lacked the M4 display modules, so the M4 config now explicitly includes `appledrm`, `asahi_m4` and `phy-apple-dptx`. Real mkinitcpio rebuilt both images with those modules and their dependency closures in a disposable Arch ARM root; see [the display initramfs receipt](display-initramfs-2026-10-30.json). That does not establish early console, firmware handoff or HDMI on the mini. [The integration receipt](boot-integration-2026-10-30.json) records the earlier test and package scope.

Stage 1 reads a fixed `m1n1/boot.bin`. Before the M4 Limine leaf writes boot files, it requires the mounted system ESP and a separately saved prior stage-two image with a matching SHA-256 record; the boot checker verifies the saved image too. That file is **manual recovery material**, not an automatic rollback or proof that the prior boot chain is usable. Recovery can also depend on the previous EFI loader, menu, kernel, initramfs, filesystem and firmware. No previous system has been captured here, and no restoration has been exercised.

`scripts/m4-mini-recovery-capsule` can copy regular files from already-captured local ESP and boot snapshots into a new, checksum-inventoried capsule, including the saved-stage-two files expected by the checker. It accepts an independently supplied ESP PARTUUID and stage-two hash and refuses links, special files, missing essential inputs, an existing output or mismatched bytes. `verify` rechecks the identity and every copied file. It does not preserve empty directories, ownership, permissions or extended attributes. This is an offline research aid, not a mount, installer or restore tool; checksums do not authenticate a snapshot or prove it boots. Capture and restore procedures still need to be tested on the actual machine before considering activation.

`scripts/m4-mini-prepare-boot-transition` connects that Gravity recovery capsule to the locked M4 kernel and loader. It requires the captured Gravity ESP PARTUUID, the prior stage-two hash, a different proposed Omarchy system ESP PARTUUID, and m1n1 configuration that explicitly names that target. It rejects a shared ESP, mismatched identities and unsupported or duplicate options. Different identifiers do not prove that a separate Apple boot entry exists or that its stage one is paired with the target ESP. The proposal is offline review material: its gzip bytes can differ from the target updater, the capsule is not proof of a working restore, and it must not be written to an ESP.

`scripts/m4-mini-prepare-efi-research` combines that transition with a snapshot of the separately provisioned target ESP, its independently supplied stage-two hash, target firmware, a target kernel command line, and default and fallback initramfs images. On an Arch ARM staging host with `mkinitcpio`, `systemd-ukify` and Limine installed, it checks the kernel package and module dependency closure, builds and inspects both AArch64 UKIs, writes matching Limine entries, and makes a checksummed copy of the prior target ESP files. It also provides the locked raw stage-one binary and intended target ESP settings for an Asahi installer handoff. It creates only a new local directory; it neither provisions Apple's boot entry nor writes an ESP. A [local synthetic fixture receipt](efi-fixture-2026-10-30.json) records the completed assembly. Its UUIDs and firmware are placeholders, and the resulting example must not be installed.

For a real target, use the independently captured Gravity capsule and a snapshot of the **separate** Omarchy system ESP created by the Asahi installer. The target snapshot must contain `m1n1/boot.bin`, `EFI/BOOT/BOOTAA64.EFI` and `vendorfw/firmware.cpio`; the command line and initramfs must come from the intended Omarchy installation. Set the following variables to those captured paths and identities before running on the Linux staging host:

```sh
scripts/m4-mini-prepare-efi-research \
  --bundle "$M4_BUNDLE" --capsule "$GRAVITY_CAPSULE" \
  --recovery-esp-partuuid "$GRAVITY_ESP_PARTUUID" --recovery-stage2-sha256 "$GRAVITY_STAGE2_SHA256" \
  --target-esp-partuuid "$OMARCHY_ESP_PARTUUID" --target-stage2-sha256 "$OMARCHY_PREVIOUS_STAGE2_SHA256" \
  --target-esp-snapshot "$OMARCHY_ESP_SNAPSHOT" --m1n1-config "$OMARCHY_M1N1_CONFIG" \
  --cmdline "$OMARCHY_CMDLINE" --os-release "$OMARCHY_OS_RELEASE" \
  --initramfs-default "$OMARCHY_INITRAMFS" --initramfs-fallback "$OMARCHY_FALLBACK_INITRAMFS" \
  --output "$NEW_STAGING_DIRECTORY"
```

The resulting `stage1-handoff` is input for review and installer integration, not a signed Apple boot entry. The `esp-proposal` and `target-esp-recovery` directories are offline files; the existing Gravity entry remains the recovery route until target restoration has been rehearsed. Machine-provided vendor firmware must stay local.

The kernel-selection helper can resolve an explicitly named installed kernel with `--select`, without changing any boot file; its automatic mode still refuses to choose when multiple Apple kernel packages are installed. Coexistence of the known-good and M4 research kernels therefore still needs an explicit, safe activation path that coordinates the chosen kernel with its m1n1 and device tree. The M4 Limine check accepts only a narrow default-menu layout and does not inspect one-shot EFI variables. The M4 check refuses to certify GRUB because it does not yet interpret GRUB's default or saved selection. Initramfs module checks establish presence, not a byte-for-byte comparison with the packaged modules. The packages and boot files have not been installed on the mini. The [KVM warning investigation](audits/2026-10-30-hyp-data-warning.md) traces the observed warning to an empty linker section in the examined build, without claiming hardware KVM validation.

## Wi-Fi DMA research

The separate [Broadcom DMA research pull request](https://github.com/techmore/linux-m1pro-touchid/pull/2) carries three upstream fixes together, with the includes adapted to Gravity's source. The modified object compiled in the local ARM64 VM and its DMA selection logic passed a host test; see [the receipt](wifi-dma-research-2026-10-30.json). It changes mapping behavior for other devices as well, and the mini's radio identity and hardware behavior still need verification. It is not part of the R7 build above.

## Matching Mesa source

The [M4 Mesa 6 research branch](https://github.com/techmore/mesa/tree/m4-mini-mesa6-research) carries the existing M-series graphics fixes on Gravity's pinned Mesa source. It retains the eight original upstream commits and their authorship. The eleven reviewed source files match the earlier Mesa 6 recipe; see [the Mesa source receipt](mesa-source-lock.json). A local Ubuntu ARM64 build passed compiler and software checks; see [the build receipt](mesa-build-2026-10-30.json). An unsigned private Mesa package has also been built in an isolated Arch ARM staging root; see [the package receipt](mesa-arch-package-2026-10-30.json). Neither build is an M4 GPU or HDMI hardware result.

`scripts/m4-mini-run-mesa` is the existing M-series private-prefix launcher. When placed in a compatible Mesa prefix's `bin` directory, it selects that prefix for one command and adds Gravity's `ASAHI_MESA_DEBUG=nocompress` workaround without replacing other debug flags. It passed an isolated software test and temporary Vulkan manifest check; it does not configure the greeter or compositor automatically and has not been tested with the M4 GPU.

`scripts/m4-mini-prepare-mesa-arch-research` prepares a private-prefix Arch package recipe from the locked Mesa source archive. The recipe includes the launcher, a UWSM loader and a private environment fragment that requires an explicit research opt-in, the matching research kernel and J773g identification. Without those conditions the loader leaves the session environment unchanged. The built package pins the LLVM, display-info and sensor library ABIs it needs; a different Arch package set may require a rebuild. The package and session integration have not been tested on the target.

`scripts/m4-mini-assemble-omarchy-research` gathers the corrected kernel package, private loader package, an Omarchy Mac boot source snapshot, the Mesa recipe, the offline recovery and EFI preparation tools, and a sample stage-two image into one checksummed bundle. `--stage1` includes the matching unsigned stage-one binary required by the EFI preparation tool; `--mesa-package` adds the locked Arch ARM Mesa package and verifies its recipe, libraries, session files and driver manifests. With `--initramfs-dir`, it includes the rebuilt default and fallback fixture images and their receipt; these are not configured for the target system. It checks the locked kernel Asahi GPU UAPI against the Mesa archive header and checks that the packaged J773g tree and loader bytes match the sample. The sample has no target-specific configuration, and the bundle is not an installer or a safe recovery mechanism.

`scripts/m4-mini-prepare-staged-package` prepares an Arch package that stores the locked kernel, loader and Mesa packages as nested files under `/usr/share/omarchy-m4-research/bundle`, alongside unsigned stage one and the offline recovery tools. It does not install those nested packages or activate a boot chain. In a disposable Arch ARM fresh-install transaction, the current staging release did not trigger the recorded Asahi m1n1 updater. See [the staging receipt](staged-package-2026-10-30.json). That limited check does not protect against future hooks, Gravity's own updater, or an unsafe activation of the nested packages.

On a Linux staging host, `scripts/m4-mini-stage-omarchy-overlay` can unpack that locked bundle's kernel and loader together with the Omarchy boot payload into a new, checksummed image overlay. `--with-mesa` adds the locked private Mesa files and opt-in session loader; [the local Mesa overlay receipt](omarchy-mesa-overlay-2026-10-30.json) identifies that artifact. Neither overlay creates a package database, installs Mesa's runtime dependencies, runs pacman hooks or makes an image bootable, and neither may be applied to an installed system.

## Bootloader research build

The [Gravity bootloader fork](https://github.com/techmore/bootloader/tree/f02d4a52017915febb222539636b5b025a70407a) is separate from the installed bootloader. `scripts/m4-mini-build-bootloader` builds both stages from a fresh pinned checkout, with `NO_DISPLAY=1`, and cleans its generated build directory before switching stage settings. The earlier wrapper reused the first configuration; the corrected builder caught and avoids that failure. Two local runs produced matching bytes and passed stage-configuration checks; [the receipt](bootloader-build-2026-10-30.json) records the scope. Neither stage has been installed or tested on the M4.

Gravity's pinned U-Boot source also built twice locally with matching bytes using `scripts/m4-mini-build-uboot`, copied from the M-series project. A further GCC 15.2 build reproduced the earlier configuration exactly; only compiler identification fields differ from the GCC 13 configuration. Details are in [the U-Boot receipt](uboot-build-2026-10-30.json).

`scripts/m4-mini-assemble-boot-research` assembled the locally built bootloader stages, exact GCC 15 U-Boot and R7 J773g tree into a byte-checked research bundle. [The receipt](boot-bundle-2026-10-30.json) records readback and negative controls. It does not install anything, and the loader, firmware handoff, boot and recovery remain unqualified on the mini.
