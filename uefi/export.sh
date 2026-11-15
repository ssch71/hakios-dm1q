#!/bin/bash
# Save the dm1q platform from Mu-Silicium/ into files/ here (uefi/export.sh runs this; HakiOS's own changes are uefi/'s).
# The vendor's drivers (Binaries/dm1q) and the phone's device tree (Resources/DTBs/dm1q.dtb) are NOT copied back: they are
# Samsung's and Qualcomm's, from your own phone, and stay out of the repository.
set -e
cd "$(dirname "$(readlink -f "$0")")"
MU=${MU:-../../../Mu-Silicium}
rm -rf files/Platforms files/Resources/Configs
mkdir -p files/Resources/Configs files/Platforms/Samsung files/Binaries/dm1q
cp -r $MU/Platforms/Samsung/dm1qPkg files/Platforms/Samsung/
cp $MU/Resources/Configs/dm1q.toml files/Resources/Configs/
find files -name __pycache__ -prune -exec rm -rf {} +
echo "devices/dm1q/uefi/export.sh: $(find files -type f | wc -l) files"
