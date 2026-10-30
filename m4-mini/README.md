# M4 Mac mini kernel research candidate

This is an isolated J773g research lane for Omarchy Mac, not an installer or a supported release. The mini currently runs Gravity Linux and has not booted this Omarchy candidate. Do not enable it in an installer, release, channel, or update path on the strength of these sources.

The [locked kernel branch](https://github.com/techmore/linux-m1pro-touchid/tree/m4-mini-gravity) starts from Gravity's M4 source and applies the two existing [M-series kernel patches](https://github.com/techmore/ElementaryOS_MSeries-Kernel/tree/main/gravity): GPU notification-timeout recovery (0066) and a T8132 SMC reboot node (0067). The M4 mini has run the GPU fix as a module and booted with the reboot device tree; a successful reboot has not been demonstrated. The kernel source in this branch has not been built or booted.

The mini's installed `7.1.13-509.gravity.fc44.aarch64+16k` kernel and Gravity Mesa are the observed baseline. Gravity's packaging source pins kernel `dea38a96aa86679d5e24da16b799030fe07ad2f6`; the candidate instead uses the later development source `4fc326f6c25ccceb7515e2635c22e01fde5d3bac`. The running binary has not been reproduced from those sources in this work. Keep the matched bootloader, firmware, J773g device tree, kernel and Mesa together; this is not a claim that the newer source is a replacement for the working stack.

The J773g device tree enables the main DCP HDMI-A output and PHY 4. Its DCP driver expects firmware 26.6.2; its GPU has its own firmware and loader handoff requirements. Omarchy integration additionally needs compatible Arch ARM packaging, boot and initramfs handling, Mesa and a separately tested recovery path. An earlier comparison with a different Aurora M4 revision found 53 of 65 Gravity changes conflicted; this candidate does not merge those trees. The separate [Aurora baseline branch](https://github.com/techmore/linux-m1pro-touchid/tree/aurora-m4-integration) records the current Aurora source for future review.

To check a clean checkout of the exact candidate and an optional resolved, out-of-tree kernel configuration:

```sh
python3 scripts/m4-mini-source-check /path/to/kernel-checkout --config /path/to/build/.config
```

The checker requires the locked commit, clean source, four matching source hashes, Apple ARM64 and 16 KiB pages, Rust, the Apple display driver and the M4 GPU driver. Omitting `--config` checks source only. It neither builds nor installs anything, and passing is not proof of boot, HDMI, GPU operation or recovery.
