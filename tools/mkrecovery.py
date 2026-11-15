#!/usr/bin/env python3
"""
The dm1q (Galaxy S23, SM-S911N) boot image: HakiOS's UEFI (Mu-Silicium dm1qPkg) and an "XNUP" payload, as an Android boot
image for the RECOVERY partition. Samsung has no fastboot, so nothing is started from RAM by the computer: the image is flashed
with Odin (tools/mkodin.sh) and started with volume-up + power. Android's boot, init_boot, vendor_boot, dtbo and super are not
touched, so the stock One UI 8.5 firmware (S911NKSU7FZDT) stays as it is.

  kernel = gzip(BootShim + UEFI FD + "XNUP" container), header version 2, the phone's own device tree in the dtb section
           (Resources/Configs/dm1q.toml of the platform, as Silicium's dm2q)

The boot shim copies the FD to FD_BASE and the payload to PAYLOAD_BASE (uefi/hakios.patch, BootShim.S).
By default the payload is the loader alone, resident (--usb): the phone then waits in the loader for `fastboot stage` and
`fastboot oem run` from the computer (./xl run with DEVICE=dm1q), the development loop of redwood.

usage: devices/dm1q/tools/mkrecovery.py [-p payload.bin] [-o recovery.img] [--partition-size N]
"""
import argparse, gzip, os, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..', '..'))
MU = os.environ.get('MU', os.path.join(ROOT, 'Mu-Silicium'))
DEVICE = 'dm1q'
# Mu-Silicium dm1qPkg (dm2q's): Resources/Configs/dm1q.toml [uefi_fd], MemoryMapLib "UEFI FD"
FD_BASE, FD_SIZE = 0xA7100000, 0x300000
# free DDR on dm1q above TZApps (0xD8800000-0xDFC00000) and below the second bank: where the loader looks for its payload
PAYLOAD_BASE, PAYLOAD_MAX = 0xF0000000, 0x04000000
# the stock recovery partition of SM-S911N; checked again against the real one with --partition-size / --stock
RECOVERY_SIZE_DEFAULT = 100 * 1024 * 1024

ap = argparse.ArgumentParser()
ap.add_argument('-p', '--payload', help='an "XNUP" container (xnuloader/mkpayload.py); default: the loader, resident on USB')
ap.add_argument('-o', '--output', default=os.path.join(ROOT, 'out', 'dm1q-recovery.img'))
ap.add_argument('--mode', default='RELEASE')
ap.add_argument('--dtb', default=os.path.join(MU, 'Resources', 'DTBs', 'dm1q.dtb'),
                help="the phone's own tree (tools/pull-uefi-blobs.sh): Samsung's ABL matches it by msm-id and board-id")
ap.add_argument('--partition-size', type=lambda s: int(s, 0), default=None)
ap.add_argument('--stock', help='the stock recovery image pulled from the phone: its size is the partition size')
args = ap.parse_args()

fd_path = os.path.join(MU, f'Build/{DEVICE}Pkg/{args.mode}_CLANGPDB/FV/SILICIUM_UEFI.fd')
parts = {'fd': fd_path, 'dtb': args.dtb, 'ramdisk': os.path.join(MU, 'Resources/ramdisk'),
         'mkbootimg': os.path.join(MU, 'Resources/Scripts/mkbootimg.py'), 'shim_src': os.path.join(MU, 'BootShim')}
for name, path in parts.items():
    if not os.path.exists(path):
        hint = {
            'fd': '\n  build it: devices/dm1q/uefi/apply.sh && cd Mu-Silicium && python3 build_uefi.py -d dm1q -r RELEASE\n'
                  '  (it needs the vendor drivers from your own phone: devices/dm1q/uefi/README.md)',
            'dtb': '\n  pull it from your phone: devices/dm1q/tools/pull-uefi-blobs.sh, then copy out/dm1q.dtb there',
        }.get(name, '\n  run devices/dm1q/uefi/apply.sh first')
        sys.exit(f'mkrecovery.py: {path} not found{hint}')

dtb = open(parts['dtb'], 'rb').read()
if dtb[:4] != b'\xd0\x0d\xfe\xed':
    sys.exit(f'mkrecovery.py: {parts["dtb"]} is not a flattened device tree')
if b'board-id' not in dtb or b'msm-id' not in dtb:
    sys.exit('mkrecovery.py: the tree has no qcom,board-id / qcom,msm-id: ABL would not take it (pull /sys/firmware/fdt)')

shim_dir = parts['shim_src']
for f in ('BootShim.elf', 'BootShim.bin'):
    try:
        os.unlink(os.path.join(shim_dir, f))
    except FileNotFoundError:
        pass
subprocess.check_call(['make', 'REQUIRES_KERNEL_HEADER=1', f'FD_BASE={FD_BASE:#x}', f'FD_SIZE={FD_SIZE:#x}',
                       f'CFLAGS=--target=aarch64-linux-gnu -DPAYLOAD_BASE={PAYLOAD_BASE:#x}'],
                      cwd=shim_dir, stdout=subprocess.DEVNULL)
shim = open(os.path.join(shim_dir, 'BootShim.bin'), 'rb').read()
fd = open(fd_path, 'rb').read()
if len(fd) != FD_SIZE:
    sys.exit(f'mkrecovery.py: the FD is {len(fd):#x} bytes, dm1qPkg says {FD_SIZE:#x}')

tmp = tempfile.mkdtemp(prefix='dm1q-')
payload = args.payload
if payload is None:
    loader = os.path.join(ROOT, 'xnuloader', 'loader.efi')
    if not os.path.isfile(loader):
        sys.exit('mkrecovery.py: xnuloader/loader.efi not found: make loader (or make loader-open)')
    payload = os.path.join(tmp, 'usb-payload.bin')
    subprocess.check_call([sys.executable, os.path.join(ROOT, 'xnuloader', 'mkpayload.py'), '-o', payload,
                           f'loader.efi={loader}', '--usb'], stdout=subprocess.DEVNULL)
data = open(payload, 'rb').read()
if data[:4] != b'XNUP' or len(data) > PAYLOAD_MAX - 0x1000:
    sys.exit('mkrecovery.py: bad or oversized payload')

blob = shim + fd + data
blob += b'\0' * (-len(blob) % 16)
kernel = os.path.join(tmp, 'kernel')
open(kernel, 'wb').write(gzip.compress(blob, 9))
dtbf = os.path.join(tmp, 'dtb')
open(dtbf, 'wb').write(dtb)
os.makedirs(os.path.dirname(os.path.abspath(args.output)), exist_ok=True)
subprocess.check_call([sys.executable, parts['mkbootimg'], '--kernel', kernel, '--ramdisk', parts['ramdisk'],
                       '--dtb', dtbf, '--header_version', '2', '--pagesize', '4096',
                       '--cmdline', 'hakios', '-o', args.output])

size = os.path.getsize(args.output)
limit = args.partition_size or (os.path.getsize(args.stock) if args.stock else RECOVERY_SIZE_DEFAULT)
if size > limit:
    os.unlink(args.output)
    sys.exit(f'mkrecovery.py: {size} bytes do not fit the recovery partition ({limit} bytes)')
print(f'payload: {len(data)} bytes')
print(f'{args.output}: {size} bytes (shim {len(shim)}, FD {len(fd)}, uncompressed {len(blob)}), recovery partition {limit}')
