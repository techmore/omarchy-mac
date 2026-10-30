# SPDX-License-Identifier: MIT
"""M4 Omarchy image checks and per-install EFI identity for Gravity installer.

This module is added to a pinned Gravity installer checkout by the local
adapter. It does not perform partitioning or create the Apple boot object.
"""
import hashlib
import os
from pathlib import Path, PurePosixPath
import stat
import struct
import tempfile
import uuid

STAGE1_SHA256 = 'ec46b6981aa88320c2548b48e0584cda04e7615cbed74b3fa18a724522a1d8ab'
STAGE2_SHA256 = 'c04c1c67633775a2831fa551ed61e047f8f854e58621e5079fed7cd877ce9a16'
KERNEL_SHA256 = '539438aed106cfc4ce28832fb7430084b16de8b692b4f407b1dacdf25e0ec833'
UKIS = ('esp/EFI/Linux/omarchy_linux-omarchy-m4-research.efi',
        'esp/EFI/Linux/omarchy_linux-omarchy-m4-research-fallback.efi')
MENU = (b'timeout: 3\ndefault_entry: 2\nremember_last_entry: no\ninterface_branding: Omarchy Bootloader\n'
        b'/+Omarchy\n//linux-omarchy-m4-research\n  protocol: efi\n'
        b'  path: boot():/EFI/Linux/omarchy_linux-omarchy-m4-research.efi\n'
        b'//linux-omarchy-m4-research-fallback\n  protocol: efi\n'
        b'  path: boot():/EFI/Linux/omarchy_linux-omarchy-m4-research-fallback.efi\n')


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def check_stage1(path):
    path = Path(path)
    if path.is_symlink() or not path.is_file() or sha256(path.read_bytes()) != STAGE1_SHA256:
        raise ValueError('Omarchy requires the matched M4 stage-one binary')


def pe_sections(data):
    if len(data) < 64 or data[:2] != b'MZ':
        raise ValueError('EFI file is not a PE executable')
    offset = struct.unpack_from('<I', data, 60)[0]
    if offset + 24 > len(data) or data[offset:offset + 6] != b'PE\0\0\x64\xaa':
        raise ValueError('EFI file is not an AArch64 PE executable')
    count, optional = struct.unpack_from('<H', data, offset + 6)[0], struct.unpack_from('<H', data, offset + 20)[0]
    table = offset + 24 + optional
    if count == 0 or count > 128 or table + count * 40 > len(data):
        raise ValueError('invalid EFI section table')
    sections = {}
    for index in range(count):
        entry = table + 40 * index
        name = data[entry:entry + 8].rstrip(b'\0').decode('ascii')
        vsize, _, size, start = struct.unpack_from('<IIII', data, entry + 8)
        if name in sections or start + size > len(data):
            raise ValueError('invalid EFI section')
        sections[name] = data[start:start + min(vsize, size)]
    return sections



def filesystem_identity(superblock):
    if len(superblock) >= 0x10048 and superblock[0x10040:0x10048] == b'_BHRfS_M':
        kind, raw = 'btrfs', superblock[0x10020:0x10030]
    elif len(superblock) >= 1144 and superblock[1080:1082] == b'\x53\xef':
        kind, raw = 'ext4', superblock[1128:1144]
    else:
        raise ValueError('image is not an ext4 or Btrfs filesystem')
    value = str(uuid.UUID(bytes=raw))
    if value == str(uuid.UUID(int=0)):
        raise ValueError('image has no filesystem UUID')
    return kind, value


def check_root_cmdline(words, kind, root_uuid):
    roots = [word for word in words if word.startswith('root=')]
    flags = [word.split('=', 1)[1].split(',') for word in words if word.startswith('rootflags=')]
    subvolumes = [part for group in flags for part in group if part.startswith('subvol=')]
    if roots != ['root=UUID=' + root_uuid]:
        raise ValueError('kernel command line does not select the root filesystem UUID')
    if kind == 'btrfs' and (len(flags) != 1 or subvolumes not in (['subvol=@'], ['subvol=/@'])):
        raise ValueError('Btrfs root must select the Omarchy @ subvolume')
    if kind == 'ext4' and subvolumes:
        raise ValueError('ext4 root cannot select a Btrfs subvolume')


