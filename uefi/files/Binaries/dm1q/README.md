## Firmware Infos

- **Device:** Samsung Galaxy S23 (dm1q, SM-S911N, Korea)
- **Region:** KOO (Korea, open)
- **Version:** `S911NKSU7FZDT` (One UI 8.5) / the `BOOT.MXF.2.1.x-KAILUA` of that firmware: fill in from the extracted `xbl`

The drivers are NOT in this repository. Make this directory yourself from your own phone (`devices/dm1q/tools/pull-uefi-blobs.sh`,
then UEFIReader), and never commit them.

## Patches/Fixes (the same as Silicium's dm2q, whose drivers are of the same Kailua UEFI)

### ClockDxe:

- **Reason:** To keep the display on while UEFI boots.
- **Patch:** the call that disables the display clock's dependencies (DCD) removed.

### PmicDxe + SPMIDxe (together):

- **Reason:** UEFI crashes during boot otherwise.
- **Patch:** PmicDxe's minimal PMIC init removed; SPMIDxe's SPMI PIC init removed.

### TzDxeLA:

- **Reason:** UEFI crashes during boot otherwise.
- **Patch:** the global TZ applet variable set to `TRUE` instead of `FALSE`.

### UFSDxe:

- See Silicium's `Device-Binaries/dm2q/README.md` for the exact patch; apply the same to dm1q's.

Not checked on a dm1q yet: write here what was patched, with the offsets, once it has been done.
