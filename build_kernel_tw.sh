#!/bin/sh
export KERNELDIR=`readlink -f .`
export RAMFS_SOURCE="/root/Ramdisks/GT-I9505-TW"
export PARENT_DIR=`readlink -f ..`
export USE_SEC_FIPS_MODE=true
export CROSS_COMPILE=/Kernel_Folder/Toolchain_4.9.3-2015.03_a15/bin/arm-cortex_a15-linux-gnueabihf-

# if [ "${1}" != "" ];then
#  export KERNELDIR=`readlink -f ${1}`
# fi

RAMFS_TMP="/root/Ramdisks/GT-I9505/tmp_tw/ramfs"

VER="\"-Hulk-Kernel_TW-V1.0.1$1\""
cp -f /root/Hulk-Kernel/arch/arm/configs/0hulk_TW_defconfig /root/Hulk-Kernel/0hulk_TW_defconfig
sed "s#^CONFIG_LOCALVERSION=.*#CONFIG_LOCALVERSION=$VER#" /root/Hulk-Kernel/0hulk_TW_defconfig > /root/Hulk-Kernel/arch/arm/configs/0hulk_TW_defconfig

if [ "${2}" = "x" ];then
 make mrproper || exit 1
# make -j5 hulk_defconfig || exit 1
fi

# if [ ! -f $KERNELDIR/.config ];
# if [ "${2}" = "y" ];then
find -name '*.ko' -exec rm -rf {} \;
# fi

# 
make 0hulk_TW_defconfig VARIANT_DEFCONFIG=jf_eur_defconfig SELINUX_DEFCONFIG=selinux_defconfig SELINUX_LOG_DEFCONFIG=selinux_log_defconfig DEBUG_DEFCONFIG=jfuserdebug_defconfig || exit 1

. $KERNELDIR/.config

export KCONFIG_NOTIMESTAMP=true
export ARCH=arm

cd $KERNELDIR/
make -j3 || exit 1

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
# find $RAMFS_TMP -name .orig -exec rm -rf {} \;
#remove empty directory placeholders
find $RAMFS_TMP -name EMPTY_DIRECTORY -exec rm -rf {} \;
#remove mercurial repository
rm -rf $RAMFS_TMP/.hg
#copy modules into zip
mkdir -p /home/linux/Downloads/ROM_Folder/ArchiKitchen-master/PROJECT_HULK/system/lib/modules
rm -rf /home/linux/Downloads/ROM_Folder/ArchiKitchen-master/PROJECT_HULK/system/lib/modules/*
find -name '*.ko' -exec cp -av {} /home/linux/Downloads/ROM_Folder/ArchiKitchen-master/PROJECT_HULK/system/lib/modules/ \;
${CROSS_COMPILE}strip --strip-unneeded /home/linux/Downloads/ROM_Folder/ArchiKitchen-master/PROJECT_HULK/system/lib/modules/*

cd $RAMFS_TMP
find | fakeroot cpio -H newc -o > $RAMFS_TMP.cpio 2>/dev/null
ls -lh $RAMFS_TMP.cpio
gzip -9 $RAMFS_TMP.cpio
cd -

./mkbootimg64 --kernel $KERNELDIR/arch/arm/boot/zImage --ramdisk $RAMFS_TMP.cpio.gz --cmdline "console=null androidboot.hardware=qcom user_debug=31 msm_rtb.filter=0x3F ehci-hcd.park=3" -o $KERNELDIR/boot.img --base "0x80200000" --ramdiskaddr "0x82200000"

cd /home/linux/Downloads/ROM_Folder/ArchiKitchen-master/PROJECT_HULK
mv -f -v /root/Hulk-Kernel/boot.img /home/linux/Downloads/ROM_Folder/ArchiKitchen-master/PROJECT_HULK/boot.img
cd /home/linux/Downloads/ROM_Folder/ArchiKitchen-master/PROJECT_HULK
zip -r ../Hulk-Kernel_TW-${1}_CWM.zip .

# adb push /home/googy/Anas/Googy-Max3-Kernel/GoogyMax3_TW-Kernel_${1}_CWM.zip /storage/sdcard0/update-gmax3.zip
# 
# adb shell su -c "echo 'boot-recovery ' > /cache/recovery/command"
# adb shell su -c "echo '--update_package=/storage/sdcard0/update-gmax3.zip' >> /cache/recovery/command"
# adb shell su -c "reboot recovery"
