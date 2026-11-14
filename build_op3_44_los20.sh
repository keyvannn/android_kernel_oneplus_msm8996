#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq && apt-get install -y -qq \
  git gcc-9 gcc-9-aarch64-linux-gnu gcc-9-arm-linux-gnueabi binutils binutils-aarch64-linux-gnu binutils-arm-linux-gnueabi \
  make bison flex bc libssl-dev libncurses5-dev libelf-dev zip unzip kmod cpio python2 >/dev/null

mkdir -p /usr/local/bin
ln -sf /usr/bin/python2 /usr/local/bin/python
ln -sf /usr/bin/gcc-9 /usr/local/bin/gcc
ln -sf /usr/bin/aarch64-linux-gnu-gcc-9 /usr/local/bin/aarch64-linux-gnu-gcc
ln -sf /usr/bin/arm-linux-gnueabi-gcc-9 /usr/local/bin/arm-linux-gnueabi-gcc
export PATH=/usr/local/bin:$PATH

export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
export CROSS_COMPILE_ARM32=arm-linux-gnueabi-

if [ ! -d /build/k44_los20/.git ]; then
  mkdir -p /build/k44_los20
  cp -r /src/kernel-oneplus3-4.4-los20/.git /build/k44_los20/
fi
cd /build/k44_los20
git reset --hard HEAD

python2 -c '
# 1. Remove vbmeta from msm8996-mtp.dtsi (keep ramoops_mem no-map intact!)
p = "arch/arm/boot/dts/qcom/15801/msm8996-mtp.dtsi"
with open(p, "r") as f:
    s = f.read()
old_fw = """&firmware {
\tandroid {
\t\tfstab {"""
new_fw = """&firmware {
\tandroid {
\t\t/delete-node/ vbmeta;
\t\tfstab {"""
assert old_fw in s, "firmware block not found"
s = s.replace(old_fw, new_fw)
with open(p, "w") as f:
    f.write(s)

# 2. Fix stack buffer overflows and __user pointer reads in synaptics_driver_s3320.c
p2 = "drivers/input/touchscreen/synaptics_driver_s3320.c"
with open(p2, "r") as f:
    s2 = f.read()
assert "i2c_smbus_read_i2c_block_data(ts->client, F12_2D_CTRL08, 14, buf);" in s2
s2 = s2.replace("uint8_t buf[4];", "uint8_t buf[32];")
s2 = s2.replace("uint8_t buf[2];", "uint8_t buf[16];")
s2 = s2.replace("uint8_t reportbuf[4];", "uint8_t reportbuf[16];")
s2 = s2.replace("unsigned char reportbuf[3];", "unsigned char reportbuf[16];")
s2 = s2.replace("uint8_t page[4];", "uint8_t page[16];")
s2 = s2.replace("char manu_name[10];", "char manu_name[32];")
s2 = s2.replace("memset(ts->fw_name,TP_FW_NAME_MAX_LEN,0);", "memset(ts->fw_name, 0, TP_FW_NAME_MAX_LEN);")
s2 = s2.replace("memset(ts->test_limit_name,TP_FW_NAME_MAX_LEN,0);", "memset(ts->test_limit_name, 0, TP_FW_NAME_MAX_LEN);")

old_chg = """static ssize_t changer_write_func(struct file *file, const char __user *buffer, size_t count, loff_t *ppos)
{
\tstruct synaptics_ts_data *ts= ts_g;
\tint ret = 0 ;

\tsscanf(&buffer[0], "%d", &ret);"""
new_chg = """static ssize_t changer_write_func(struct file *file, const char __user *buffer, size_t count, loff_t *ppos)
{
\tstruct synaptics_ts_data *ts= ts_g;
\tint ret = 0 ;
\tchar kbuf[16] = {0};
\tif (count == 0 || count >= sizeof(kbuf)) return -EINVAL;
\tif (copy_from_user(kbuf, buffer, count)) return -EFAULT;
\tsscanf(kbuf, "%d", &ret);"""
assert old_chg in s2, "changer_write_func not found"
s2 = s2.replace(old_chg, new_chg)

