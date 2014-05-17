#!/sbin/busybox sh

BB=/sbin/busybox

# protect init from oom
echo "-1000" > /proc/1/oom_score_adj;

PIDOFINIT=$(pgrep -f "/sbin/ext/googymax3.sh");
for i in $PIDOFINIT; do
	echo "-600" > /proc/"$i"/oom_score_adj;
done;

OPEN_RW()
{
        $BB mount -o remount,rw /;
        $BB mount -o remount,rw /system;
}
OPEN_RW;

# Boot with CFQ I/O Gov
$BB echo "cfq" > /sys/block/mmcblk0/queue/scheduler;

# create init.d folder if missing
if [ ! -d /system/etc/init.d ]; then
	mkdir -p /system/etc/init.d/
	$BB chmod 755 /system/etc/init.d/;
fi;

(
	if [ ! -d /data/init.d_bkp ]; then
		$BB mkdir /data/init.d_bkp;
	fi;
	$BB mv /system/etc/init.d/* /data/init.d_bkp/;

	# run ROM scripts
	if [ -e /system/etc/init.qcom.post_boot.sh ]; then
		 /system/bin/sh /system/etc/init.qcom.post_boot.sh
	else
		$BB echo "No ROM Boot script detected"
	fi;

	$BB mv /data/init.d_bkp/* /system/etc/init.d/
)&

sleep 5;
OPEN_RW;

# some nice thing for dev
if [ ! -e /cpufreq ]; then
	$BB ln -s /sys/devices/system/cpu/cpu0/cpufreq /cpufreq;
	$BB ln -s /sys/devices/system/cpu/cpufreq/ /cpugov;
	$BB ln -s /sys/module/msm_thermal/parameters/ /cputemp;
fi;

# cleaning
$BB rm -rf /cache/lost+found/* 2> /dev/null;
$BB rm -rf /data/lost+found/* 2> /dev/null;
$BB rm -rf /data/tombstones/* 2> /dev/null;

CRITICAL_PERM_FIX()
{
	# critical Permissions fix
	$BB chown -R system:system /data/anr;
	$BB chown -R root:root /tmp;
	$BB chown -R root:root /res;
	$BB chown -R root:root /sbin;
	$BB chown -R root:root /lib;
	$BB chmod -R 777 /tmp/;
	$BB chmod -R 775 /res/;
	$BB chmod -R 06755 /sbin/ext/;
	$BB chmod -R 0777 /data/anr/;
	$BB chmod -R 0400 /data/tombstones;
	$BB chmod 06755 /sbin/busybox
}
CRITICAL_PERM_FIX;

# oom and mem perm fix
$BB chmod 666 /sys/module/lowmemorykiller/parameters/cost;
$BB chmod 666 /sys/module/lowmemorykiller/parameters/adj;
$BB chmod 666 /sys/module/lowmemorykiller/parameters/minfree

# make sure we own the device nodes
$BB chown system /sys/devices/system/cpu/cpu0/cpufreq/*
$BB chown system /sys/devices/system/cpu/cpu1/online
$BB chown system /sys/devices/system/cpu/cpu2/online
$BB chown system /sys/devices/system/cpu/cpu3/online
$BB chmod 666 /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
$BB chmod 666 /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq
$BB chmod 666 /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq
$BB chmod 444 /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_cur_freq
$BB chmod 444 /sys/devices/system/cpu/cpu0/cpufreq/stats/*
$BB chmod 666 /sys/devices/system/cpu/cpu1/online
$BB chmod 666 /sys/devices/system/cpu/cpu2/online
$BB chmod 666 /sys/devices/system/cpu/cpu3/online
$BB chmod 666 /sys/module/msm_thermal/parameters/*
$BB chmod 666 /sys/module/msm_thermal/core_control/enabled
$BB chmod 666 /sys/class/kgsl/kgsl-3d0/max_gpuclk
$BB chmod 666 /sys/devices/platform/kgsl-3d0/kgsl/kgsl-3d0/pwrscale/trustzone/governor

$BB chown -R root:root /data/property;
$BB chmod -R 0700 /data/property

# set ondemand GPU governor as default
echo "ondemand" > /sys/devices/platform/kgsl-3d0/kgsl/kgsl-3d0/pwrscale/trustzone/governor

# make sure our max gpu clock is set via sysfs
echo 450000000 > /sys/class/kgsl/kgsl-3d0/max_gpuclk

# set min max boot freq to default.
echo "1890000" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq;
echo "384000" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq;

# Fix ROM dev wrong sets.
setprop persist.adb.notify 0
setprop persist.service.adb.enable 1
setprop dalvik.vm.execution-mode int:jit
setprop pm.sleep_mode 1

if [ ! -d /data/.googymax3 ]; then
	$BB mkdir -p /data/.googymax3;
fi;

$BB chmod -R 0777 /data/.googymax3/;

ccxmlsum=`md5sum /res/customconfig/customconfig.xml | awk '{print $1}'`
if [ "a${ccxmlsum}" != "a`cat /data/.googymax3/.ccxmlsum`" ];
then
  rm -f /data/.googymax3/*.profile;
  echo ${ccxmlsum} > /data/.googymax3/.ccxmlsum;
fi;

[ ! -f /data/.googymax3/default.profile ] && cp /res/customconfig/default.profile /data/.googymax3/default.profile;
[ ! -f /data/.googymax3/battery.profile ] && cp /res/customconfig/battery.profile /data/.googymax3/battery.profile;
[ ! -f /data/.googymax3/balanced.profile ] && cp /res/customconfig/balanced.profile /data/.googymax3/balanced.profile;
[ ! -f /data/.googymax3/performance.profile ] && cp /res/customconfig/performance.profile /data/.googymax3/performance.profile;

. /res/customconfig/customconfig-helper;

read_defaults;
read_config;

# cpu
echo "$scaling_governor" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor;
echo "$scaling_min_freq" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq;
echo "$scaling_max_freq" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq;

# dynamic fsync
if [ "$Dyn_fsync_active" == "on" ];then
echo 1 > /sys/kernel/dyn_fsync/Dyn_fsync_active;
else
echo 0 > /sys/kernel/dyn_fsync/Dyn_fsync_active;
fi;

# scheduler
echo "$int_scheduler" > /sys/block/mmcblk0/queue/scheduler;
echo "$int_read_ahead_kb" > /sys/block/mmcblk0/bdi/read_ahead_kb;
echo "$ext_scheduler" > /sys/block/mmcblk1/queue/scheduler;
echo "$ext_read_ahead_kb" > /sys/block/mmcblk1/bdi/read_ahead_kb;

# busybox addons
if [ -e /system/xbin/busybox ] && [ ! -e /sbin/ifconfig ]; then
	$BB ln -s /system/xbin/busybox /sbin/ifconfig;
fi;

# enable kmem interface for everyone by GM
echo "0" > /proc/sys/kernel/kptr_restrict;

OPEN_RW;

(
	# Start any init.d scripts that may be present in the rom or added by the user
#	if [ "$init_d" == "on" ]; then
		$BB chmod 755 /system/etc/init.d/*;
		$BB run-parts /system/etc/init.d/;
#	fi;

	# ROOT activation if supersu used
	if [ -e /system/app/SuperSU.apk ] && [ -e /system/xbin/daemonsu ]; then
		if [ "$(pgrep -f "/system/xbin/daemonsu" | wc -l)" -eq "0" ]; then
			/system/xbin/daemonsu --auto-daemon &
		fi;
	fi;

if [ ! -f /system/app/STweaks_Googy-Max.apk ] || [ -f /system/app/STweaks.apk ] || [ -f /data/app/STweaks.apk ] ; then
	$BB rm -f /system/app/STweaks.apk > /dev/null 2>&1;
	$BB rm -f /system/app/STweaks_Googy-Max.apk > /dev/null 2>&1;
	$BB rm -f /data/app/com.gokhanmoral.stweaks* > /dev/null 2>&1;
	$BB rm -f /data/data/com.gokhanmoral.stweaks*/* > /dev/null 2>&1;
	$BB cp /res/STweaks_Googy-Max.apk /system/app/;
	$BB chown root.root /system/app/STweaks_Googy-Max.apk;
	$BB chmod 644 /system/app/STweaks_Googy-Max.apk;
fi;

	# disabling knox security at boot
	pm disable com.sec.knox.seandroid;
	setenforce 0;

	# Fix critical perms again after init.d mess
	CRITICAL_PERM_FIX;

)&

