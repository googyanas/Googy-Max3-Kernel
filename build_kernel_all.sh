#!/bin/bash
{
	make mrproper
	make 0hulk_TW_defconfig VARIANT_DEFCONFIG=jf_eur_defconfig SELINUX_DEFCONFIG=selinux_defconfig SELINUX_LOG_DEFCONFIG=selinux_log_defconfig DEBUG_DEFCONFIG=jfuserdebug_defconfig
        make -j3
}
