# Linux 4.4.302-cip112 Kernel for OnePlus 3 / 3T (`msm8996`)

Updated Linux `4.4.302-cip112` forward-port for OnePlus 3 / 3T (`15801` / `15811`), combining:
- **OP3 hardware base:** `tangalbert919`'s `staging/lineage-20` `4.4.302` tree + LineageOS 18.1 compatibility fixes (`synaptics_driver_s1302`/`s3320`, `ufs-qcom-ice`, `qcom_soc_legacy_dev` for LEDs/power supply, `/dev/btpower`, OP3 `camera_v2`, shared `msm8996`/`pm8994` DTSI).
- **LTS security & Android 17 readiness:** Merged `Inkypen79/android_kernel_xiaomi_msm8996` (`lineage-24.0`) bringing **`v4.4.302-cip112`** (Linux CIP LTS patches up to June 2026), August 2026 fixes (`CVE-2026-43499`, `WLAN_FEATURE_11W` / `SAE`), and backports for **`eBPF`** (`RINGBUF`, `LPM_TRIE`, `SOCKMAP`, `SOCKHASH`, `QUEUE`, `CGROUP_STORAGE`), **`EROFS`**, **`IncFS`**, **`PSI`**, `pidfd_open`, `close_range`, `membarrier`, and `userfaultfd`.

## Branches

| Branch | Target | `CONFIG_ANDROID_BINDERFS` | Notes |
|--------|--------|---------------------------|-------|
| [`lineage-18.1-4.4.302-cip112`](https://github.com/keyvannn/android_kernel_oneplus_msm8996/tree/lineage-18.1-4.4.302-cip112) | LineageOS 18.1 (Android 11) | Disabled (`binder,hwbinder,vndbinder`) | Boots and verified live on OnePlus 3 (`SELinux Enforcing`) |
| [`lineage-24.0`](https://github.com/keyvannn/android_kernel_oneplus_msm8996/tree/lineage-24.0) | Android 17 / LineageOS 24.0 bring-up | Enabled (`=y`) | Compiles cleanly; ready for Android 17 ROM bring-up |

## Verified on Device (OnePlus 3 `15801`, `4.4.302-cip112-lineageos #5`)

- **Core / Security / Storage:** Boots with `SELinux Enforcing`, `dm-0` (`/data` encryption), UFS, USB ADB/MTP
- **CPUFreq & CPR3:** `qcom,cpr3-hmss-regulator` & `cpu-clock-8996` active (`cpu0` `307.2 MHz – 1.5936 GHz`, `cpu2` `307.2 MHz – 2.1504 GHz`, `interactive` governor)
- **GPU & Thermals:** Adreno 530 (`kgsl-3d0`, `msm-adreno-tz`), `thermal_zone0..4`
- **Connectivity:** Wi-Fi (`qcacld-2.0` + `11W`), Bluetooth (`bt_qca6174` + `/dev/btpower` ON), NFC (`mState=on`), RIL/Modem (`IN_SERVICE`), GPS/GNSS providers
- **Multimedia & Sensors:** Camera (`2` devices, `PIX0`/`RDI0` frames streaming, dual 720/724-byte `msm_ispif` payload support), Audio (`msm8996-tasha-mtp-snd-card` + speaker), Fingerprint, Touchscreen & physical buttons, Alert Slider (`tri-state-key`), Vibrator sysfs, Torch LED sysfs, `42/42` hardware sensors (`LSM6DS3`, `MMC3416PJ`, `APDS-9921`)
- **Battery & Charging:** `SMBCHG` / `bq27541` telemetry active (`Charging`, voltage/current/temp), Charger LED
- **Android 17 Kernel Checks:** `op3_ebpf_probe` (`11/11` eBPF maps + `pidfd_open` + `close_range`), `erofs`, `incremental-fs`, and `/proc/pressure/cpu` (`PSI`) verified on device

## Known Caveats / Next Steps

- Android 17 userspace (`bpfloader`, `init`, SELinux `bt_qca6174` path alignment) still requires booting an actual Android 17 ROM build to verify end-to-end.
- Linux `4.4` CIP tracks core Linux LTS security fixes (not every vendor/downstream Android CVE).