def preflight(template, package, stage1, root_partition_size, boot_partition_size=None):
    """Reject incompatible images before Gravity creates or changes partitions."""
    check_stage1(stage1)
    if template.get('omarchy_m4') is not True or template.get('boot_object') != 'm1n1.bin' or template.get('next_object') != 'm1n1/boot.bin':
        raise ValueError('invalid Omarchy M4 boot template')
    parts = template.get('partitions', [])
    if len(parts) not in (2, 3):
        raise ValueError('Omarchy M4 needs new EFI and root partitions, with an optional boot partition')
    efi, root = parts[0], parts[-1]
    boot = parts[1] if len(parts) == 3 else None
    if (efi.get('type') != 'EFI' or efi.get('format') != 'fat' or efi.get('source') != 'esp'
            or efi.get('copy_firmware') is not True or root.get('type') != 'Linux'
            or efi.get('image') or root.get('source') or root.get('copy_firmware')
            or root.get('image') != 'root.img' or root.get('expand') is not True):
        raise ValueError('invalid Omarchy M4 partition template')
    if boot is not None and (boot.get('type') != 'Linux' or boot.get('image') != 'boot.img'
                             or boot.get('expand') or boot.get('source') or boot.get('copy_firmware')):
        raise ValueError('invalid separate boot partition template')
    names = {}
    for info in package.infolist():
        name = info.filename.rstrip('/')
        path = PurePosixPath(name)
        if (not name or '\\' in name or path.is_absolute() or any(x in ('', '.', '..') for x in name.split('/'))
                or stat.S_ISLNK(info.external_attr >> 16) or name.casefold() in names):
            raise ValueError('unsafe or duplicate image archive path')
        names[name.casefold()] = info
        if name.casefold().startswith('esp/vendorfw'):
            raise ValueError('device firmware must be collected by the installer')
    required = ('root.img', 'esp/m1n1/boot.bin', 'esp/EFI/BOOT/BOOTAA64.EFI', 'esp/limine.conf', *UKIS)
    if boot is not None:
        required += ('boot.img',)
    if any(name.casefold() not in names or names[name.casefold()].is_dir()
           or names[name.casefold()].filename != name for name in required):
        raise ValueError('Omarchy image is missing a boot or root file')
    if sha256(package.read(names['esp/m1n1/boot.bin'])) != STAGE2_SHA256:
        raise ValueError('Omarchy image has the wrong M4 stage two')
    pe_sections(package.read(names['esp/efi/boot/bootaa64.efi']))
    if package.read(names['esp/limine.conf']) != MENU:
        raise ValueError('Omarchy image has an unexpected Limine menu')
    rootinfo = names['root.img']
    if rootinfo.file_size < 4096 or rootinfo.file_size % 4096 or rootinfo.file_size > root_partition_size:
        raise ValueError('root image must fit and be 4 KiB aligned')
    with package.open(rootinfo) as stream:
        kind, root_uuid = filesystem_identity(stream.read(0x10080))
    if (kind == 'btrfs') != (boot is not None):
        raise ValueError('the Btrfs Omarchy layout requires a separate boot image')
    if boot is not None:
        bootinfo = names['boot.img']
        if (boot_partition_size is None or bootinfo.file_size < 4096 or bootinfo.file_size % 4096
                or bootinfo.file_size > boot_partition_size):
            raise ValueError('boot image must fit and be 4 KiB aligned')
        with package.open(bootinfo) as stream:
            boot_kind, boot_uuid = filesystem_identity(stream.read(0x10080))
        if boot_kind != 'ext4':
            raise ValueError('the separate boot image must be ext4')
        if boot_uuid == root_uuid:
            raise ValueError('root and boot filesystem UUIDs must be different')
    for name in UKIS:
        sections = pe_sections(package.read(names[name.casefold()]))
        command = sections.get('.cmdline', b'').rstrip(b'\0').decode('ascii').split()
        check_root_cmdline(command, kind, root_uuid)
        if sha256(sections.get('.linux', b'')) != KERNEL_SHA256 or not sections.get('.initrd'):
            raise ValueError('UKI kernel, initramfs or root UUID is incompatible with the image')
    return root_uuid



def recovery_from_environment():
    """Require an independently identified, inventoried Gravity recovery copy."""
    import omarchy_m4_recovery
    capsule = os.environ.get('OMARCHY_M4_RECOVERY_CAPSULE')
    partuuid = os.environ.get('OMARCHY_M4_GRAVITY_ESP_PARTUUID')
    stage2_sha = os.environ.get('OMARCHY_M4_GRAVITY_STAGE2_SHA256')
    if not capsule or not partuuid or not stage2_sha:
        raise ValueError('a Gravity recovery capsule, EFI PARTUUID and prior stage-two hash are required')
    partuuid, stage2_sha = omarchy_m4_recovery.expected_identity(partuuid, stage2_sha)
    omarchy_m4_recovery.verify(Path(capsule), partuuid, stage2_sha)
    return partuuid


def verify_live_gravity_esp(esp, expected_sha):
    """Check that the mounted Gravity ESP still has the captured stage two."""
    root = Path(esp)
    stage2 = root / 'm1n1' / 'boot.bin'
    loader = root / 'EFI' / 'BOOT' / 'BOOTAA64.EFI'
    for path in (root, root / 'm1n1', stage2, root / 'EFI', root / 'EFI' / 'BOOT', loader):
        if path.is_symlink():
            raise ValueError('linked Gravity EFI path is not accepted')
    if (not stage2.is_file() or sha256(stage2.read_bytes()) != expected_sha.lower()
            or not loader.is_file() or loader.stat().st_size == 0):
        raise ValueError('live Gravity EFI does not match the recovery capture')

def configure_stage2(esp, partuuid):
    """Bind the extracted stage two to the newly created ESP, not Gravity's ESP."""
    target = str(uuid.UUID(partuuid))
    root = Path(esp)
    stage2 = root / 'm1n1' / 'boot.bin'
    for path in (root, root / 'm1n1', stage2):
        if path.is_symlink():
            raise ValueError('linked EFI boot path is not accepted')
    if not stage2.is_file() or sha256(stage2.read_bytes()) != STAGE2_SHA256:
        raise ValueError('new ESP stage two does not match the checked image')
    firmware = root / 'vendorfw' / 'firmware.cpio'
    if firmware.parent.is_symlink() or firmware.is_symlink() or not firmware.is_file() or firmware.stat().st_size == 0:
        raise ValueError('new ESP has no collected device firmware')
    config = (f'chosen.gravity,efi-system-partition={target}\n'
              f'chosen.asahi,efi-system-partition={target}\n').encode('ascii')
    fd, name = tempfile.mkstemp(prefix='.omarchy-boot-', dir=stage2.parent)
    try:
        with os.fdopen(fd, 'wb') as stream:
            stream.write(stage2.read_bytes())
            stream.write(config)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(name, stage2)
    finally:
        if os.path.exists(name):
            os.unlink(name)
    return target
