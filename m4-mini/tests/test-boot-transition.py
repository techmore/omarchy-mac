#!/usr/bin/env python3
import contextlib
import gzip
import hashlib
import io
import json
from importlib.machinery import SourceFileLoader
from pathlib import Path
import runpy
import sys
import tarfile
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
transition = SourceFileLoader('m4_transition', str(ROOT / 'scripts/m4-mini-prepare-boot-transition')).load_module()
recovery = runpy.run_path(str(ROOT / 'scripts/m4-mini-recovery-capsule'))
PARTUUID = '12345678-1234-1234-1234-123456789abc'


def sha(data):
    return hashlib.sha256(data).hexdigest()


def archive(path, entries):
    with tarfile.open(path, 'w:gz') as output:
        for name, data in entries.items():
            info = tarfile.TarInfo(name)
            info.size = len(data)
            output.addfile(info, io.BytesIO(data))


class TransitionTest(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.bundle = self.root / 'bundle'
        (self.bundle / 'kernel').mkdir(parents=True)
        (self.bundle / 'bootloader').mkdir()
        kernel = self.bundle / 'kernel/linux-omarchy-m4-research-7.1.13.r7.rootfix-1-aarch64.pkg.tar.gz'
        loader = self.bundle / 'bootloader/m1n1-omarchy-m4-research-1.6.1.r1-1-aarch64.pkg.tar.gz'
        dtb, stage2, uboot = b'J773g test tree', b'new stage two', b'new uboot'
        archive(kernel, {f'usr/lib/modules/{transition.KVER}/dtbs/apple/t8132-j773g.dtb': dtb})
        archive(loader, {'usr/lib/asahi-boot/omarchy-m4-research/m1n1.bin': stage2,
                         'usr/lib/asahi-boot/omarchy-m4-research/u-boot-nodtb.bin': uboot})
        self.sample = stage2 + dtb + gzip.compress(uboot, mtime=0)
        (self.bundle / 'bootloader/boot-sample.bin').write_bytes(self.sample)
        transition.EXPECTED = {'kernel': sha(kernel.read_bytes()), 'loader': sha(loader.read_bytes()),
                               'boot': sha(self.sample), 'dtb': sha(dtb)}
        esp, boot = self.root / 'esp', self.root / 'boot'
        (esp / 'm1n1').mkdir(parents=True)
        (esp / 'EFI/BOOT').mkdir(parents=True)
        boot.mkdir()
        (esp / 'm1n1/boot.bin').write_bytes(b'previous stage two')
        (esp / 'EFI/BOOT/BOOTAA64.EFI').write_bytes(b'previous EFI')
        (boot / 'vmlinuz').write_bytes(b'previous kernel')
        (boot / 'initramfs').write_bytes(b'previous initramfs')
        self.prior_sha = sha(b'previous stage two')
        self.capsule = self.root / 'capsule'
        args = type('Args', (), {'esp_snapshot': esp, 'boot_snapshot': boot, 'kernel': 'vmlinuz',
                                 'initramfs': 'initramfs', 'output': self.capsule,
                                 'partuuid': PARTUUID, 'stage2_sha256': self.prior_sha})()
        with contextlib.redirect_stdout(io.StringIO()):
            recovery['create'](args)
        self.config = self.root / 'm1n1.conf'
        self.config.write_text(f'chosen.asahi,efi-system-partition={PARTUUID}\ndisplay=2560x1600\n')

    def run_transition(self, output):
        argv = ['transition', '--bundle', str(self.bundle), '--capsule', str(self.capsule),
                '--partuuid', PARTUUID, '--prior-stage2-sha256', self.prior_sha,
                '--m1n1-config', str(self.config), '--output', str(output)]
        with patch.object(sys, 'argv', argv), contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            return transition.main()

    def test_verified_proposal_and_mismatched_esp_refusal(self):
        output = self.root / 'proposal'
        self.assertEqual(self.run_transition(output), 0)
        self.assertEqual((output / 'stage2-proposal.bin').read_bytes(), self.sample + self.config.read_bytes())
        receipt = json.loads((output / 'proposal.json').read_text())
        self.assertFalse(receipt['ready_for_activation'])
        self.assertFalse(receipt['recovery_tested'])
        self.config.write_text('chosen.asahi,efi-system-partition=22345678-1234-1234-1234-123456789abc\n')
        refused = self.root / 'refused'
        self.assertEqual(self.run_transition(refused), 1)
        self.assertFalse(refused.exists())
        (self.capsule / 'boot/initramfs').write_bytes(b'corrupted')
        self.config.write_text('display=2560x1600\n')
        self.assertEqual(self.run_transition(refused), 1)
        self.assertFalse(refused.exists())


if __name__ == '__main__':
    unittest.main()
