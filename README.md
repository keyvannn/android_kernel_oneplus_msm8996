# OnePlus 3 / 3T Kernel — Linux `4.4.302-cip112` (`msm8996`)

![Kernel](https://img.shields.io/badge/Linux-4.4.302--cip112-blue)
![Device](https://img.shields.io/badge/Device-OnePlus%203%20%2F%203T%20(15801)-brightgreen)
![SELinux](https://img.shields.io/badge/SELinux-Enforcing-success)
![Android 17 Ready](https://img.shields.io/badge/eBPF%20%7C%20EROFS%20%7C%20IncFS%20%7C%20PSI-Enabled-informational)

Forward-ported Linux **`4.4.302-cip112`** kernel for the **OnePlus 3 / 3T (`msm8996`)**, built on top of `tangalbert919`'s `staging/lineage-20` tree with LineageOS 18.1 compatibility fixes and Android 17 (`lineage-24.0`) kernel backports ported from `Inkypen79/android_kernel_xiaomi_msm8996`.

---

## Branches

| Branch | Target Android | `CONFIG_ANDROID_BINDERFS` | Status |
| :--- | :--- | :--- | :--- |
| **[`lineage-18.1-4.4.302-cip112`](https://github.com/keyvannn/android_kernel_oneplus_msm8996/tree/lineage-18.1-4.4.302-cip112)** | **Android 11** (LineageOS 18.1) | Off (`binder,hwbinder,vndbinder`) | Booted & hardware-verified on OnePlus 3 (`#5`) |
| **[`lineage-24.0`](https://github.com/keyvannn/android_kernel_oneplus_msm8996/tree/lineage-24.0)** | **Android 17** (LineageOS 24.0) | Enabled (`=y`) | Compiles cleanly; ready for Android 17 ROM bring-up |

---

## What Changed vs. Older `4.4.302` (Mid-2023)

### Security & LTS Updates
- **Linux `4.4.302-cip112`:** Merged upstream CIP (Civil Infrastructure Platform) LTS patches maintained through **June 2026**.
- **August 2026 Fixes:** Includes `CVE-2026-43499`, `WLAN_FEATURE_11W` (PMF), and `WLAN_FEATURE_SAE` (WPA3-SAE) from `Inkypen79`'s tree, alongside OP3's `kpti=1` cmdline and `synaptics` / `ufs-qcom-ice` fixes.

### Android 15–17 Kernel Features
- **Extended eBPF & Verifier Backports:** Verified on-device with **`11/11` checks passing**:
  - `BPF_MAP_TYPE_HASH`, `ARRAY`, `LPM_TRIE`, `CGROUP_STORAGE`, `PERCPU_CGROUP_STORAGE`
  - `BPF_MAP_TYPE_SOCKMAP`, `SOCKHASH`, `QUEUE`, `RINGBUF`
  - Syscalls: `pidfd_open`, `close_range`
- **Filesystems & Memory/Pressure:** `EROFS` (`erofs`), `IncFS` (`incremental-fs`), `PSI` (`/proc/pressure/{cpu,io,memory}`), `CONFIG_MEMBARRIER=y`, and `CONFIG_USERFAULTFD=y`.

### OnePlus 3 Hardware Fixes Applied
- **CPUFreq & CPR3 Regulator:** Restored OP3 `msm8996`/`pm8994` shared `.dtsi` files (specifically fixing `qcom,cpr3-hmss-regulator` probe error `-22` and bringing up `6400000.qcom,cpu-clock-8996`).
- **Camera:** Restored OP3 `camera_v2` / UAPI ABI and updated `msm_ispif.c` to accept both `720`-byte (prebuilt OP3 HAL) and `724`-byte `msm_ispif_param_data_ext` payloads.
- **Bluetooth:** Restored `/dev/btpower` (`bluetooth-power.c`) and moved `bt_qca6174` under `/` in `15801/msm8996-mtp.dtsi` so SELinux `sysfs_bluetooth_writable` labels match on `Enforcing` boots.

---

## Hardware Verification Status (`4.4.302-cip112-lineageos #5`)

Tested live on **OnePlus 3 (`15801`)** running LineageOS 18.1 with **`SELinux Enforcing`**:

| Subsystem | Status | Verified Details |
| :--- | :---: | :--- |
| **Boot / Encryption / USB** | Working | Boots cleanly with `dm-0` (`/data` encrypted), UFS (`cfq`), USB ADB & MTP |
| **CPUFreq & Voltage Scaling** | Working | `cpu0`: `307.2 MHz – 1.59 GHz` · `cpu2`: `307.2 MHz – 2.15 GHz` (`interactive`, `cpr3-hmss-regulator` active) |
| **GPU & Thermals** | Working | Adreno 530 (`kgsl-3d0`, `msm-adreno-tz`), `thermal_zone0..4` active |
| **Wi-Fi** | Working | `qcacld-2.0` (`WLAN_FEATURE_11W` / `SAE`), connects normally |
| **Bluetooth** | Working | `bt_qca6174` + `/dev/btpower`, turns ON/OFF (`rfkill0=1`) |
| **Camera** | Working | Both cameras detected, `PIX0`/`RDI0` frames streaming without `ispif` errors |
| **Audio & Speaker** | Working | `msm8996-tasha-mtp-snd-card` active, loudspeaker confirmed |
| **Fingerprint & Buttons** | Working | `Fingerprint Manager` (`0` HAL deaths), touch, physical keys, Alert Slider (`tri-state-key`) |
| **Battery & Charging** | Working | `SMBCHG` / `bq27541` telemetry (`Charging`, current/voltage/temp), Charger LED |
| **Sensors, NFC, Modem, GPS** | Working | `42/42` hardware sensors (`LSM6DS3`, `MMC3416PJ`, `APDS-9921`), `NFC mState=on`, RIL `IN_SERVICE`, GNSS providers registered |
| **Vibrator & Torch** | Sysfs OK | `vibrator` service & `/sys/class/timed_output/vibrator/enable`, `led:torch_0` / `led:switch` sysfs nodes active |

---

## Known Limitations & Honest Notes

> [!NOTE]
> - **Android 17 userspace still untested:** `eBPF`, `EROFS`, `IncFS`, `PSI`, `pidfd_open`, and `close_range` are verified at the kernel level, and `lineage-24.0` compiles with `CONFIG_ANDROID_BINDERFS=y`. However, full Android 17 `bpfloader` ELF program verification and `init` bring-up can only be confirmed when booting an actual Android 17 ROM build.
> - **Security patch scope:** `v4.4.302-cip112` updates core Linux LTS subsystems through mid-2026; it does not include Android ROM userspace patches or every legacy Qualcomm vendor driver CVE.

---

## Credits & Upstream Sources

- **`tangalbert919`** — [`android_kernel_oneplus_msm8996`](https://github.com/tangalbert919/android_kernel_oneplus_msm8996) (`staging/lineage-20` OP3 `4.4.302` port)
- **`Inkypen79`** — [`android_kernel_xiaomi_msm8996`](https://github.com/Inkypen79/android_kernel_xiaomi_msm8996) (`lineage-24.0`, `4.4.302-cip112`, eBPF / EROFS / IncFS / PSI backports)
- **LineageOS** & **Linux CIP Project** (`v4.4.302-cip112`)
