# M4 Mac mini kernel research candidate

This is an isolated J773g research lane for Omarchy Mac, not an installer or a supported release. The mini currently runs Gravity Linux and has not booted this Omarchy candidate. Do not enable it in an installer, release, channel, or update path on the strength of these sources.

The [locked kernel branch](https://github.com/techmore/linux-m1pro-touchid/tree/m4-mini-gravity) starts from Gravity's M4 source and applies the two existing [M-series kernel patches](https://github.com/techmore/ElementaryOS_MSeries-Kernel/tree/main/gravity): GPU notification-timeout recovery (0066) and a T8132 SMC reboot node (0067). It also carries four ARM64 helper exports from [Gravity's packaging source](https://github.com/GravityLinux/packages/tree/711c2a110416d28010ccdd118b83111776bff207), needed when appledrm is modular. The M4 mini has run the GPU fix as a module and booted with the reboot device tree; a successful reboot has not been demonstrated. The full kernel in this branch has not been built or booted.

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
