# Desktop applications to revisit after M4 bring-up

**Status: planned; Signal has not been tested on the Omarchy M4 candidate.**

The owner identified a separate Messages app in their elementaryOS SDK that worked with Signal, and also wants the F5 speaking workflow. Identify and review both SDK applications after M4 kernel and HDMI bring-up. The Signal Desktop research below is related background, not confirmation that it is the requested Messages app.

The existing M-series F5 work is [local speech-to-text dictation](https://github.com/techmore/ElementaryOS_MSeries/blob/c6fd172c1abc1a31dbf9c70eef79c3bd7896cd8c/mseries/dictation/F5-ENGLISH-ACCEPTANCE.md), with additional voice reply work. Determine which SDK implementation the owner means and assess ARM64/M4 audio, shortcut, text insertion and model dependencies after the desktop is stable; prior app-specific acceptance gaps remain open.

## Related Signal Desktop background

## Existing work

The earlier [M-series handoff](https://github.com/techmore/ElementaryOS_MSeries/blob/c6fd172c1abc1a31dbf9c70eef79c3bd7896cd8c/mseries/OS9-HANDOFF.md) records a native ARM64 Signal Beta, launcher/icon repair and a system-accent experiment. It reports that an owner-approved migration from a Flatpak profile succeeded on that earlier machine, with sessions decrypting. That observation is not a test on the mini or this Omarchy candidate; the handoff also leaves visual and screenshot-drop checks open. The prior [Signal integration script](https://github.com/techmore/ElementaryOS_MSeries/blob/c6fd172c1abc1a31dbf9c70eef79c3bd7896cd8c/mseries/install-signal-integration.sh) and [screenshot shelf notes](https://github.com/techmore/ElementaryOS_MSeries/blob/c6fd172c1abc1a31dbf9c70eef79c3bd7896cd8c/mseries/screenshot-shelf/README.md) are references, not automatically portable installation steps.

Omarchy already offers Signal on demand and binds `Super+Shift+G` to its launcher. Its current script expects the `signal-desktop` package and `/usr/bin/signal-desktop`. [Arch Linux ARM lists an aarch64 package](https://archlinuxarm.org/packages/aarch64/signal-desktop); verify availability from the actual target repositories and test it before choosing a delivery path. The community-maintained [Flathub package](https://flathub.org/en/apps/org.signal.Signal) also lists aarch64. Signal's [support page](https://support.signal.org/hc/en-us/articles/360008216551-Installing-Signal) currently describes Linux support as x86_64 only, while the [Flathub manifest](https://github.com/flathub/org.signal.Signal/blob/master/org.signal.Signal.yaml) references a Signal-hosted ARM64 Debian package. Treat official support status as unresolved and confirm it for the selected release.

## Signal Desktop research criteria

- A supported, maintained ARM64 delivery path installs and updates reproducibly on the selected Omarchy image; confirm its source, package provenance, repository priority and architecture. It works through Omarchy's application launcher and Signal shortcut, without relying on the path of an unrelated packaging format.
- Link the desktop with the owner's Signal phone through the normal in-app flow. In a user-controlled test, send and receive messages and attachments, receive a desktop notification, restart the app and verify the linked session remains usable. Verify link handling, tray/window identity, and file-picker and screenshot drag-and-drop with the chosen Wayland/portal and packaging path. Voice/video calls are a separate test if desired.
- Preserve the appearance the owner liked: review the prior system-accent and icon work against Omarchy's theme and the selected Signal version. Verify updates and package integrity before considering modifications to packaged application files; do not assume an old `app.asar` patch remains safe or compatible.
- Existing accounts and message history are not moved automatically. If migration is desired, use a supported import or backup path chosen by the owner and preserve existing profiles. Do not run two copies against a copied live profile or put message contents and keys in test receipts.
- Record package source/version, aarch64 architecture, desktop/portal versions, target M4 build, and the observed results. Do not claim a working M4 messaging experience until it has been tested on the target.
