# -*- Makefile -*-
# $Id: hsmget.mk,v 1.1.2.2 2012/09/27 15:36:46 afy Exp $
# ------------------------------------------------------------------------------
# FMS/FRE Project: Common Makefile for the HSM Data-Pulling Tool (hsmget)
# ------------------------------------------------------------------------------
# afy    Ver   1.00  Initial version (copied from NCRC and split)   April 12
# afy    Ver   2.00  Replace variable uuid => ptmptmp               September 12
# afy    Ver   2.01  Add variables FINALCOPY/{TAR,CPO}COPY_DIRECT   September 12
# afy    Ver   2.02  Add variables SUM_TARGET_DIR/TOUCH_MTIME       September 12
# afy    Ver   2.03  Add variables MSG_PTMP/MSG                     September 12
# afy    Ver   2.05  Modify all the recipes using above variables   September 12
# ------------------------------------------------------------------------------
# Copyright (C) NOAA Geophysical Fluid Dynamics Laboratory, 2000-2012
# Designed and written by V. Balaji, Amy Langenhorst and Aleksey Yakovlev
#

# use csh, with no user .cshrc
SHELL = /bin/csh -f

# verbose flag: set to -v to get verbose commans
verbose =
# timer off by default
time =
# flag to force remote retrieval, non-empty string means ON
force =
# flag to turn on checksums
check =
# commands: these are all the external dependencies
commands :=

# temporary directory, different for each invocation of hsmget.mk
ptmptmp := $(PTMPROOT)/tmp/$(shell uuidgen)

include $(FRE_COMMANDS_HOME)/site/$(FRE_SYSTEM_SITE)/hsmget.inc

# list variables (first target)
what:
	@echo Using Makefile $(firstword $(MAKEFILE_LIST)) ...
	@echo ARCHROOT = $(ARCHROOT)
	@echo PTMPROOT = $(PTMPROOT)
	@echo WORKROOT = $(WORKROOT)
	@echo uuid = $(uuid)

# list commands
which:
	@echo Command paths: $(shell which $(commands))

FINALCOPY = $(MKDIR) $(PTMPROOT)/$* && (set nonomatch; $(RM) $(PTMPROOT)/$*/*) && $(MV) $(ptmptmp)/* $(PTMPROOT)/$*
TARCOPY_DIRECT = $(MKDIR) $(ptmptmp) && (cd $(ptmptmp); $(UNTAR) $<) && $(FINALCOPY) && $(RM) $(ptmptmp)
CPOCOPY_DIRECT = $(MKDIR) $(ptmptmp) && (cd $(ptmptmp); $(UNCPO) $<) && $(FINALCOPY) && $(RM) $(ptmptmp)
SUM_TARGET_DIR = cd $(PTMPROOT)/$* && $(SUM) `$(FIND) . $(FINDFLAGS)` > $@
TOUCH_MTIME = touch -m -r $< $@
MSG_PTMP = echo Created $(PTMPROOT)/$* from $<
MSG = echo Created $@ from $<

# get remote file
ifneq ($(force),)
$(ARCHROOT)/%:
	@$(MKDIR) $(@D)
	cd $(ARCHROOT) && $(REMOTECP) $(REMOTEID)/$* $(LOCALID)$(@D)
	@echo Created $@ from $(REMOTEID)/$*
endif

# moving from ARCH to PTMP
# first look for file of same name
# we've chosen not to retrieve entire directories from /archive... dangerous!
# if not found look for .cpio
# if not found look for .tar
# if not found look for .nc.cpio
# if not found look for .nc.tar
# TODO: need to include .tar.gz?

# 20090508: tar/cpio unpacking is now followed by touching an ok file
# to ensure that the unpacking actually finished, the direct approach
# had problems if you ^C'd in the middle of an untar...

$(PTMPROOT)/%.ok: $(ARCHROOT)/%
	-test -f $< && $(MKDIR) $(@D) && $(LOCALCP) `$(RESOLVE) $<` $(@D) || \
	 test -d $< && $(MKDIR) $(PTMPROOT)/$* && $(LOCALCP) `$(FIND) $< $(FINDFLAGS)` $(PTMPROOT)/$*
ifneq ($(check),)
	-test -f $< && cd $(@D) && $(SUM) $(*F) > $@ && cd $(<D) && $(CHECK) $@ || \
	 test -d $< && cd $(PTMPROOT)/$* && $(SUM) `$(FIND) . $(FINDFLAGS)` > $@ && cd $< && $(CHECK) $@
endif
	$(TOUCH_MTIME)
	@$(MSG_PTMP)

$(PTMPROOT)/%.ok: $(ARCHROOT)/%.tar
	$(TARCOPY_DIRECT)
ifneq ($(check),)
	$(SUM_TARGET_DIR)
endif
	$(TOUCH_MTIME)
	@$(MSG_PTMP)

$(PTMPROOT)/%.ok: $(ARCHROOT)/%.nc.tar
	$(TARCOPY_DIRECT)
ifneq ($(check),)
	$(SUM_TARGET_DIR)
endif
	$(TOUCH_MTIME)
	@$(MSG_PTMP)

$(PTMPROOT)/%.ok: $(ARCHROOT)/%.cpio
	$(CPOCOPY_DIRECT)
ifneq ($(check),)
	$(SUM_TARGET_DIR)
endif
	$(TOUCH_MTIME)
	@$(MSG_PTMP)

$(PTMPROOT)/%.ok: $(ARCHROOT)/%.nc.cpio
	$(CPOCOPY_DIRECT)
ifneq ($(check),)
	$(SUM_TARGET_DIR)
endif
	$(TOUCH_MTIME)
	@$(MSG_PTMP)

# moving from PTMP to WORK
$(WORKROOT)/%: $(PTMPROOT)/%
	@$(MKDIR) $(@D)
ifeq ($(verbose),)
	ln -f $< $@ >& /dev/null || $(LOCALCP) $< $@
else
	ln -f $< $@ || $(LOCALCP) $< $@
endif
	chmod a-w $<
	@$(MSG)

# the dot variables
.LOW_RESOLUTION_TIME: $(WORKROOT)/% $(PTMPROOT)/%
.PRECIOUS: $(PTMPROOT)/%
.SUFFIXES:
.SUFFIXES: .cpio .ok .tar