old_tps = """static ssize_t touch_press_status_write(struct file *file, const char __user *buffer, size_t count, loff_t *ppos)
{
\tstruct synaptics_ts_data *ts= ts_g;
\tint ret = 0 ;

\tsscanf(&buffer[0], "%d", &ret);"""
new_tps = """static ssize_t touch_press_status_write(struct file *file, const char __user *buffer, size_t count, loff_t *ppos)
{
\tstruct synaptics_ts_data *ts= ts_g;
\tint ret = 0 ;
\tchar kbuf[16] = {0};
\tif (count == 0 || count >= sizeof(kbuf)) return -EINVAL;
\tif (copy_from_user(kbuf, buffer, count)) return -EFAULT;
\tsscanf(kbuf, "%d", &ret);"""
assert old_tps in s2, "touch_press_status_write not found"
s2 = s2.replace(old_tps, new_tps)

old_tpr = """static ssize_t tp_reset_write_func (struct file *file, const char *buffer, size_t count, loff_t *ppos)
{
    int ret,write_flag,i;
\tstruct synaptics_ts_data *ts = ts_g;

\tif(ts->loading_fw) {
\t\tTPD_ERR("%s FW is updating break!!\\n",__func__);
\t\treturn count;
\t}

    ret = sscanf(buffer,"%x",&write_flag);"""
new_tpr = """static ssize_t tp_reset_write_func (struct file *file, const char __user *buffer, size_t count, loff_t *ppos)
{
    int ret,write_flag,i;
\tstruct synaptics_ts_data *ts = ts_g;
\tchar kbuf[16] = {0};

\tif(ts->loading_fw) {
\t\tTPD_ERR("%s FW is updating break!!\\n",__func__);
\t\treturn count;
\t}
\tif (count == 0 || count >= sizeof(kbuf)) return -EINVAL;
\tif (copy_from_user(kbuf, buffer, count)) return -EFAULT;
    ret = sscanf(kbuf,"%x",&write_flag);"""
assert old_tpr in s2, "tp_reset_write_func not found"
s2 = s2.replace(old_tpr, new_tpr)

with open(p2, "w") as f:
    f.write(s2)

# 3. Fix stack buffer overflows and __user pointer reads in synaptics_driver_s1302.c
p3 = "drivers/input/touchscreen/synaptics_driver_s1302.c"
with open(p3, "r") as f:
    s3 = f.read()
assert "ret = synaptics_read_product_id(ts,&buf[0]);" in s3
s3 = s3.replace("uint8_t buf[5];", "uint8_t buf[32];")
s3 = s3.replace("uint8_t buf[4];", "uint8_t buf[32];")
s3 = s3.replace("uint8_t buf[2];", "uint8_t buf[16];")
s3 = s3.replace("uint8_t buf[10]={ 0 };", "uint8_t buf[32]={ 0 };")
s3 = s3.replace("memcpy(id,&buf[0],sizeof(buf));", "memcpy(id,&buf[0],10);")
s3 = s3.replace("char fw_id[12];", "char fw_id[32];")
s3 = s3.replace("char manu_name[12];", "char manu_name[32];")
s3 = s3.replace("char buf[32];", "char buf[32] = {0};")

old_s1302_rst = """static ssize_t synaptics_s1302_reset_write (struct file *file, const char *buffer, size_t count, loff_t *ppos)
{
    int ret,write_flag;
\tstruct synaptics_ts_data *ts = tc_g;

\tif(ts->loading_fw) {
\t\tTPD_ERR("%s FW is updating break!!\\n",__func__);
\t\treturn count;
\t}

    ret = sscanf(buffer,"%x",&write_flag);"""
new_s1302_rst = """static ssize_t synaptics_s1302_reset_write (struct file *file, const char __user *buffer, size_t count, loff_t *ppos)
{
    int ret,write_flag;
\tstruct synaptics_ts_data *ts = tc_g;
\tchar kbuf[16] = {0};

\tif(ts->loading_fw) {
\t\tTPD_ERR("%s FW is updating break!!\\n",__func__);
\t\treturn count;
\t}
\tif (count == 0 || count >= sizeof(kbuf)) return -EINVAL;
\tif (copy_from_user(kbuf, buffer, count)) return -EFAULT;
    ret = sscanf(kbuf,"%x",&write_flag);"""
