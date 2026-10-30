#!/usr/bin/env python3
import hashlib
import json
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[2] / "scripts/m4-mini-recovery-capsule"
PARTUUID = "12345678-1234-1234-1234-123456789abc"


class RecoveryCapsuleTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.esp, self.boot, self.output = (self.root / name for name in ("esp", "boot", "capsule"))
        (self.esp / "m1n1").mkdir(parents=True)
        (self.esp / "EFI/BOOT").mkdir(parents=True)
        self.boot.mkdir()
        (self.esp / "m1n1/boot.bin").write_bytes(b"previous stage two")
        (self.esp / "EFI/BOOT/BOOTAA64.EFI").write_bytes(b"previous EFI loader")
        (self.boot / "vmlinuz").write_bytes(b"previous kernel")
        (self.boot / "initramfs.img").write_bytes(b"previous initramfs")
        self.sha = hashlib.sha256(b"previous stage two").hexdigest()

    def run_tool(self, *args):
        return subprocess.run(["python3", str(SCRIPT), *map(str, args)], capture_output=True, text=True)

    def create(self, *extra):
        return self.run_tool("create", "--esp-snapshot", self.esp, "--boot-snapshot", self.boot,
                             "--kernel", "vmlinuz", "--initramfs", "initramfs.img",
                             "--output", self.output, "--partuuid", PARTUUID,
                             "--stage2-sha256", self.sha, *extra)

    def verify(self, partuuid=PARTUUID, sha=None):
        return self.run_tool("verify", self.output, "--partuuid", partuuid, "--stage2-sha256", sha or self.sha)

    def test_create_verify_and_detect_corruption(self):
        result = self.create()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.verify().returncode, 0)
        saved = self.output / "recovery/m1n1/boot.omarchy-m4-recovery.bin"
        self.assertEqual(saved.read_bytes(), b"previous stage two")
        (self.output / "boot/initramfs.img").write_bytes(b"corrupt")
        self.assertNotEqual(self.verify().returncode, 0)
        self.assertEqual((self.boot / "initramfs.img").read_bytes(), b"previous initramfs")

    def test_identity_and_existing_output_refused(self):
        self.assertEqual(self.create().returncode, 0)
        self.assertNotEqual(self.create().returncode, 0)
        self.assertNotEqual(self.verify(partuuid="22345678-1234-1234-1234-123456789abc").returncode, 0)
        self.assertNotEqual(self.verify(sha="0" * 64).returncode, 0)
        self.assertNotEqual(self.run_tool("create", "--esp-snapshot", self.esp, "--boot-snapshot", self.boot,
                                       "--kernel", "vmlinuz", "--initramfs", "initramfs.img",
                                       "--output", self.root / "other", "--partuuid", PARTUUID,
                                       "--stage2-sha256", "0" * 64).returncode, 0)

    def test_links_traversal_and_missing_files_refused(self):
        (self.esp / "link").symlink_to("m1n1/boot.bin")
        self.assertNotEqual(self.create().returncode, 0)
        (self.esp / "link").unlink()
        self.assertNotEqual(self.create("--kernel", "../esp/m1n1/boot.bin").returncode, 0)
        (self.esp / "EFI/BOOT/BOOTAA64.EFI").unlink()
        self.assertNotEqual(self.create().returncode, 0)
        self.assertFalse(self.output.exists())

    def test_manifest_cannot_hide_extra_files(self):
        self.assertEqual(self.create().returncode, 0)
        (self.output / "esp/extra").write_text("extra")
        self.assertNotEqual(self.verify().returncode, 0)
        (self.output / "esp/extra").unlink()
        manifest = self.output / "manifest.json"
        record = json.loads(manifest.read_text())
        record["kernel"] = "../outside"
        manifest.write_text(json.dumps(record))
        self.assertNotEqual(self.verify().returncode, 0)


if __name__ == "__main__":
    unittest.main()
