# J773g WIP5 loader drafts

This is a read-only snapshot of the mini agent's loader patches at `e97673b`.
`series.json` records source pins and patch digests. The m1n1 patches add the
mini ANS handoff and expose the framebuffer-preserving `NO_DISPLAY` build
option. The U-Boot patches add the opt-in mini storage import and allow the
mini to omit built-in keyboard metadata. The matching kernel marker is in the
kernel series; it requests the import and does not prove the source identity.

Prepare both source trees without installing them:

```sh
scripts/m4-mini-prepare-wip5-loaders \
  --m1n1-archive /path/to/m1n1-cda8314d.tar.gz \
  --uboot-archive /path/to/u-boot-cc47d3b7.tar.gz \
  --output /path/to/new-output-directory
```

The tool checks both archive hashes and all patch hashes, applies each series
in order, and writes an `INCOMPLETE` marker if preparation fails.

The mini agent reports that draft m1n1 stage one and stage two built with
`NO_DISPLAY`, with stage one also using `CHAINLOADING`. It also reports a
patched `apple_m1_defconfig` U-Boot build, including the keyboard fix. Those
artifacts are not release inputs: their source FDT, stage-one configuration,
ESP identity and boot path have not been verified together.

The running Gravity tree has `gravity,efi-system-partition`; the U-Boot import
expects `asahi,efi-system-partition`. The agent found that the pinned m1n1 can
set the Asahi property when its stage-one configuration explicitly selects a
target, while the factory-empty configuration does not. Preserve and verify
the selected ESP identity rather than relying on a first-partition fallback.
The Omarchy boot draft requires an independently captured and verified Gravity
recovery capsule before any activation.

The loader still needs the mini's native display and GPU handoff. These patches
are not installed or boot-qualified, and the saved Gravity and macOS/Recovery
paths must remain available throughout integration.
