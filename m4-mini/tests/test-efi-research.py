#!/usr/bin/env python3
import hashlib
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GRAVITY = '12345678-1234-1234-1234-123456789abc'
TARGET = '22345678-1234-1234-1234-123456789abc'


class EfiPreflightTest(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        esp = self.root / 'gravity-esp'
        boot = self.root / 'gravity-boot'
        for path, value in ((esp / 'm1n1/boot.bin', b'gravity stage two'),
                            (esp / 'EFI/BOOT/BOOTAA64.EFI', b'gravity EFI'),
                            (boot / 'vmlinuz', b'kernel'), (boot / 'initramfs', b'initramfs')):
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(value)
        self.gravity_sha = hashlib.sha256(b'gravity stage two').hexdigest()
        self.capsule = self.root / 'capsule'
        subprocess.run([str(ROOT / 'scripts/m4-mini-recovery-capsule'), 'create',
                        '--esp-snapshot', str(esp), '--boot-snapshot', str(boot),
                        '--kernel', 'vmlinuz', '--initramfs', 'initramfs', '--output', str(self.capsule),
                        '--partuuid', GRAVITY, '--stage2-sha256', self.gravity_sha], check=True, capture_output=True)
        self.target = self.root / 'target-esp'
        for path in (self.target / 'm1n1/boot.bin', self.target / 'EFI/BOOT/BOOTAA64.EFI'):
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b'target bytes')
        self.bundle = self.root / 'bundle'
        self.bundle.mkdir()
        self.target_sha = hashlib.sha256(b'target bytes').hexdigest()

    def run_preflight(self, target=TARGET, target_sha=None):
        output = self.root / 'output'
        args = [str(ROOT / 'scripts/m4-mini-prepare-efi-research'), '--bundle', str(self.bundle),
                '--capsule', str(self.capsule), '--target-esp-snapshot', str(self.target),
                '--m1n1-config', str(self.root / 'm1n1.conf'), '--cmdline', str(self.root / 'cmdline'),
                '--os-release', str(self.root / 'os-release'), '--initramfs-default', str(self.root / 'default'),
                '--initramfs-fallback', str(self.root / 'fallback'), '--output', str(output),
                '--recovery-esp-partuuid', GRAVITY, '--recovery-stage2-sha256', self.gravity_sha,
                '--target-esp-partuuid', target, '--target-stage2-sha256', target_sha or self.target_sha]
        result = subprocess.run(args, text=True, capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(output.exists())
        return result.stderr

    def test_shared_esp_is_rejected(self):
        self.assertIn('different system ESP', self.run_preflight(target=GRAVITY))

    def test_missing_firmware_and_mismatched_stage_two_are_rejected(self):
        self.assertIn('vendorfw/firmware.cpio', self.run_preflight())
        firmware = self.target / 'vendorfw/firmware.cpio'
        firmware.parent.mkdir()
        firmware.write_bytes(b'firmware')
        self.assertIn('stage-two hash', self.run_preflight(target_sha='0' * 64))


if __name__ == '__main__':
    unittest.main()