assert old_s1302_rst in s3, "synaptics_s1302_reset_write not found"
s3 = s3.replace(old_s1302_rst, new_s1302_rst)

old_s1302_dbg = """static ssize_t synaptics_s1302_debug_write (struct file *file, const char *buffer, size_t count, loff_t *ppos)
{
    int ret,write_flag;

    ret = sscanf(buffer,"%x",&write_flag);"""
new_s1302_dbg = """static ssize_t synaptics_s1302_debug_write (struct file *file, const char __user *buffer, size_t count, loff_t *ppos)
{
    int ret,write_flag;
    char kbuf[16] = {0};
    if (count == 0 || count >= sizeof(kbuf)) return -EINVAL;
    if (copy_from_user(kbuf, buffer, count)) return -EFAULT;
    ret = sscanf(kbuf,"%x",&write_flag);"""
assert old_s1302_dbg in s3, "synaptics_s1302_debug_write not found"
s3 = s3.replace(old_s1302_dbg, new_s1302_dbg)

old_s1302_wt = """static ssize_t synaptics_s1302_wait_time_write (struct file *file, const char *buffer, size_t count, loff_t *ppos)
{
\tint ret,write_flag;
\tret = sscanf(buffer,"%d",&write_flag);"""
new_s1302_wt = """static ssize_t synaptics_s1302_wait_time_write (struct file *file, const char __user *buffer, size_t count, loff_t *ppos)
{
\tint ret,write_flag;
\tchar kbuf[16] = {0};
\tif (count == 0 || count >= sizeof(kbuf)) return -EINVAL;
\tif (copy_from_user(kbuf, buffer, count)) return -EFAULT;
\tret = sscanf(kbuf,"%d",&write_flag);"""
assert old_s1302_wt in s3, "synaptics_s1302_wait_time_write not found"
s3 = s3.replace(old_s1302_wt, new_s1302_wt)

with open(p3, "w") as f:
    f.write(s3)

# 4. Fix UFS ICE LBA / DUN calculation in ufs-qcom-ice.c and ufs-qcom.c to match OnePlus 3 3.18 FDE encryption
p4 = "drivers/scsi/ufs/ufs-qcom-ice.c"
with open(p4, "r") as f:
    s4 = f.read()
old_lba = """\tif (req->bio)
\t\tlba = (req->bio->bi_iter.bi_sector) >>
\t\t\tUFS_QCOM_ICE_TR_DATA_UNIT_4_KB;"""
new_lba = """\tif (req->bio)
\t\tlba = req->bio->bi_iter.bi_sector;"""
assert old_lba in s4, "old_lba not found in ufs-qcom-ice.c"
s4 = s4.replace(old_lba, new_lba)
with open(p4, "w") as f:
    f.write(s4)

p5 = "drivers/scsi/ufs/ufs-qcom.c"
with open(p5, "r") as f:
    s5 = f.read()
old_dun = """\tif (req->bio)
\t\t*dun = (req->bio->bi_iter.bi_sector) >>
\t\t\t\tUFS_QCOM_ICE_TR_DATA_UNIT_4_KB;"""
new_dun = """\tif (req->bio)
\t\t*dun = req->bio->bi_iter.bi_sector;"""
assert old_dun in s5, "old_dun not found in ufs-qcom.c"
s5 = s5.replace(old_dun, new_dun)
with open(p5, "w") as f:
    f.write(s5)

# 5. Match 3.18 CDU mask in ufs-qcom-ice.c (ctrl_info_val = 0x0 for 512B DUN)
p6 = "drivers/scsi/ufs/ufs-qcom-ice.c"
with open(p6, "r") as f:
    s6 = f.read()
