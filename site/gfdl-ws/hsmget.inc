# -*- Makefile -*-
# $Id: hsmget.inc,v 1.1.2.2.2.1 2013/03/27 22:51:30 afy Exp $
# ------------------------------------------------------------------------------
# FMS/FRE Project: HSM Site-Dependent Makefile for GFDL Workstations (hsmget)
# ------------------------------------------------------------------------------
# afy    Ver   1.00  Initial version (copied from NESCC version)    July 12
# afy    Ver   2.00  Add variables CPOOPTS/TAROPTS/RM/MV            September 12
# afy    Ver   2.01  Rename CPIO => UNCPO, TAR => UNTAR             September 12
# afy -------------- Branch 1.1.2.2.2 ----------------------------- March 13
# afy    Ver   1.00  Don't call 'gcp' with option --debug           March 13
# ------------------------------------------------------------------------------
# Copyright (C) NOAA Geophysical Fluid Dynamics Laboratory, 2000-2012
# Designed and written by V. Balaji, Amy Langenhorst and Aleksey Yakovlev
#

# timer
ifneq ($(time),)
TIMECMD := /usr/bin/time
commands += $(firstword $(TIMECMD))
endif

# remote copy
REMOTEID =
LOCALID =
GCP ?= gcp
GCPOPTS := --disable-checksum
ifeq ($(verbose),)
REMOTECP ?= $(GCP) $(GCPOPTS) --quiet
else
REMOTECP ?= $(GCP) $(GCPOPTS) --verbose
endif
commands += $(firstword $(REMOTECP))
ifneq ($(time),)
REMOTECP := $(TIMECMD) -f "$(firstword $(REMOTECP)) took %e secs." $(REMOTECP)
endif

# local copy
LOCALCP ?= cp -f --preserve=mode,timestamps $(verbose)
commands += $(firstword $(LOCALCP))
ifneq ($(time),)
LOCALCP := $(TIMECMD) -f "$(firstword $(LOCALCP)) took %e secs." $(LOCALCP)
endif

# resolve symbolic links
RESOLVE = readlink -f
commands += $(firstword $(RESOLVE))
ifneq ($(time),)
RESOLVE := $(TIMECMD) -f "$(firstword $(RESOLVE)) took %e secs." $(RESOLVE)
endif

# checksum, written to ok file
SUM := md5sum -b
commands += $(firstword $(SUM))
ifneq ($(time),)
SUM := $(TIMECMD) -f "$(firstword $(SUM)) took %e secs." $(SUM)
endif

# checksum, read from ok file
CHECK := md5sum -c
commands += $(firstword $(CHECK))
ifneq ($(time),)
CHECK := $(TIMECMD) -f "$(firstword $(CHECK)) took %e secs." $(CHECK)
endif

# cpio
CPOOPTS := -C 524288
UNCPO := cpio $(verbose) $(CPOOPTS) -i -I
commands += $(firstword $(UNCPO))
ifneq ($(time),)
UNCPO := $(TIMECMD) -f "$(firstword $(UNCPO)) took %e secs." $(UNCPO)
endif

# tar
TAROPTS := -b 1024
UNTAR := tar $(verbose) $(TAROPTS) -xf
commands += $(firstword $(UNTAR))
ifneq ($(time),)
UNTAR := $(TIMECMD) -f "$(firstword $(UNTAR)) took %e secs." $(UNTAR)
endif

# mkdir
MKDIR := mkdir -p
commands += $(firstword $(MKDIR))

# find: one level only
FIND := find -L
FINDFLAGS = -maxdepth 1 -type f
commands += $(firstword $(FIND))

# rm
RM := rm -rf
commands += $(firstword $(RM))

# mv
MV := mv -f
commands += $(firstword $(MV))
