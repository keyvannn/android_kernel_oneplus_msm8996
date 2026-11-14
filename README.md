# OnePlus 3 (MSM8996) — Linux 4.4.302 Kernel for LineageOS 18.1 (Android 11)

An updated, bootable **Linux 4.4.302** kernel for **OnePlus 3 (`15801`)** running **LineageOS 18.1 (Android 11)** with **SELinux Enforcing**, built on top of [`tangalbert919/android_kernel_oneplus_msm8996`](https://github.com/tangalbert919/android_kernel_oneplus_msm8996) (`staging/lineage-20`, commit `21f3c249`).

> **Upstream Credit & License:** Full credit to `tangalbert919` (and `dianlujitao` / CodeAurora / LineageOS contributors) for the `4.4.302` MSM8996 bring-up base. Licensed under **GPLv2**.

---

## What Was Fixed for LineageOS 18.1 Compatibility

1. **UFS ICE / FDE Decryption (`drivers/scsi/ufs/ufs-qcom-ice.c`, `ufs-qcom.c`)**
   - Matched OnePlus 3 `3.18` 512-byte DUN/LBA and `ctrl_info_val` CDU mask so existing Android 11 `/data` FDE encryption decrypts and mounts cleanly.
2. **LineageOS 18.1 SELinux Enforcing Compatibility (`drivers/power/power_supply_core.c`, `drivers/leds/leds-qpnp.c`)**
   - Added `qcom_soc_legacy_dev()` / `legacy_psy_parent()` / `legacy_led_parent()` to expose expected `/sys/devices/soc/*` parent paths (`qpnp-smbcharger-16`, `qpnp-fg-17`, `msm-bcl-14`, `6a00000.ssusb`, `leds-qpnp-18`, `leds-qpnp-25`) matching LineageOS 18.1's `vendor_sepolicy.cil` and `vendor_file_contexts` without weakening SELinux or modifying `/vendor`.
   - Resolves `health@2.1-serv` `avc: denied` errors (`healthd: battery none chg=`) that caused `com.android.systemui` crash loops, and restores `sysfs_leds` access for `light@2.0-servi`.
3. **Vibrator HAL (`arch/arm/boot/dts/qcom/msm-pmi8994.dtsi`, `15801/msm8996-mtp.dtsi`)**
   - Switched PMI8994 haptics node back to legacy `qcom,qpnp-haptic` (`timed_output`) expected by Android 11's vibrator HAL.
4. **DTS & Touchscreen Stability (`15801/msm8996-mtp.dtsi`, `synaptics_driver_s3320.c`, `synaptics_driver_s1302.c`)**
   - Deleted `/firmware/android/vbmeta` node for legacy non-AVB boot while preserving `ramoops_mem`.
   - Fixed stack buffer sizes and added proper `copy_from_user()` handling for procfs write handlers in Synaptics s3320 / s1302 drivers.
5. **Android Cgroups & Defconfig (`arch/arm64/configs/lineageos_oneplus3_defconfig`)**
   - Fixed missing trailing newline before appended options and enabled `CONFIG_CPUSETS`, `CONFIG_PROC_PID_CPUSET`, `CONFIG_MEMCG`, `CONFIG_MEMCG_SWAP`, `CONFIG_BLK_CGROUP`, `CONFIG_CFQ_GROUP_IOSCHED`, `CONFIG_SCHED_TUNE`, `CONFIG_OVERLAY_FS`, `CONFIG_NETFILTER_XT_MATCH_QTAGUID`.

---

## Tested Status (OnePlus 3 `15801` / LineageOS 18.1)

Verified on device (`uname -a`: `Linux localhost 4.4.302-lineageos+`, `getenforce`: `Enforcing`, `sys.boot_completed`: `1`):

- **Working / Verified:**
  - Encrypted `/data` FDE boot + Android 11 UI + Magisk AnyKernel3 repacking
  - Battery & charging status (`dumpsys battery`), LEDs (`button-backlight`, `red`, `green`, `blue`, `rgb`)
  - USB ADB (`adb devices`), Wi-Fi, Camera, Cellular/RIL signal, Touch & Hardware buttons, Fingerprint
  - NFC (`pn544` / `vendor.nxp.hardware.nfc@2.0-service`: `NFA_RF_DISCOVERY_STARTED_EVT`)
  - GPS/GNSS HAL initialization (`GnssLocationProvider` & modem voting active; outdoor satellite TTFF not yet field-tested)
  - Cgroups (`cpuset`, `cpu`, `cpuacct`, `schedtune`, `blkio`, `memory`, `freezer`)
- **Not Yet Fully Tested / Caveats:**
  - Dash Charge rapid-charging rates, USB MTP file transfer, Bluetooth/in-call audio, outdoor GPS lock, and OnePlus 3T (`15811`) DTS (`vbmeta` deletion was only patched in `15801/msm8996-mtp.dtsi`).

---

## Installation (TWRP + AnyKernel3)

> Always back up your working `boot` partition in TWRP before flashing!

1. Download `OnePlus3_Kernel_4.4.302_LOS18.1_TWRP.zip` (`SHA-256`: `d1973f7fcbb71c1ae06c68928af54be9aea176b94e53d9d0aa3ceb1f61d3bd6a`).
2. Boot to **TWRP Recovery**.
3. Backup `boot` (recommended).
4. Flash `OnePlus3_Kernel_4.4.302_LOS18.1_TWRP.zip` (AnyKernel3 preserves Magisk automatically if previously installed on stock/working boot).
5. Reboot to System.

---

## Building from Source

Apply the patch on top of [`tangalbert919/android_kernel_oneplus_msm8996`](https://github.com/tangalbert919/android_kernel_oneplus_msm8996) (`staging/lineage-20`):

```bash
git clone -b staging/lineage-20 https://github.com/tangalbert919/android_kernel_oneplus_msm8996.git
cd android_kernel_oneplus_msm8996
git am /path/to/0001-oneplus3-Bring-up-Linux-4.4.302-for-LineageOS-18.1-A.patch
```

Or use the included reproducible Docker build script (`build_op3_44_los20.sh`, Ubuntu 22.04 + `gcc-9-aarch64-linux-gnu`), which applies all patches, builds `lineageos_oneplus3_defconfig`, and outputs `Image.gz-dtb`.
