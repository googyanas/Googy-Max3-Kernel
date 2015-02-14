#!/bin/sh
export KERNELDIR=`readlink -f .`
export RAMFS_SOURCE="/home/googy/Anas/Ramdisks/ramfs_cm12"
export PARENT_DIR=`readlink -f ..`
export USE_SEC_FIPS_MODE=true
export CROSS_COMPILE=/home/googy/Anas/linaro_a15_4.9.3-2015.01/bin/arm-cortex_a15-linux-gnueabihf-

# if [ "${1}" != "" ];then
#  export KERNELDIR=`readlink -f ${1}`
# fi

RAMFS_TMP="/home/googy/Anas/tmp_cm12/ramfs_cm12"

VER="\"-GoogyMax3_CM12-v$1\""
cp -f /home/googy/Anas/Googy-Max3-Kernel/Kernel/arch/arm/configs/0googymax3_cm12_defconfig /home/googy/Anas/Googy-Max3-Kernel/0googymax3_cm12_defconfig
sed "s#^CONFIG_LOCALVERSION=.*#CONFIG_LOCALVERSION=$VER#" /home/googy/Anas/Googy-Max3-Kernel/0googymax3_cm12_defconfig > /home/googy/Anas/Googy-Max3-Kernel/Kernel/arch/arm/configs/0googymax3_cm12_defconfig

if [ "${2}" = "x" ];then
 make mrproper || exit 1
# make -j5 0googymax3_defconfig || exit 1
fi

# if [ ! -f $KERNELDIR/.config ];
# if [ "${2}" = "y" ];then
find -name '*.ko' -exec rm -rf {} \;
# fi

# 
make 0googymax3_cm12_defconfig VARIANT_DEFCONFIG=jf_eur_defconfig SELINUX_DEFCONFIG=selinux_defconfig SELINUX_LOG_DEFCONFIG=selinux_log_defconfig || exit 1

. $KERNELDIR/.config

export KCONFIG_NOTIMESTAMP=true
export ARCH=arm

cd $KERNELDIR/
make -j3 CONFIG_NO_ERROR_ON_MISMATCH=y || exit 1

#remove previous ramfs files
rm -rf $RAMFS_TMP
rm -rf $RAMFS_TMP.cpio
rm -rf $RAMFS_TMP.cpio.gz
rm -rf $RAMFS_TMP/*
#copy ramfs files to tmp directory
cp -ax $RAMFS_SOURCE $RAMFS_TMP
#clear git repositories in ramfs
find $RAMFS_TMP -name .git -exec rm -rf {} \;
#remove orig backup files
find $RAMFS_TMP -name .orig -exec rm -rf {} \;
#remove empty directory placeholders
find $RAMFS_TMP -name EMPTY_DIRECTORY -exec rm -rf {} \;
#remove mercurial repository
rm -rf $RAMFS_TMP/.hg
#copy modules into ramfs
mkdir -p /home/googy/Anas/Googy-Max3-Kernel/GT-I9505_GoogyMax3_CM12.CWM/system/lib/modules
rm -rf /home/googy/Anas/Googy-Max3-Kernel/GT-I9505_GoogyMax3_CM12.CWM/system/lib/modules/*
find -name '*.ko' -exec cp -av {} /home/googy/Anas/Googy-Max3-Kernel/GT-I9505_GoogyMax3_CM12.CWM/system/lib/modules/ \;
${CROSS_COMPILE}strip --strip-unneeded /home/googy/Anas/Googy-Max3-Kernel/GT-I9505_GoogyMax3_CM12.CWM/system/lib/modules/*

cd $RAMFS_TMP
find | fakeroot cpio -H newc -o > $RAMFS_TMP.cpio 2>/dev/null
ls -lh $RAMFS_TMP.cpio
gzip -9 $RAMFS_TMP.cpio
cd -

./mkbootimg64 --kernel $KERNELDIR/arch/arm/boot/zImage --ramdisk $RAMFS_TMP.cpio.gz --cmdline "console=null androidboot.hardware=qcom user_debug=31 androidboot.selinux=permissive" -o $KERNELDIR/boot.img --base "0x80200000" --ramdiskaddr "0x82200000"
#	./mkbootimg --cmdline 'console = null androidboot.hardware=qcom user_debug=31 androidboot.selinux=permissive' --kernel $PACKAGEDIR/zImage --ramdisk $PACKAGEDIR/ramdisk.gz --base 0x80200000 --pagesize 2048 --ramdisk_offset 0x02000000 --output $PACKAGEDIR/boot.img

cd /home/googy/Anas/Googy-Max3-Kernel
mv -f -v /home/googy/Anas/Googy-Max3-Kernel/Kernel/boot.img /home/googy/Anas/Googy-Max3-Kernel/GT-I9505_GoogyMax3_CM12.CWM/boot.img
cd /home/googy/Anas/Googy-Max3-Kernel/GT-I9505_GoogyMax3_CM12.CWM
zip --symlinks -r ../GoogyMax3_CM12-Kernel_${1}_CWM.zip .

adb push /home/googy/Anas/Googy-Max3-Kernel/GoogyMax3_CM12-Kernel_${1}_CWM.zip /storage/sdcard1/GoogyMax3_CM12-Kernel_${1}_CWM.zip || adb push /home/googy/Anas/Googy-Max3-Kernel/GoogyMax3_CM12-Kernel_${1}_CWM.zip /storage/sdcard0/GoogyMax3_CM12-Kernel_${1}_CWM.zip

# adb push /home/googy/Anas/Googy-Max3-Kernel/GoogyMax3_CM12-Kernel_${1}_CWM.zip /storage/sdcard1/update-gmax3.zip
# 
# adb shell su -c "echo 'boot-recovery ' > /cache/recovery/command"
# adb shell su -c "echo '--update_package=/storage/sdcard1/update-gmax3.zip' >> /cache/recovery/command"
# adb shell su -c "reboot recovery"
