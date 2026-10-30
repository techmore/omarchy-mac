# R7 `.hyp.data` modpost warning

The local `7.1.13-omarchy-m4-r7-ARCH` build reported that the `vmlinux` `.hyp.data` section was unexpectedly non-allocatable. The following investigation is specific to the incremental R7 build and its recorded configuration (`9e0bd682fc678215daf71a3ab2c68616b2b75b2e9baa5f24b2ccd578dd3dec6f`); it is not a finding about every kernel configuration.

On the local ARM64 build VM, `readelf -SW arch/arm64/kvm/hyp/nvhe/kvm_nvhe.tmp.o` shows `.hyp.data` as a **zero-byte**, writable `PROGBITS` section with no alloc flag. Its `__hyp_section_.hyp.data` symbol also has size zero. The same zero-byte, non-allocatable section appears in `vmlinux.o`. The linker script creates that output section from `.data` and `.data.*`, while `modpost` flags a `PROGBITS` section without the alloc flag even when it is empty. Other KVM hypervisor sections in that object, including `.hyp.text`, `.hyp.rodata`, `.hyp.data..percpu` and `.hyp.data..ro_after_init`, have the alloc flag and nonzero sizes.

The final `vmlinux` has an allocatable, writable `.hyp.data` section of size `0x3d30`, but `nm -n vmlinux` places both `__hyp_data_start` and `__hyp_data_end` at `ffffc00083444000`. The logical hypervisor data range is empty; the bytes preceding it in the output section are alignment space. Together, these observations support the inference that the warning in this build comes from the empty linker placeholder. They do not prove KVM behavior on M4 hardware, and they do not rule out unrelated boot, memory or virtualization bugs.

Reproduction against the retained build tree:

```sh
readelf -SW arch/arm64/kvm/hyp/nvhe/kvm_nvhe.tmp.o
readelf -sW arch/arm64/kvm/hyp/nvhe/kvm_nvhe.tmp.o
readelf -SW vmlinux.o
readelf -SW vmlinux
nm -n vmlinux | grep -E '__hyp_data_(start|end)$'
```

The later encrypted-root research configuration (`b45421f50feb6a6114d0f1bb694ccc6fbb1763780e9a715291ae1cc584d949fa`)
emitted the same warning. Its linked hypervisor object and `vmlinux.o` again
have a zero-byte `.hyp.data` without the alloc flag, and its final `vmlinux`
has equal `__hyp_data_start` and `__hyp_data_end` addresses. Their SHA-256
hashes, in that order, are `33c78e1898fbd88e1cc816000466fa0dd4324b33e98f58d2d687be2da06c8b03`,
`943387ca3101e0bb476f21f8f51de68e88f255dd5097d7d952be8379499733c2`, and
`e699b7c609ffd01720e932b376a37d4c53b63363566b478c6acbef6d062b85f6`.
This supports the same empty-placeholder explanation for that build; it is
not a hardware KVM test or proof that all other boot warnings are benign.

The inspected `kvm_nvhe.tmp.o`, `vmlinux.o`, and `vmlinux` SHA-256 hashes were respectively `33449aa7ce8d695d52f5f2ebcd23b0b9a7292bfd7d918ec60e89023faa4c5f1a`, `9131b3d783cec88b76b4530f6d2a02db884bc249825310915285d1d1f00e3f72`, and `c6ae725a228f340f34e5103a07dee5f49d8ed857f5cf7863465499de5b6277e1`. The candidate booted a generic QEMU ARM64 fixture without Apple hardware. No warning suppression or kernel linker change was made; the M4 boot, display and KVM remain untested.
