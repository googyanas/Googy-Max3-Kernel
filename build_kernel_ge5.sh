#!/bin/sh
export KERNELDIR=`readlink -f .`
export RAMFS_SOURCE="/home/googy/Anas/Googy-Max3-Kernel/Kernel/ramfs_ge5"
export PARENT_DIR=`readlink -f ..`
export USE_SEC_FIPS_MODE=true
export CROSS_COMPILE=/home/googy/Anas/linaro_a15_4.9.3-2014.11/bin/arm-cortex_a15-linux-gnueabihf-

# if [ "${1}" != "" ];then
#  export KERNELDIR=`readlink -f ${1}`
# fi

RAMFS_TMP="/home/googy/Anas/tmp_ge5/ramfs_ge5"

VER="\"-GoogyMax3_GE5-v$1\""
cp -f /home/googy/Anas/Googy-Max3-Kernel/Kernel/arch/arm/configs/0googymax3_GE5_defconfig /home/googy/Anas/Googy-Max3-Kernel/0googymax3_GE5_defconfig
sed "s#^CONFIG_LOCALVERSION=.*#CONFIG_LOCALVERSION=$VER#" /home/googy/Anas/Googy-Max3-Kernel/0googymax3_GE5_defconfig > /home/googy/Anas/Googy-Max3-Kernel/Kernel/arch/arm/configs/0googymax3_GE5_defconfig

if [ "${2}" = "x" ];then
 make mrproper || exit 1
# make -j5 0googymax3_defconfig || exit 1
fi

# if [ ! -f $KERNELDIR/.config ];
# if [ "${2}" = "y" ];then
find -name '*.ko' -exec rm -rf {} \;
# fi

# 
make 0googymax3_GE5_defconfig VARIANT_DEFCONFIG=jf_eur_defconfig SELINUX_DEFCONFIG=selinux_defconfig SELINUX_LOG_DEFCONFIG=selinux_log_defconfig || exit 1

. $KERNELDIR/.config

export KCONFIG_NOTIMESTAMP=true
export ARCH=arm

cd $KERNELDIR/
make -j3 CONFIG_NO_ERROR_ON_MISMATCH=y || exit 1

#remove previous ramfs files
rm -rf $RAMFS_TMP
rm -rf $RAMFS_TMP.cpio
rm -rf $RAMFS_TMP.cpio.gz
#copy ramfs files to tmp directory
cp -ax $RAMFS_SOURCE $RAMFS_TMP
#clear git repositories in ramfs
find $RAMFS_TMP -name .git -exec rm -rf {} \;
#remove orig backup files
# find $RAMFS_TMP -name .orig -exec rm -rf {} \;
#remove empty directory placeholders
find $RAMFS_TMP -name EMPTY_DIRECTORY -exec rm -rf {} \;
rm -rf $RAMFS_TMP/tmp3/*
#remove mercurial repository
rm -rf $RAMFS_TMP/.hg
#copy modules into ramfs
mkdir -p /home/googy/Anas/Googy-Max3-Kernel/GT-I9505_GoogyMax3_GE5.CWM/system/lib/modules
rm -rf /home/googy/Anas/Googy-Max3-Kernel/GT-I9505_GoogyMax3_GE5.CWM/system/lib/modules/*
find -name '*.ko' -exec cp -av {} /home/googy/Anas/Googy-Max3-Kernel/GT-I9505_GoogyMax3_GE5.CWM/system/lib/modules/ \;
${CROSS_COMPILE}strip --strip-unneeded /home/googy/Anas/Googy-Max3-Kernel/GT-I9505_GoogyMax3_GE5.CWM/system/lib/modules/*

cd $RAMFS_TMP
find | fakeroot cpio -H newc -o > $RAMFS_TMP.cpio 2>/dev/null
ls -lh $RAMFS_TMP.cpio
gzip -9 $RAMFS_TMP.cpio
cd -

./mkbootimg64 --kernel $KERNELDIR/arch/arm/boot/zImage --ramdisk $RAMFS_TMP.cpio.gz --cmdline "console=null androidboot.hardware=qcom user_debug=31 msm_rtb.filter=0x3F ehci-hcd.park=3" -o $KERNELDIR/boot.img --base "0x80200000" --ramdiskaddr "0x82200000"

cd /home/googy/Anas/Googy-Max3-Kernel
mv -f -v /home/googy/Anas/Googy-Max3-Kernel/Kernel/boot.img /home/googy/Anas/Googy-Max3-Kernel/GT-I9505_GoogyMax3_GE5.CWM/boot.img
cd /home/googy/Anas/Googy-Max3-Kernel/GT-I9505_GoogyMax3_GE5.CWM
zip -r ../GoogyMax3_GE5-Kernel_${1}_CWM.zip .

adb push /home/googy/Anas/Googy-Max3-Kernel/GoogyMax3_GE5-Kernel_${1}_CWM.zip /storage/sdcard0/GoogyMax3_GE5-Kernel_${1}_CWM.zip || adb push /home/googy/Anas/Googy-Max3-Kernel/GoogyMax3_GE5-Kernel_${1}_CWM.zip /storage/sdcard1/GoogyMax3_GE5-Kernel_${1}_CWM.zip
