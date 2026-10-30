#!/usr/bin/env python3
"""Exercise the local Gravity adapter against a synthetic image, without disks."""
import argparse
import contextlib
import hashlib
import io
import json
import os
from pathlib import Path
import shutil
import sys
import tempfile
from types import SimpleNamespace
import zipfile
from unittest.mock import patch

parser = argparse.ArgumentParser()
parser.add_argument('--installer', type=Path, required=True)
parser.add_argument('--image', type=Path, required=True)
parser.add_argument('--stage1', type=Path, required=True)
parser.add_argument('--stage2-sample', type=Path, required=True)
args = parser.parse_args()
installer, image, stage1, sample = (p.resolve(strict=True) for p in
                                    (args.installer, args.image, args.stage1, args.stage2_sample))
sys.path.insert(0, str(installer / 'src'))
import m1n1
import omarchy_m4
import omarchy_m4_recovery
import osinstall
import main

template = json.loads((image / 'installer_data.json').read_text())['os_list'][0]
parts = template['partitions']
root_size = int(parts[-1]['size'].removesuffix('B'))
boot_size = int(parts[1]['size'].removesuffix('B')) if len(parts) == 3 else None
target_uuid = '22345678-1234-1234-1234-123456789abc'
with tempfile.TemporaryDirectory(prefix='m4-installer-fixture-') as temp:
    root = Path(temp)
    (root / 'boot').mkdir()
    shutil.copyfile(stage1, root / 'boot/m1n1.bin')
    os.chdir(root)
    recovery_esp = root / 'gravity-esp'
    (recovery_esp / 'm1n1').mkdir(parents=True)
    (recovery_esp / 'EFI/BOOT').mkdir(parents=True)
    (recovery_esp / 'm1n1/boot.bin').write_bytes(b'working Gravity stage two fixture')
    (recovery_esp / 'EFI/BOOT/BOOTAA64.EFI').write_bytes(b'Gravity loader fixture')
    recovery_boot = root / 'gravity-boot'
    recovery_boot.mkdir()
    (recovery_boot / 'kernel').write_bytes(b'Gravity kernel fixture')
    (recovery_boot / 'initramfs').write_bytes(b'Gravity initramfs fixture')
    recovery_uuid = '12345678-1234-1234-1234-123456789abc'
    recovery_sha = hashlib.sha256((recovery_esp / 'm1n1/boot.bin').read_bytes()).hexdigest()
    capsule = root / 'recovery-capsule'
    recovery_args = SimpleNamespace(esp_snapshot=str(recovery_esp), boot_snapshot=str(recovery_boot),
                                    kernel='kernel', initramfs='initramfs', output=str(capsule),
                                    partuuid=recovery_uuid, stage2_sha256=recovery_sha)
    with contextlib.redirect_stdout(io.StringIO()):
        omarchy_m4_recovery.create(recovery_args)
    recovery_env = {'OMARCHY_M4_RECOVERY_CAPSULE': str(capsule),
                    'OMARCHY_M4_GRAVITY_ESP_PARTUUID': recovery_uuid,
                    'OMARCHY_M4_GRAVITY_STAGE2_SHA256': recovery_sha}
    with patch.dict(os.environ, recovery_env), contextlib.redirect_stdout(io.StringIO()):
        assert omarchy_m4.recovery_from_environment() == recovery_uuid
        omarchy_m4.verify_live_gravity_esp(recovery_esp, recovery_sha)
    with patch.dict(os.environ, {**recovery_env, 'OMARCHY_M4_GRAVITY_STAGE2_SHA256': '0' * 64}):
        try:
            omarchy_m4.recovery_from_environment()
            raise AssertionError('mismatched recovery identity accepted')
        except ValueError:
            pass
    (root / 'os').mkdir()
    (root / 'os' / template['package']).symlink_to(image / template['package'])
    disk = SimpleNamespace(mount=lambda name: str(recovery_esp))
    with patch.dict(os.environ, {**recovery_env, 'REPO_BASE': str(root)}), contextlib.redirect_stdout(io.StringIO()):
        loaded = osinstall.OSInstaller(disk, {}, template)
        loaded.load_package()
        assert loaded.omarchy_m4_recovery_uuid == recovery_uuid
        loaded.pkg.close()
    with patch.dict(os.environ, {**recovery_env, 'REPO_BASE': str(root),
                                 'OMARCHY_M4_GRAVITY_STAGE2_SHA256': '0' * 64}), contextlib.redirect_stdout(io.StringIO()):
        rejected = osinstall.OSInstaller(disk, {}, template)
        try:
            rejected.load_package()
            raise AssertionError('installer accepted mismatched recovery before partitioning')
        except ValueError:
            rejected.pkg.close()
    with zipfile.ZipFile(image / template['package']) as package:
        fs_uuid = omarchy_m4.preflight(template, package, root / 'boot/m1n1.bin', root_size, boot_size)
        assert fs_uuid == '32345678-1234-1234-1234-123456789abc'
        try:
            omarchy_m4.preflight(template, package, root / 'boot/m1n1.bin', 4096, boot_size)
            raise AssertionError('undersized root partition accepted')
        except ValueError:
            pass
        efi = root / 'new-esp'
        efi.mkdir()
        firmware = root / 'firmware'
        firmware.mkdir()
        (firmware / 'firmware.cpio').write_bytes(b'synthetic fixture firmware')
        info = SimpleNamespace(name='fresh-efi', uuid=target_uuid)
        disk = SimpleNamespace(mount=lambda name: str(efi))
        instance = osinstall.OSInstaller(disk, {}, template)
        instance.efi_part = info
        instance.omarchy_m4_recovery_uuid = recovery_uuid
        # Only the EFI boot phase is exercised; the root image is not written.
        instance.part_info = [info]
        instance.pkg = package
        instance.firmware_package = SimpleNamespace(path=str(firmware))
        boot_object = root / 'apple-boot-object'
        stub = SimpleNamespace(boot_obj_path=str(boot_object))
        with contextlib.redirect_stdout(io.StringIO()):
            instance.install(stub)
        config = (f'chosen.gravity,efi-system-partition={target_uuid}\n'
                  f'chosen.asahi,efi-system-partition={target_uuid}\n').encode()
        assert (efi / 'm1n1/boot.bin').read_bytes() == sample.read_bytes() + config
        values = m1n1.extract_vars(str(boot_object))
        assert values == [f'chosen.gravity,efi-system-partition={target_uuid}',
                          f'chosen.asahi,efi-system-partition={target_uuid}',
                          f'chainload={target_uuid};m1n1/boot.bin']
        before = (efi / 'm1n1/boot.bin').read_bytes()
        try:
            omarchy_m4.configure_stage2(efi, target_uuid)
            raise AssertionError('already configured stage two accepted as a clean image')
        except ValueError:
            assert (efi / 'm1n1/boot.bin').read_bytes() == before
    manager = main.InstallerMain.__new__(main.InstallerMain)
    manager.choose_os = lambda: template
    manager.yesno = lambda prompt: True
    with contextlib.redirect_stdout(io.StringIO()):
        assert manager.action_install_into_container([]) is True
        assert manager.action_wipe() is True
    manager.data = {}
    manager.dutil = SimpleNamespace(mount=lambda name: str(recovery_esp))
    manager.parts = [SimpleNamespace(free=False, type='EFI', uuid=recovery_uuid, name='gravity-efi')]
    manager.input = lambda: None
    loaded_fake = SimpleNamespace(omarchy_m4_recovery_uuid=recovery_uuid, load_package=lambda: None,
                                  min_size=4096, min_recommended_size=4096)
    manager.expert = True
    with patch.object(main.osinstall, 'OSInstaller', return_value=loaded_fake), \
         patch.dict(os.environ, recovery_env), contextlib.redirect_stdout(io.StringIO()):
        assert manager.action_install_into_free([]) is True
    with patch.object(main.osinstall, 'OSInstaller', return_value=loaded_fake), \
         patch.dict(os.environ, {**recovery_env, 'OMARCHY_M4_GRAVITY_STAGE2_SHA256': '0' * 64}), \
         contextlib.redirect_stdout(io.StringIO()):
        try:
            manager.action_install_into_free([])
            raise AssertionError('installer accepted a changed live Gravity EFI')
        except ValueError:
            pass
print('Passed: recovery identity, image preflight, new-ESP stage two, stage-one identity and destructive-path guards; no disk used.')
