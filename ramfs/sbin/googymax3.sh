#!/system/bin/sh
# GoogyMax3 kernel script (Root helper by Wanam)

/system/xbin/busybox mount -t rootfs -o remount,rw rootfs

ln -s /system/xbin/busybox /sbin/busybox

# Disable knox
pm disable com.sec.knox.seandroid
setenforce 0
setprop ro.securestorage.support false

rm /data/.googymax3/customconfig.xml
rm /data/.googymax3/action.cache

setprop pm.sleep_mode 1
setprop ro.ril.disable.power.collapse 0
setprop ro.telephony.call_ring.delay 1000

/system/xbin/daemonsu --auto-daemon &

if [ -d /system/etc/init.d ]; then
  /sbin/busybox run-parts /system/etc/init.d
fi

chmod 755 /res/uci.sh
/res/uci.sh apply

/system/xbin/busybox mount -t rootfs -o remount,ro rootfs
