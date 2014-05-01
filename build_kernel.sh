#!/bin/sh
export KERNELDIR=`readlink -f .`
export RAMFS_SOURCE="/home/googy/Anas/Googy-Max3-Kernel/Kernel/ramfs"
export PARENT_DIR=`readlink -f ..`
export USE_SEC_FIPS_MODE=true
export CROSS_COMPILE=/usr/bin/arm-linux-gnueabihf-
# export CROSS_COMPILE=/home/googy/Anas/linaro_4.7.4-2014.01/bin/arm-gnueabi-
# export CROSS_COMPILE=/home/googy/Anas/linaro_4.9.1-2014.04/bin/arm-gnueabi-
# export CROSS_COMPILE=/home/googy/Anas/linaro_4.8.3-2014.04/bin/arm-gnueabi-
# export CROSS_COMPILE=/home/googy/Anas/arm-eabi-4.7/bin/arm-eabi-

# if [ "${1}" != "" ];then
#  export KERNELDIR=`readlink -f ${1}`
# fi

RAMFS_TMP="/home/googy/Anas/tmp3/ramfs"

if [ "${2}" = "x" ];then
 make mrproper || exit 1
# make -j5 0googymax3_defconfig || exit 1
fi

# if [ ! -f $KERNELDIR/.config ];
if [ "${2}" = "y" ];then
find -name '*.ko' -exec rm -rf {} \;
fi

# 
make 0googymax3_defconfig VARIANT_DEFCONFIG=jf_eur_defconfig SELINUX_DEFCONFIG=selinux_defconfig SELINUX_LOG_DEFCONFIG=selinux_log_defconfig || exit 1

. $KERNELDIR/.config

export KCONFIG_NOTIMESTAMP=true
export ARCH=arm

cd $KERNELDIR/
make -j4 || exit 1

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
mkdir -p /home/googy/Anas/Googy-Max3-Kernel/GT-I9505_GoogyMax3.CWM/system/lib/modules
rm -rf /home/googy/Anas/Googy-Max3-Kernel/GT-I9505_GoogyMax3.CWM/system/lib/modules/*
find -name '*.ko' -exec cp -av {} /home/googy/Anas/Googy-Max3-Kernel/GT-I9505_GoogyMax3.CWM/system/lib/modules/ \;
${CROSS_COMPILE}strip --strip-unneeded /home/googy/Anas/Googy-Max3-Kernel/GT-I9505_GoogyMax3.CWM/system/lib/modules/*

cd $RAMFS_TMP
find | fakeroot cpio -H newc -o > $RAMFS_TMP.cpio 2>/dev/null
ls -lh $RAMFS_TMP.cpio
gzip -9 $RAMFS_TMP.cpio
cd -

./mkbootimg --kernel $KERNELDIR/arch/arm/boot/zImage --ramdisk $RAMFS_TMP.cpio.gz --cmdline "console=null androidboot.hardware=qcom user_debug=31 msm_rtb.filter=0x3F ehci-hcd.park=3" -o $KERNELDIR/boot.img --base "0x80200000" --ramdiskaddr "0x82200000"

cd /home/googy/Anas/Googy-Max3-Kernel
mv -f -v /home/googy/Anas/Googy-Max3-Kernel/Kernel/boot.img /home/googy/Anas/Googy-Max3-Kernel/GT-I9505_GoogyMax3.CWM/googymax3/boot.img
# mv -f -v /home/googy/Anas/Googy-Max3-Kernel/Kernel/boot.img /home/googy/Anas/Googy-Max3-Kernel/GT-I9505_GoogyMax3.CWM/boot.img
cd /home/googy/Anas/Googy-Max3-Kernel/GT-I9505_GoogyMax3.CWM
zip -v -r ../GoogyMax3-Kernel_${1}_CWM.zip .

adb push /home/googy/Anas/Googy-Max3-Kernel/GoogyMax3-Kernel_${1}_CWM.zip /storage/sdcard0/GoogyMax3-Kernel_${1}_CWM.zip
