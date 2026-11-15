#!/bin/bash
# An Odin package (AP slot) that writes ONLY the recovery partition of a Galaxy S23 (SM-S911N):
#
#   out/HakiOS-dm1q-recovery.tar.md5      recovery.img from tools/mkrecovery.py: HakiOS (volume-up + power)
#   out/stock-dm1q-recovery.tar.md5       with --stock-recovery FILE: the stock recovery back (out/recovery-stock.img)
#
# Android's own partitions (boot, init_boot, vendor_boot, dtbo, vbmeta, super) are not in the package, so the installed
# One UI 8.5 (S911NKSU7FZDT) and its data stay. Requirements on the phone, as for any custom recovery on it: the bootloader
# unlocked (OEM unlock, KG state not Prenormal), and recovery's verification off in vbmeta (it is when the phone was rooted by
# flashing a vbmeta with flags 3; otherwise ABL refuses the image with "Only official released binaries are allowed").
#
#   devices/dm1q/tools/mkodin.sh [recovery.img]
#   devices/dm1q/tools/mkodin.sh --stock-recovery out/recovery-stock.img
set -euo pipefail
HERE=$(dirname "$(readlink -f "$0")")
OUT=$HERE/../out
mkdir -p "$OUT"

if [ "${1:-}" = --stock-recovery ]; then
	img=${2:?the stock recovery image}
	name=stock-dm1q-recovery
else
	img=${1:-$(readlink -f "$HERE/../../../out/dm1q-recovery.img")}
	name=HakiOS-dm1q-recovery
fi
[ -f "$img" ] || { echo "mkodin: $img not found (devices/dm1q/tools/mkrecovery.py makes it)" >&2; exit 1; }
head -c 8 "$img" | grep -q 'ANDROID!' || { echo "mkodin: $img is not an Android boot image" >&2; exit 1; }

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cp "$img" "$work/recovery.img"
if command -v lz4 >/dev/null; then
	lz4 -B6 --content-size -q -f "$work/recovery.img" "$work/recovery.img.lz4"
	member=recovery.img.lz4
else
	member=recovery.img
fi
tar -H ustar -C "$work" -cf "$OUT/$name.tar" "$member"
md5sum -t "$OUT/$name.tar" >> "$OUT/$name.tar"
mv "$OUT/$name.tar" "$OUT/$name.tar.md5"
echo "mkodin: $OUT/$name.tar.md5 ($member)"
echo "mkodin: Odin -> AP: this file only; BL, CP, CSC empty; 'Auto Reboot' off."
echo "mkodin: then hold volume-up + power (cable in) to start it; a normal restart goes to One UI."