old_cdu = """\tctrl_info_val |=
\t\tUFS_QCOM_ICE_TR_DATA_UNIT_4_KB
\t\t << OFFSET_UFS_QCOM_ICE_CTRL_INFO_CDU;"""
new_cdu = """\tctrl_info_val |=
\t\t(UFS_QCOM_ICE_TR_DATA_UNIT_4_KB &
\t\t MASK_UFS_QCOM_ICE_CTRL_INFO_CDU)
\t\t << OFFSET_UFS_QCOM_ICE_CTRL_INFO_CDU;"""
assert old_cdu in s6, "old_cdu not found"
s6 = s6.replace(old_cdu, new_cdu)
with open(p6, "w") as f:
    f.write(s6)

# 6. Vibrator: use legacy timed_output driver (qcom,qpnp-haptic) like 3.18,
#    because the Android 11 ROM vibrator HAL needs /sys/class/timed_output/vibrator
pd = "arch/arm/boot/dts/qcom/msm-pmi8994.dtsi"
with open(pd, "r") as f:
    sd = f.read()
start = sd.index("\t\tpmi8994_haptics: qcom,haptics@c000 {")
end = sd.index("\t\t};\n", start) + len("\t\t};\n")
new_node = """\t\tpmi8994_haptics: qcom,haptic@c000 {
\t\t\tstatus = "disabled";
\t\t\tcompatible = "qcom,qpnp-haptic";
\t\t\treg = <0xc000 0x100>;
\t\t\tinterrupts = <0x3 0xc0 0x0 IRQ_TYPE_EDGE_BOTH>,
\t\t\t\t     <0x3 0xc0 0x1 IRQ_TYPE_EDGE_BOTH>;
\t\t\tinterrupt-names = "sc-irq", "play-irq";
\t\t\tqcom,pmic-revid = <&pmi8994_revid>;
\t\t\tvcc_pon-supply = <&pon_perph_reg>;
\t\t\tqcom,play-mode = "direct";
\t\t\tqcom,wave-play-rate-us = <5263>;
\t\t\tqcom,actuator-type = "lra";
\t\t\tqcom,wave-shape = "square";
\t\t\tqcom,vmax-mv = <2000>;
\t\t\tqcom,ilim-ma = <800>;
\t\t\tqcom,sc-deb-cycles = <8>;
\t\t\tqcom,int-pwm-freq-khz = <505>;
\t\t\tqcom,en-brake;
\t\t\tqcom,brake-pattern = [03 03 00 00];
\t\t\tqcom,use-play-irq;
\t\t\tqcom,use-sc-irq;
\t\t\tqcom,wave-samples = [3e 3e 3e 3e 3e 3e 3e 3e];
\t\t\tqcom,wave-rep-cnt = <1>;
\t\t\tqcom,wave-samp-rep-cnt = <1>;
\t\t\tqcom,lra-high-z = "opt1";
\t\t\tqcom,lra-auto-res-mode = "qwd";
\t\t\tqcom,lra-res-cal-period = <4>;
\t\t};
"""
sd = sd[:start] + new_node + sd[end:]
with open(pd, "w") as f:
    f.write(sd)

pm = "arch/arm/boot/dts/qcom/15801/msm8996-mtp.dtsi"
with open(pm, "r") as f:
    sm = f.read()
old_ov = "\tqcom,actuator-type = <1>;\n\tqcom,vmax-mv = <2700>;"
new_ov = "\tqcom,actuator-type = \"erm\";\n\tqcom,vmax-mv = <2700>;"
assert old_ov in sm, "old_ov not found"
sm = sm.replace(old_ov, new_ov)
with open(pm, "w") as f:
    f.write(sm)

# 7. Map QPNP power_supply & LEDs sysfs parent paths to 3.18 /sys/devices/soc/* names
#    expected by LineageOS 18.1 vendor_sepolicy.cil / vendor_file_contexts.
pps = "drivers/power/power_supply_core.c"
with open(pps, "r") as f:
    sps = f.read()

