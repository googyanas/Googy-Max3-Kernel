/* Copyright (c) 2014, Zhao Wei Liew <zhaoweiliew@gmail.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 and
 * only version 2 as published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 */

#include <linux/export.h>
#include <linux/kernel.h>
#include <linux/slab.h>
#include <linux/io.h>
#include <mach/socinfo.h>
#include <mach/scm.h>

#include "kgsl.h"
#include "kgsl_pwrscale.h"
#include "kgsl_device.h"

/*
 * FLOOR is 5msec to capture up to 3 re-draws
 * per frame for 60fps content.
 */
#define FLOOR			10000
/*
 * CEILING is 50msec, larger than any standard
 * frame length.
 */
#define CEILING			50000

static unsigned int conservativeness = 0;
static unsigned int min_sample_time = FLOOR;

static unsigned long total_time = 0;
static unsigned long busy_time = 0;

struct gpu_thresh_tbl {
	unsigned int up_threshold;
	unsigned int down_threshold;
};

#define GPU_SCALE(u,d) \
    { \
        .up_threshold = u, \
        .down_threshold = d, \
    }

static struct gpu_thresh_tbl thresh_tbl[] = {
	GPU_SCALE(110, 50),
	GPU_SCALE(85, 35),
	GPU_SCALE(70, 20),
	GPU_SCALE(50, 0),
	GPU_SCALE(100, 0),
};

static void conservative_wake(struct kgsl_device *device, struct kgsl_pwrscale *pwrscale)
{
	if (device->state != KGSL_STATE_NAP)
		kgsl_pwrctrl_pwrlevel_change(device,
					     device->pwrctrl.default_pwrlevel);
}

static void conservative_idle(struct kgsl_device *device, struct kgsl_pwrscale *pwrscale)
{
	struct kgsl_pwrctrl *pwr = &device->pwrctrl;
	struct kgsl_power_stats stats;
	int load, level;
	unsigned int upthreshold = 0, downthreshold = 0;

	device->ftbl->power_stats(device, &stats);

	total_time += (unsigned long) stats.total_time;
	busy_time += (unsigned long) stats.busy_time;

	/* Do not waste CPU cycles running this algorithm if
	 * the GPU just started, or if less than min_sample_time
	 * has passed since the last run.
	 */
	if (stats.total_time == 0 || total_time < min_sample_time)
		return;

	/* Prevent overflow */
	if (stats.busy_time >= 1 << 24 || stats.total_time >= 1 << 24) {
		stats.busy_time >>= 7;
		stats.total_time >>= 7;
	}

	/* If current level is unknown, default to max */
	level = pwr->active_pwrlevel;
	if (unlikely(level < pwr->max_pwrlevel)) {
		kgsl_pwrctrl_pwrlevel_change(device, pwr->max_pwrlevel);
		goto clear;
	}

	/*
	 * If there is an extended block of busy processing,
	 * increase frequency. Otherwise run the normal algorithm.
	 */
	if (busy_time > CEILING) {
		kgsl_pwrctrl_pwrlevel_change(device, pwr->max_pwrlevel);
		goto clear;
	}

	load = (100 * busy_time) / total_time;

	upthreshold = conservativeness ?
		(thresh_tbl[level].up_threshold * (100 + conservativeness)) / 100 :
		thresh_tbl[level].up_threshold;
	downthreshold = conservativeness ?
		(thresh_tbl[level].down_threshold * (100 + conservativeness)) / 100 :
		thresh_tbl[level].down_threshold;

	if (load > upthreshold)
		level = max_t(int, level - 1, pwr->max_pwrlevel);
	else if (load < downthreshold)
		level = min_t(int, level + 1, pwr->min_pwrlevel);

	kgsl_pwrctrl_pwrlevel_change(device, level);

clear:
	total_time = 0;
	busy_time = 0;
}

static void conservative_busy(struct kgsl_device *device, struct kgsl_pwrscale *pwrscale)
{
	device->on_time = ktime_to_us(ktime_get());
}

static void conservative_sleep(struct kgsl_device *device, struct kgsl_pwrscale *pwrscale)
{
	struct kgsl_pwrctrl *pwr = &device->pwrctrl;

	kgsl_pwrctrl_pwrlevel_change(device, pwr->min_pwrlevel);

	total_time = 0;
	busy_time = 0;
}

