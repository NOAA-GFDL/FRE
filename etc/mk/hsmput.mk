# -*- Makefile -*-
# $Id: hsmput.mk,v 1.1.2.2 2012/09/27 15:44:20 afy Exp $
# ------------------------------------------------------------------------------
# FMS/FRE Project: Common Makefile for the HSM Data-Pushing Tool (hsmput)
# ------------------------------------------------------------------------------
# afy    Ver   1.00  Initial version (copied from NCRC and split)   April 12
# afy    Ver   2.00  Add variables uuid/ARCHTMP                     September 12
# afy    Ver   2.01  Add variables SUM_SOURCE_DIR/TOUCH_MTIME       September 12
# afy    Ver   2.02  Add variables MSG_PTMP/MSG                     September 12
# afy    Ver   2.03  Modify all the recipes using above variables   September 12
# ------------------------------------------------------------------------------
# Copyright (C) NOAA Geophysical Fluid Dynamics Laboratory, 2000-2012
# Designed and written by V. Balaji, Amy Langenhorst and Aleksey Yakovlev
#

# use csh, with no user .cshrc
SHELL = /bin/csh -f

# verbose flag: set to -v to get verbose commands
verbose =
# timer off by default
time =
# flag to force remote archival, non-empty string means ON
force =
# flag to turn on checksums
check =
# commands: these are all the external dependencies
commands :=

# random string, different for each invocation of hsmput.mk
uuid := $(shell uuidgen)

# flag to turn on compression (only for tar at present)
zip =
# remote path, if non-blank this is used for remote archival
remotepath =

include $(FRE_COMMANDS_HOME)/site/$(FRE_SYSTEM_SITE)/hsmput.inc

# list variables (first target)
what:
	@echo Using Makefile $(firstword $(MAKEFILE_LIST)) ...
	@echo ARCHROOT = $(ARCHROOT)
	@echo PTMPROOT = $(PTMPROOT)
	@echo WORKROOT = $(WORKROOT)

# list commands
which:
	@echo Command paths: $(shell which $(commands))

ARCHTMP = $@.$(uuid)
SUM_SOURCE_DIR = cd $< && $(SUM) `$(FIND) . $(FINDFLAGS)` > ../$(*F).ok && ln -f ../$(*F).ok .
TOUCH_MTIME = touch -m -r $< $@
MSG_PTMP = echo Created $(PTMPROOT)/$* from $<
MSG = echo Created $@ from $<

# operations on ARCH
$(ARCHROOT)/%.ok: $(ARCHROOT)/%
ifneq ($(check),)
	-test -d $< && cd $< && $(SUM) `$(FIND) . $(FINDFLAGS)` > $@ || \
	 test -f $< && cd $(<D) && $(SUM) $(<F) > $@
endif
	$(TOUCH_MTIME)
	@$(MSG)
ifneq ($(remotepath),)
	test -f $(ARCHROOT)/$* && $(REMOTECP) $(LOCALID)$(ARCHROOT)/$* $(REMOTEID)$(remotepath)/
	@echo Created $(REMOTEID)$(remotepath) from $(ARCHROOT)/$*
endif

# moving from WORK to PTMP
$(PTMPROOT)/%.ok: $(WORKROOT)/%
ifeq ($(verbose),)
	-test -d $< && $(MKDIR) $(PTMPROOT)/$* && ln -f -t $(PTMPROOT)/$* `$(FIND) $< $(FINDFLAGS)` >& /dev/null || \
	 test -f $< && $(MKDIR) $(@D) && ln -f -t $(@D) `$(FIND) $< $(FINDFLAGS)` >& /dev/null || \
	 $(LOCALCP) $< $(@D)
else
	-test -d $< && $(MKDIR) $(PTMPROOT)/$* && ln -f -t $(PTMPROOT)/$* `$(FIND) $< $(FINDFLAGS)` || \
	 test -f $< && $(MKDIR) $(@D) && ln -f -t $(@D) `$(FIND) $< $(FINDFLAGS)` || \
	 $(LOCALCP) $< $(@D)
endif
ifneq ($(check),)
	-test -d $< && cd $< && $(SUM) `$(FIND) . $(FINDFLAGS)` > $@ || \
	 test -f $< && cd $(<D) && $(SUM) $(<F) > $@
endif
	$(TOUCH_MTIME)
	@$(MSG_PTMP)

# moving from WORK to ARCH
$(ARCHROOT)/%.cpio: $(WORKROOT)/%
ifneq ($(check),)
	$(SUM_SOURCE_DIR)
endif
	-$(MKDIR) $(@D) && cd $< && $(FIND) . $(FINDFLAGS) | $(CPO) $(ARCHTMP) ; $(MV) $(ARCHTMP) $@
	$(TOUCH_MTIME)
	@$(MSG)

$(ARCHROOT)/%.tar: $(WORKROOT)/%
ifneq ($(check),)
	$(SUM_SOURCE_DIR)
endif
	-$(MKDIR) $(@D) && cd $< && $(TAR) $(ARCHTMP) . ; $(MV) $(ARCHTMP) $@
	$(TOUCH_MTIME)
	@$(MSG)

# the dot variables
.LOW_RESOLUTION_TIME: $(PTMPROOT)/% $(ARCHROOT)/%.cpio $(ARCHROOT)/%.tar
.PRECIOUS: $(PTMPROOT)/% $(ARCHROOT)/%.cpio $(ARCHROOT)/%.tar
.SUFFIXES:
.SUFFIXES: .cpio .ok .tar