old_inc = """#include <linux/thermal.h>
#include "power_supply.h\""""
new_inc = """#include <linux/thermal.h>
#include <linux/platform_device.h>
#include <linux/mutex.h>
#include "power_supply.h"

struct qcom_legacy_entry {
\tconst char *name;
\tstruct device *dev;
};

static DEFINE_MUTEX(qcom_legacy_lock);
static struct qcom_legacy_entry qcom_legacy_devs[] = {
\t{ "qpnp-smbcharger-16", NULL },
\t{ "qpnp-fg-17", NULL },
\t{ "msm-bcl-14", NULL },
\t{ "leds-qpnp-18", NULL },
\t{ "leds-qpnp-25", NULL },
};

static void qcom_legacy_dev_release(struct device *dev)
{
\tkfree(dev);
}

struct device *qcom_soc_legacy_dev(const char *name)
{
\tstatic struct device *cached_soc;
\tstatic struct device *cached_ssusb;
\tstruct device *pdev;
\tint i, rc;

\tif (!name)
\t\treturn NULL;

\tmutex_lock(&qcom_legacy_lock);
\tif (!strcmp(name, "6a00000.ssusb")) {
\t\tif (!cached_ssusb)
\t\t\tcached_ssusb = bus_find_device_by_name(&platform_bus_type,
\t\t\t\t\t\t\t     NULL, "6a00000.ssusb");
\t\tmutex_unlock(&qcom_legacy_lock);
\t\treturn cached_ssusb;
\t}

\tfor (i = 0; i < ARRAY_SIZE(qcom_legacy_devs); i++) {
\t\tif (strcmp(qcom_legacy_devs[i].name, name))
\t\t\tcontinue;
\t\tif (qcom_legacy_devs[i].dev) {
\t\t\tpdev = qcom_legacy_devs[i].dev;
\t\t\tmutex_unlock(&qcom_legacy_lock);
\t\t\treturn pdev;
\t\t}
\t\tif (!cached_soc) {
\t\t\tcached_soc = bus_find_device_by_name(&platform_bus_type,
\t\t\t\t\t\t\t   NULL, "soc");
\t\t\tif (!cached_soc) {
\t\t\t\tstruct device *u = bus_find_device_by_name(
\t\t\t\t\t&platform_bus_type, NULL, "6a00000.ssusb");
\t\t\t\tif (u) {
\t\t\t\t\tcached_soc = get_device(u->parent);
\t\t\t\t\tput_device(u);
\t\t\t\t}
\t\t\t}
\t\t}
\t\tif (!cached_soc) {
\t\t\tmutex_unlock(&qcom_legacy_lock);
\t\t\treturn NULL;
\t\t}
\t\tpdev = kzalloc(sizeof(*pdev), GFP_KERNEL);
\t\tif (!pdev) {
\t\t\tmutex_unlock(&qcom_legacy_lock);
\t\t\treturn NULL;
\t\t}
\t\tdevice_initialize(pdev);
\t\tpdev->parent = cached_soc;
\t\tpdev->release = qcom_legacy_dev_release;
\t\tdev_set_name(pdev, "%s", qcom_legacy_devs[i].name);
\t\trc = device_add(pdev);
\t\tif (rc) {
\t\t\tput_device(pdev);
\t\t\tmutex_unlock(&qcom_legacy_lock);
\t\t\treturn NULL;
\t\t}
\t\tqcom_legacy_devs[i].dev = pdev;
\t\tmutex_unlock(&qcom_legacy_lock);
\t\treturn pdev;
\t}
\tmutex_unlock(&qcom_legacy_lock);
\treturn NULL;
}
EXPORT_SYMBOL_GPL(qcom_soc_legacy_dev);

static struct device *legacy_psy_parent(const char *name, struct device *orig)
{
\tstruct device *compat = NULL;

\tif (!name)
\t\treturn orig;
\tif (!strcmp(name, "battery") || !strcmp(name, "dc"))
\t\tcompat = qcom_soc_legacy_dev("qpnp-smbcharger-16");
\telse if (!strcmp(name, "bms"))
\t\tcompat = qcom_soc_legacy_dev("qpnp-fg-17");
\telse if (!strcmp(name, "fg_adc"))
\t\tcompat = qcom_soc_legacy_dev("msm-bcl-14");
\telse if (!strcmp(name, "usb"))
\t\tcompat = qcom_soc_legacy_dev("6a00000.ssusb");

\treturn compat ? compat : orig;
}"""
assert old_inc in sps, "power_supply_core.c include block not found"
sps = sps.replace(old_inc, new_inc, 1)