static ssize_t conservative_min_sample_time_show(struct kgsl_device *device, struct kgsl_pwrscale
						  *pwrscale, char *buf)
{
	return sprintf(buf, "%u\n", min_sample_time);
}

static ssize_t conservative_min_sample_time_store(struct kgsl_device *device, struct kgsl_pwrscale
						   *pwrscale, const char *buf,
						   size_t count)
{
	unsigned long tmp;
	int err;

	err = kstrtoul(buf, 0, &tmp);
	if (err) {
		pr_err("%s: failed setting new min sample time!\n", KGSL_NAME);
		return err;
	}

	min_sample_time = tmp;

	return count;
}

PWRSCALE_POLICY_ATTR(min_sample_time, 0644, conservative_min_sample_time_show,
		     conservative_min_sample_time_store);

static ssize_t conservative_threshold_table_show(struct kgsl_device *device, struct kgsl_pwrscale
						 *pwrscale, char *buf)
{
	int i, len = 0;
	struct kgsl_pwrctrl *pwr = &device->pwrctrl;

	if (!buf)
		return -EINVAL;

	for (i = 0; i < pwr->num_pwrlevels; i++) {
		len += sprintf(buf + len, "%d ", i);
		len += sprintf(buf + len, "%3d ", thresh_tbl[i].up_threshold);
		len += sprintf(buf + len, "%2d", thresh_tbl[i].down_threshold);
		len += sprintf(buf + len, "\n");
	}

	return len;
}

static ssize_t conservative_threshold_table_store(struct kgsl_device *device, struct kgsl_pwrscale
						  *pwrscale, const char *buf,
						  size_t count)
{
	int err;
	unsigned int tmp[3];

	err = sscanf(buf, "%d %d %d", &tmp[0], &tmp[1], &tmp[2]);

	if (err != ARRAY_SIZE(tmp))
		return -EINVAL;

	thresh_tbl[tmp[0]].up_threshold = tmp[1];
	thresh_tbl[tmp[0]].down_threshold = tmp[2];

	return err;
}

PWRSCALE_POLICY_ATTR(threshold_table, 0644, conservative_threshold_table_show,
		     conservative_threshold_table_store);

static ssize_t conservative_conservativeness_show(struct kgsl_device *device,
				       struct kgsl_pwrscale *pwrscale,
				       char *buf)
{
	return sprintf(buf, "%u\n", conservativeness);
}

static ssize_t conservative_conservativeness_store(struct kgsl_device *device,
					struct kgsl_pwrscale *pwrscale,
					const char *buf, size_t count)
{
	int ret;
	unsigned int val;

	ret = sscanf(buf, "%d", &val);
	if (ret != 1 || val > 100)
		return -EINVAL;

	conservativeness = val;

	return count;
}

PWRSCALE_POLICY_ATTR(conservativeness, 0644, conservative_conservativeness_show,
	       conservative_conservativeness_store);

static struct attribute *conservative_attrs[] = {
	&policy_attr_threshold_table.attr,
	&policy_attr_conservativeness.attr,
	&policy_attr_min_sample_time.attr,
	NULL
};

static struct attribute_group conservative_attr_group = {
	.attrs = conservative_attrs,
};

static int conservative_init(struct kgsl_device *device, struct kgsl_pwrscale *pwrscale)
{
	kgsl_pwrscale_policy_add_files(device, pwrscale, &conservative_attr_group);

	return 0;
}

static void conservative_close(struct kgsl_device *device, struct kgsl_pwrscale *pwrscale)
{
	kgsl_pwrscale_policy_remove_files(device, pwrscale, &conservative_attr_group);
}

struct kgsl_pwrscale_policy kgsl_pwrscale_policy_conservative = {
	.name = "conservative",
	.init = conservative_init,
	.busy = conservative_busy,
	.idle = conservative_idle,
	.sleep = conservative_sleep,
	.wake = conservative_wake,
	.close = conservative_close
};

EXPORT_SYMBOL(kgsl_pwrscale_policy_conservative);
