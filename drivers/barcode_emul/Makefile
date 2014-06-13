#
# makefile for Barcode Emulator
#

ifeq ($(CONFIG_GED_BUILD),y)
obj-$(CONFIG_SEC_FPGA)	+= barcode_emul_ice4_ge.o
else
obj-$(CONFIG_SEC_FPGA)	+= barcode_emul_ice4.o
endif
