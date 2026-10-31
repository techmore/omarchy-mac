# WIP5 Mesa interface

The previous Gravity Mesa build targets Gravity's Asahi UAPI, not the pinned
Aurora WIP5 UAPI. The headers are materially different: Gravity assigns feature
bit 1 to `DRM_ASAHI_FEATURE_FRAGMENT_BARRIER`, while WIP5 assigns bit 1 to
`DRM_ASAHI_FEATURE_VM_STATUS` and places fragment barriers at bit 14. Reusing
the old Mesa package could therefore interpret a feature differently. Do not
reuse that package as the WIP5 Mesa build.

The pinned WIP5 source header has SHA-256
`24d700763678d78b5566e0a12293701f78ce9a50b77350d865888da87a2a0509`.
The old Gravity kernel and Mesa source header was
`eb9f39e87dfe448dc044f54ab2d11b7493bf1359faca8fb76ece5f3583469015`.
The current Omarchy `mesa-aurora` recipe selects `omacom/mesa` commit
`672657e05e6b382a0203975f7a26c46f9a674973`; its header hashes to
`ca351d5527a6c6649561f0a6d5f1b04ac183af7f18dbc228f8af836678175e45`.
It agrees with WIP5 on the two feature bits above but is not byte-identical to
the pinned WIP5 header. This makes it a source candidate to adapt, not evidence
that its existing binary is compatible with this kernel.

The candidate Mesa source refers to 21 `DRM_ASAHI_*` names present in its own
header but absent from WIP5's header. Simply replacing that header would leave
those references unresolved. A bounded Clang inventory found the 18 common
feature bits have the same numeric values, and 25 of 28 shared named structures
have identical field/type sequences; the other three include shorter command
tails or a `pad`/`flags` name change. These observations are not a complete ABI
or runtime compatibility review.

Until those differences are resolved, the local build gate conservatively
requires byte-identical headers. It can reject a compatible userspace header
that is a valid superset, so do not treat a rejection alone as proof of an ABI
failure. Re-check the eventual kernel header after the G16 port. For example:

```sh
scripts/m4-mini-check-wip5-mesa-uapi \
  --kernel-header /path/to/kernel/include/uapi/drm/asahi_drm.h \
  --mesa-header /path/to/mesa/include/drm-uapi/asahi_drm.h
```

Matching headers are a build prerequisite, not proof that the Mesa driver,
kernel backend, firmware or HDMI works on the mini. A WIP5-compatible Mesa
package has not yet been built.
