# Galaxy S23 (SM-S911N, dm1q)

A HakiOS device repository for the Korean Galaxy S23 (`dm1qksx`, SM-S911N, SM8550 "kalama"), made to go **on top of the stock
One UI 8.5 firmware `S911NKSU7FZDT`** without replacing it: HakiOS lives in the `recovery` partition and nowhere else.

| | |
|---|---|
| Started by | Samsung's ABL, from `recovery` (volume-up + power): HakiOS UEFI (Mu-Silicium `dm1qPkg`), then the XNU loader |
| Android | untouched: `boot`, `init_boot` (Magisk), `vendor_boot`, `dtbo`, `vbmeta`, `super`, `userdata` |
| Back to Android | an ordinary restart; the stock recovery comes back with `tools/mkodin.sh --stock-recovery` |
| Written by HakiOS | nothing: the dm1q platform has no log partition (the loader keeps its log for `fastboot get_staged`) |

**Status: written, not yet run.** The UEFI is modelled on Silicium's `dm2q` (S23+), which is Active there with the display and the
internal storage working; dm1q's own drivers, tree and memory map are what is still to be checked on the phone.

## Why recovery, and not fastboot boot

HakiOS on redwood is started from RAM with `fastboot boot`. Samsung's bootloader has no fastboot: images are written with Odin
in download mode. The recovery partition is the one place an image can go and still leave the phone's Android and its data as
they are, and Samsung's ABL starts it with a key combination. Once started, the loader is resident on USB and speaks the
fastboot protocol itself (`xnuloader/loader.c`, the USB command channel), so the development loop of `./xl` works the same
from there: `DEVICE=dm1q ./xl run`.

## What the phone needs

- the bootloader unlocked (Developer options -> OEM unlock, then the unlock in download mode); **this wipes the phone once**,
  as unlocking always does on Samsung. A phone already rooted with Magisk has done this;
- `vbmeta` with verification off (flags 2/3): with Magisk root by Odin it already is. Otherwise ABL refuses the image
  ("Only official released binaries are allowed") and you need a patched `vbmeta` (for the stock firmware's AP) first;
- root and adb, once, to pull the phone's own device tree and UEFI drivers.

## From a clone to the phone

```sh
# 0. the common repository, with this device in devices/dm1q
tools/hakios-device.py sync

# 1. from your own phone (reads only): device tree, xbl (the UEFI drivers are in it), abl, the stock recovery
devices/dm1q/tools/pull-uefi-blobs.sh            # -> devices/dm1q/out/

# 2. HakiOS's UEFI with the dm1q platform
devices/dm1q/uefi/apply.sh                       # Mu-Silicium at uefi/BASE + HakiOS + dm1qPkg
cp devices/dm1q/out/dm1q.dtb Mu-Silicium/Resources/DTBs/dm1q.dtb
#    UEFIReader on devices/dm1q/out/xbl*.img -> Mu-Silicium/Binaries/dm1q/, then the patches in
#    devices/dm1q/uefi/files/Binaries/dm1q/README.md (the same as Silicium's dm2q)
(cd Mu-Silicium && python3 build_uefi.py -d dm1q -r RELEASE)

# 3. the loader (and, on a Mac or with theos, the kernel)
make dm1q_defconfig
make loader                                      # or make loader-open: the open kernel only
make kernel

# 4. the recovery image and its Odin package
devices/dm1q/tools/mkrecovery.py --stock devices/dm1q/out/recovery-stock.img
devices/dm1q/tools/mkodin.sh                     # -> devices/dm1q/out/HakiOS-dm1q-recovery.tar.md5

# 5. Odin: AP = that file, nothing else, Auto Reboot off. Then volume-up + power with the cable in.
DEVICE=dm1q ./xl run                             # the loader answers on USB; a run, its log, the phone back
```

`./xl` takes `DEVICE=dm1q` in `enter` (and so in every command that starts with it): `adb reboot recovery` stands in for
`fastboot boot`. `make phone` (tools/modem-cycle.sh) is redwood's and still goes through the phone's own fastboot: not for dm1q.

## What differs from redwood, part by part

| Part | redwood (SM7325) | dm1q (SM8550) |
|---|---|---|
| GIC | GICD 0x17A00000, GICR 0x17A60000 | GICD 0x17100000, GICR 0x17180000 |
| cores | 4x A55 + 4x A78, big from 4 | 3x A510 + 4x A715/A710 + X3, big is 7 (`small_cores=0x07`) |
| UEFI FD | 0x9FD00000, 2 MB, header v1 | 0xA7100000, 3 MB, header v2 with the phone's tree |
| framebuffer | 0xE1000000 | 0xB8000000, 1080x2340 |
| GPU | Adreno 642L (hakios-metal) | Adreno 740: not in `a6xx.hpp`, the window server stays on the CPU |
| Wi-Fi | WCN6750, ath11k | WCN7851, ath12k: the common driver does not fit |
| touch | Goodix / FocalTech on SPI | Samsung's (STM / Synaptics, per panel): a driver of its own, `drivers/input/` here |

## Files

| File | What |
|---|---|
| `device.conf` | what the device is, and how far each part works |
| `configs/dm1q_defconfig`, `configs/dm1q.config` | the common kernel, the SoC's fragment, this phone's (every phone driver left out) |
| `soc/`, `soc.args` | the SM8550 layer: cores, the addresses from the phone's tree (`soc_smem`, `soc_cmd_db`, ...) |
| `uefi/` | the `dm1qPkg` platform for HakiOS's UEFI ([uefi/README.md](uefi/README.md)) |
| `tools/pull-uefi-blobs.sh` | what is pulled from your phone: tree, xbl, abl, stock recovery |
| `tools/mkrecovery.py`, `tools/mkodin.sh` | the recovery image, and the Odin package that writes only it |

The vendor's drivers, the phone's tree and the images made from them are Samsung's and Qualcomm's: `.gitignore` keeps them out.
The Darwin user space is the one you lay out yourself from your own IPSW (the common repository's `LEGAL.md`); whether you may
run it on this hardware is yours to decide.

Check with `tools/hakios-device.py check dm1q`.
