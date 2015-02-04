# -*- Makefile -*-
# $Id: hsmput.inc,v 1.1.2.2.2.1 2013/03/27 22:57:08 afy Exp $
# ------------------------------------------------------------------------------
# FMS/FRE Project: HSM Site-Dependent Makefile for GFDL Workstations (hsmput)
# ------------------------------------------------------------------------------
# afy    Ver   1.00  Initial version (copied from NESCC version)    July 12
# afy    Ver   2.00  Add variables CPOOPTS/RM/MV                    September 12
# afy    Ver   2.01  Rename CPIO => CPO                             September 12
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
GCPOPTS := -cd --disable-checksum
ifeq ($(verbose),)
REMOTECP := $(GCP) $(GCPOPTS) --quiet
else
REMOTECP := $(GCP) $(GCPOPTS) --verbose
endif
commands += $(firstword $(REMOTECP))
ifneq ($(time),)
REMOTECP := $(TIMECMD) -f "$(firstword $(REMOTECP)) took %e secs." $(REMOTECP)
endif

# local copy
LOCALCP ?= cp -p -r $(verbose)
commands += $(firstword $(LOCALCP))
ifneq ($(time),)
LOCALCP := $(TIMECMD) -f "$(firstword $(LOCALCP)) took %e secs." $(LOCALCP)
endif

# checksum, written to okfile
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
CPO := cpio $(verbose) $(CPOOPTS) -o -O
commands += $(firstword $(CPO))
ifneq ($(time),)
CPO := $(TIMECMD) -f "$(firstword $(CPO)) took %e secs." $(CPO)
endif

# tar
TAROPTS := -b 1024
ifneq ($(zip),)
TAROPTS += -z
endif
TAR := tar $(verbose) $(TAROPTS) -cf
commands += $(firstword $(TAR))
ifneq ($(time),)
TAR := $(TIMECMD) -f "$(firstword $(TAR)) took %e secs." $(TAR)
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
