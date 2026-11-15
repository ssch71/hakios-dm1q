# UEFI for dm1q

The Galaxy S23's (SM-S911N, dm1q) platform for HakiOS's UEFI (`uefi/` of the common repository: Mu-Silicium with HakiOS's
changes and banner). It is modelled on Mu-Silicium's `dm2qPkg` (Galaxy S23+, Active in Silicium's `Status.md`: display and
internal storage work), the same `KailuaPkg` SoC package and the same Samsung boot chain.

What is here, in `files/`:

- `Platforms/Samsung/dm1qPkg`: the memory map, the configuration map and the driver list, from dm2q's. The two phones share the
  SoC, the RAM size (8 GB) and the panel's resolution (1080x2340); **the memory map is still to be checked against dm1q's own
  tree** (`reserved-memory` of `/sys/firmware/fdt`, `tools/check-memmap.py`);
- `Resources/Configs/dm1q.toml`: the boot image, as dm2q's (header version 2, the phone's device tree in it);
- `Resources/DTBs/dm1q.dtb`, **not tracked**: the phone's own tree, `adb shell su -c 'cat /sys/firmware/fdt' > dm1q.dtb`.
  Samsung's ABL picks the tree of a boot image by `qcom,msm-id` and `qcom,board-id`, so it must be the tree of *this* phone
  on *this* firmware (S911NKSU7FZDT), not dm2q's;
- `Binaries/dm1q`, **not tracked**: the vendor's UEFI drivers, which you extract from your own phone's `xbl`
  (`tools/pull-uefi-blobs.sh`, then UEFIReader). `Binaries/dm1q/README.md` is kept: it lists the patches dm2q's needed, which
  dm1q's need as well.

```sh
devices/dm1q/uefi/apply.sh     # = uefi/apply.sh dm1q
cd Mu-Silicium && python3 build_uefi.py -d dm1q -r RELEASE
```

The build and the vendor's drivers in general: [uefi/README.md](../../../uefi/README.md).