old_reg = "\tdev->parent = parent;"
new_reg = "\tdev->parent = legacy_psy_parent(desc->name, parent);"
assert old_reg in sps, "dev->parent = parent not found"
sps = sps.replace(old_reg, new_reg, 1)

with open(pps, "w") as f:
    f.write(sps)

pled = "drivers/leds/leds-qpnp.c"
with open(pled, "r") as f:
    sled = f.read()

old_led_inc = "#include <linux/regulator/consumer.h>"
new_led_inc = """#include <linux/regulator/consumer.h>

extern struct device *qcom_soc_legacy_dev(const char *name);

static struct device *legacy_led_parent(const char *name, struct device *orig)
{
\tstruct device *compat = NULL;

\tif (!name)
\t\treturn orig;
\tif (!strcmp(name, "button-backlight"))
\t\tcompat = qcom_soc_legacy_dev("leds-qpnp-18");
\telse if (!strcmp(name, "red") || !strcmp(name, "green") ||
\t\t !strcmp(name, "blue") || !strcmp(name, "rgb"))
\t\tcompat = qcom_soc_legacy_dev("leds-qpnp-25");

\treturn compat ? compat : orig;
}"""
assert old_led_inc in sled, "leds-qpnp.c include block not found"
sled = sled.replace(old_led_inc, new_led_inc, 1)

old_rgb_reg = "\t\trc = led_classdev_register(&pdev->dev, &rgb_sync->cdev);"
new_rgb_reg = "\t\trc = led_classdev_register(legacy_led_parent(rgb_sync->cdev.name, &pdev->dev), &rgb_sync->cdev);"
assert old_rgb_reg in sled, "rgb_sync led_classdev_register not found"
sled = sled.replace(old_rgb_reg, new_rgb_reg, 1)

old_cdev_reg = "\t\trc = led_classdev_register(&pdev->dev, &led->cdev);"
new_cdev_reg = "\t\trc = led_classdev_register(legacy_led_parent(led->cdev.name, &pdev->dev), &led->cdev);"
assert old_cdev_reg in sled, "led->cdev led_classdev_register not found"
sled = sled.replace(old_cdev_reg, new_cdev_reg, 1)

with open(pled, "w") as f:
    f.write(sled)

print("Successfully patched 4.4-los20")
'

printf "\n" >> arch/arm64/configs/lineageos_oneplus3_defconfig
cat << "EOF" >> arch/arm64/configs/lineageos_oneplus3_defconfig
CONFIG_CPUSETS=y
CONFIG_PROC_PID_CPUSET=y
CONFIG_MEMCG=y
CONFIG_MEMCG_SWAP=y
CONFIG_MEMCG_SWAP_ENABLED=y
CONFIG_BLK_CGROUP=y
CONFIG_CFQ_GROUP_IOSCHED=y
CONFIG_SCHED_TUNE=y
CONFIG_CGROUP_SCHEDTUNE=y
CONFIG_OVERLAY_FS=y
CONFIG_NETFILTER_XT_MATCH_QTAGUID=y
# CONFIG_NETFILTER_XT_MATCH_OWNER is not set
# CONFIG_DEBUG_INFO is not set
# CONFIG_KALLSYMS_ALL is not set
# CONFIG_CORESIGHT is not set
# CONFIG_MSM_CAMERA_DEBUG is not set
# CONFIG_MSMB_CAMERA_DEBUG is not set
# CONFIG_IOMMU_DEBUG is not set
EOF

make O=out lineageos_oneplus3_defconfig
make O=out CC=aarch64-linux-gnu-gcc KCFLAGS="-Wno-error" -j$(nproc)
ls -lh out/arch/arm64/boot/Image out/arch/arm64/boot/Image.gz-dtb
od -tx4 -N64 out/arch/arm64/boot/Image
cp out/arch/arm64/boot/Image.gz-dtb /src/Image.gz-dtb-4.4.302-fixed
