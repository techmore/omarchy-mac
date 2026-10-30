#!/usr/bin/env python3
import hashlib
import json
from importlib.machinery import SourceFileLoader
import pathlib
import subprocess
import tempfile
import unittest

HERE = pathlib.Path(__file__).resolve().parent
checker = SourceFileLoader('m4_source_check', str(HERE.parent / 'scripts/m4-mini-source-check')).load_module()


class SourceCheck(unittest.TestCase):
    def test_r7_kernel_and_mesa_lock_the_same_gpu_uapi(self):
        mesa = json.loads((HERE / 'mesa-source-lock.json').read_text())
        for name in ('source-lock-r7.json', 'source-lock-r7-rootfix.json'):
            kernel = json.loads((HERE / name).read_text())
            self.assertEqual(kernel['file_sha256']['include/uapi/drm/asahi_drm.h'],
                             mesa['kernel_and_mesa_uapi_sha256'])

    def test_source_lock_rejects_changed_and_untracked_files(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            subprocess.run(['git', 'init', '-q', str(root)], check=True)
            (root / 'file').write_text('original\n')
            subprocess.run(['git', '-C', str(root), 'add', 'file'], check=True)
            subprocess.run(['git', '-C', str(root), '-c', 'user.name=Test', '-c', 'user.email=test@example.invalid',
                            'commit', '-qm', 'fixture'], check=True)
            head = subprocess.check_output(['git', '-C', str(root), 'rev-parse', 'HEAD'], text=True).strip()
            lock = {'kernel': {'commit': head}, 'file_sha256': {'file': hashlib.sha256(b'original\n').hexdigest()}}
            checker.check_source(root, lock)
            (root / 'file').write_text('changed\n')
            with self.assertRaises(ValueError):
                checker.check_source(root, lock)
            (root / 'file').write_text('original\n')
            (root / 'extra').write_text('extra')
            with self.assertRaises(ValueError):
                checker.check_source(root, lock)
            (root / 'extra').unlink()
            lock['file_sha256']['file'] = '0' * 64
            with self.assertRaises(ValueError):
                checker.check_source(root, lock)
            lock['file_sha256']['file'] = hashlib.sha256(b'original\n').hexdigest()
            lock['kernel']['commit'] = '0' * 40
            with self.assertRaises(ValueError):
                checker.check_source(root, lock)

    def test_config_requires_the_m4_graphics_stack(self):
        with tempfile.TemporaryDirectory() as tmp:
            config = pathlib.Path(tmp) / 'config'
            good = ('CONFIG_ARCH_APPLE=y\nCONFIG_ARM64_16K_PAGES=y\nCONFIG_RUST=y\n'
                    'CONFIG_DRM_APPLE=m\nCONFIG_DRM_ASAHI_M4=m\nCONFIG_PHY_APPLE_DPTX=m\n')
            config.write_text(good)
            checker.check_config(config)
            with self.assertRaises(ValueError):
                checker.check_config(config, {'CONFIG_APPLE_WATCHDOG': ['y']})
            checker.check_config(config, {'CONFIG_DRM_APPLE': ['m']})
            config.write_text(good.replace('CONFIG_DRM_ASAHI_M4=m', '# CONFIG_DRM_ASAHI_M4 is not set'))
            with self.assertRaises(ValueError):
                checker.check_config(config)
            config.write_text(good.replace('CONFIG_PHY_APPLE_DPTX=m', '# CONFIG_PHY_APPLE_DPTX is not set'))
            with self.assertRaises(ValueError):
                checker.check_config(config)
            config.write_text(good.replace('CONFIG_ARM64_16K_PAGES=y', 'CONFIG_ARM64_4K_PAGES=y'))
            with self.assertRaises(ValueError):
                checker.check_config(config)

    def test_rootfix_lock_requires_encryption_modules(self):
        lock = json.loads((HERE / 'source-lock-r7-rootfix.json').read_text())
        with tempfile.TemporaryDirectory() as tmp:
            config = pathlib.Path(tmp) / 'config'
            base = ('CONFIG_ARCH_APPLE=y\nCONFIG_ARM64_16K_PAGES=y\nCONFIG_RUST=y\n'
                    'CONFIG_DRM_APPLE=m\nCONFIG_DRM_ASAHI_M4=m\nCONFIG_PHY_APPLE_DPTX=m\n')
            required = lock['required_config']
            complete = base + ''.join(f'{key}={values[-1]}\n' for key, values in required.items())
            config.write_text(complete)
            checker.check_config(config, required)
            for key in ('CONFIG_DM_CRYPT', 'CONFIG_DM_INTEGRITY', 'CONFIG_DM_BUFIO'):
                config.write_text(complete.replace(f'{key}={required[key][-1]}\n', ''))
                with self.assertRaisesRegex(ValueError, key):
                    checker.check_config(config, required)


if __name__ == '__main__':
    unittest.main()
