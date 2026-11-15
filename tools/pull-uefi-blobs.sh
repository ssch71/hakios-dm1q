#!/bin/bash
# Pull what the dm1q UEFI build needs from YOUR OWN Galaxy S23 (rooted, adb on, stock One UI 8.5 S911NKSU7FZDT):
#
#   out/dm1q.dtb            the live device tree (/sys/firmware/fdt): the one Samsung's ABL matched for this phone and firmware
#   out/xbl*.img            the xbl partition(s): the UEFI volume is inside; give it to UEFIReader
#   out/abl.img             ABL, kept as a reference (which DT and header version it accepts)
#   out/recovery-stock.img  the stock recovery, to put back with Odin (tools/mkodin.sh --stock-recovery) if you ever want it
#   out/firmware.txt        what the phone says it is running, for Binaries/dm1q/README.md
#
# Reads only. Nothing is written to the phone.
#
#   devices/dm1q/tools/pull-uefi-blobs.sh [out-dir]
set -euo pipefail
OUT=${1:-$(dirname "$(readlink -f "$0")")/../out}
mkdir -p "$OUT"

adb get-state >/dev/null 2>&1 || { echo "pull-uefi-blobs: no phone on adb" >&2; exit 1; }
su() { adb shell "su -c '$1'" | tr -d '\r'; }
su id | grep -q 'uid=0' || { echo "pull-uefi-blobs: su did not give root on the phone" >&2; exit 1; }

model=$(adb shell getprop ro.product.model | tr -d '\r')
build=$(adb shell getprop ro.build.PDA | tr -d '\r')
boot=$(adb shell getprop ro.boot.bootloader | tr -d '\r')
device=$(adb shell getprop ro.product.device | tr -d '\r')
echo "pull-uefi-blobs: $model ($device), PDA $build, bootloader $boot"
case "$model" in SM-S911N) ;; *) echo "pull-uefi-blobs: this is not an SM-S911N; the port is for dm1q (SM-S911N)" >&2; exit 1 ;; esac
[ "$build" = S911NKSU7FZDT ] || echo "pull-uefi-blobs: note: the port was planned on S911NKSU7FZDT, this phone runs $build"

pull_part() { # pull_part <partition name> <file>
	local dev
	dev=$(su "readlink -f /dev/block/by-name/$1 2>/dev/null" || true)
	[ -n "$dev" ] && [ "$dev" != "/dev/block/by-name/$1" ] || return 1
	adb exec-out "su -c 'cat $dev'" > "$2"
	echo "pull-uefi-blobs: $1 -> $(basename "$2") ($(stat -c %s "$2" 2>/dev/null || wc -c < "$2") bytes)"
}

adb exec-out "su -c 'cat /sys/firmware/fdt'" > "$OUT/dm1q.dtb"
head -c 4 "$OUT/dm1q.dtb" | od -An -tx1 | grep -q 'd0 0d fe ed' || { echo "pull-uefi-blobs: /sys/firmware/fdt is not a device tree" >&2; exit 1; }
echo "pull-uefi-blobs: device tree -> dm1q.dtb"

got=0
for p in xbl xbl_a xbl_s xbl_config xbl_config_a; do pull_part "$p" "$OUT/$p.img" && got=$((got + 1)) || true; done
[ $got -gt 0 ] || { echo "pull-uefi-blobs: no xbl partition found: list them with adb shell su -c 'ls /dev/block/by-name'" >&2; exit 1; }
pull_part abl "$OUT/abl.img" || pull_part abl_a "$OUT/abl.img" || true
pull_part recovery "$OUT/recovery-stock.img" || true

{
	echo "model=$model device=$device"
	echo "pda=$build bootloader=$boot"
	echo "board_id=$(adb shell cat /proc/device-tree/qcom,board-id 2>/dev/null | od -An -tx4 | tr -s ' ')"
	echo "msm_id=$(adb shell cat /proc/device-tree/qcom,msm-id 2>/dev/null | od -An -tx4 | tr -s ' ')"
	su "strings /dev/block/by-name/xbl 2>/dev/null | grep -m1 -E \"BOOT\\.MXF\"" || true
} > "$OUT/firmware.txt"
cat "$OUT/firmware.txt"
cat <<EOF
pull-uefi-blobs: done. Next:
  cp $OUT/dm1q.dtb Mu-Silicium/Resources/DTBs/dm1q.dtb
  UEFIReader on $OUT/xbl*.img  ->  Mu-Silicium/Binaries/dm1q/   (then the patches of devices/dm1q/uefi/files/Binaries/dm1q/README.md)
These files are Samsung's and Qualcomm's: keep them on your disk, never commit them.
EOF
