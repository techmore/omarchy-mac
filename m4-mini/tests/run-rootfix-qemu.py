#!/usr/bin/env python3
"""Run the M4 research kernel on generic ARM64 QEMU, without disks or networking."""
import argparse
import subprocess
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--kernel", required=True, type=Path)
parser.add_argument("--initramfs", required=True, type=Path)
parser.add_argument("--log", required=True, type=Path)
args = parser.parse_args()
if not args.kernel.is_file() or not args.initramfs.is_file() or args.log.exists():
    parser.error("kernel and initramfs must exist; log must be new")
command = ["qemu-system-aarch64", "-machine", "virt,accel=hvf", "-cpu", "host", "-m", "1024",
           "-smp", "2", "-nographic", "-monitor", "none", "-serial", "stdio", "-nic", "none",
           "-kernel", str(args.kernel), "-initrd", str(args.initramfs),
           "-append", "console=ttyAMA0 rdinit=/init panic=1", "-no-reboot"]
try:
    result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=120, check=False)
    output = result.stdout
    status = result.returncode
except subprocess.TimeoutExpired as error:
    output = error.stdout or b""
    status = 1
with args.log.open("xb") as log:
    log.write(output)
markers = [b"Linux version 7.1.13-omarchy-m4-r7-rootfix-ARCH ", b"M4_ROOTFIX_QEMU_OK"]
markers.extend(f"M4_MODULE_LOADED {name}".encode() for name in
               ("asahi_m4", "appledrm", "phy_apple_dptx", "nvme_apple", "dm_crypt", "dm_integrity"))
if status or b"M4_MODULE_FAILED" in output or any(marker not in output for marker in markers):
    raise SystemExit(f"Generic QEMU smoke test failed; inspect {args.log}")
print("Generic QEMU boot and module loading passed; no Apple hardware or HDMI was exercised.")
