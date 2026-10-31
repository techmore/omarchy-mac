# WIP5 kernel source draft

`series.json` records the exact source archive and patch order. The first five
patches are revision 7 of the M-series Aurora WIP5 profile. The next five are a
read-only snapshot of the mini agent's J773g kernel patches at `9002d19`;
their storage and rear USB nodes remain disabled pending a matched loader
handoff. The next seven are prerequisites from Aurora's M4 Air graphics
and basic bring-up series, retaining their original authorship. The CPU
frequency and PMP graphics patches are adapted to WIP5's newer structures;
their CPU-frequency, PMP display and PMP report C objects compiled in the
isolated local build. The Rust changes have not been built. The telemetry and
thermal policy include J713-only checks, and the adapted CPU hotplug policy
remains scoped to J713. These are draft prerequisites, not qualified thermal
policy for the mini.

Patch `0008` adds the J773g built-in HDMI controller, mailbox, DART, PHY,
GPIO and display wiring adapted from Gravity `4fc326f6c25ccceb7515e2635c22e01fde5d3bac`.
The new display nodes are disabled, and loader aliases are intentionally absent
until the mini's M4 display handoff is integrated. The resulting J773g DTB
compiled in the local ARM64 VM with defconfig, SHA-256
`91949c01fb67eb8babfdc9609f362432a015b71e0d30e9ba3bb93e1a8e57f369`;
decompilation confirmed the controller and supporting nodes remain disabled.
This is not a native HDMI test or a display-ready device tree.

Patch `0009` adds the Air's GPU thermal-policy integration, still gated to
J713. The following Air display-DART patch conflicts extensively with WIP5's
newer DART implementation and has not been applied; it needs a semantic port.

The mini agent's separate m1n1 patches are not kernel patches and are not
applied here. The remaining Air graphics series relies on the Air basic
bring-up branch and conflicts with newer WIP5 power-management code. Its G16
backend, DCP driver, enabled mini HDMI path, matching m1n1/U-Boot handoff and Mesa
UAPI still need integration. J713 board-specific checks do not qualify J773g.

Prepare the source with the archive named by the WIP5 manifest:

```sh
scripts/m4-mini-prepare-wip5-kernel \
  --source-archive /path/to/linux-aurora-2f725546d6ac6afe0bd5abfa1a844971519f0076.tar.gz \
  --output /path/to/new-output-directory
```

The tool verifies the source and every patch digest, refuses an existing output,
and leaves an `INCOMPLETE` marker on failure. It does not build or install a
kernel. A successfully prepared tree is not an M4 boot or HDMI qualification.
