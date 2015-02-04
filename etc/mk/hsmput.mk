# -*- Makefile -*-
# $Id: hsmput.mk,v 1.1.2.1 2012/04/04 17:32:13 afy Exp $
# ------------------------------------------------------------------------------
# FMS/FRE Project: Common Makefile for the HSM Data-Pushing Tool (hsmput)
# ------------------------------------------------------------------------------
# afy    Ver   1.00  Initial version (copied from NCRC and split)   April 12
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

# operations on ARCH
$(ARCHROOT)/%.ok: $(ARCHROOT)/%
ifneq ($(check),)
	-test -d $< && cd $< && $(SUM) `$(FIND) . -type f` > $@ || \
	 test -f $< && cd $(<D) && $(SUM) $(<F) > $@
else
	touch $@
endif
	@echo Created $(@) from $<
ifneq ($(remotepath),)
	test -f $(ARCHROOT)/$* && $(REMOTECP) $(LOCALID)$(ARCHROOT)/$* $(REMOTEID)$(remotepath)/
	@echo Created $(REMOTEID)$(remotepath) from $(ARCHROOT)/$*
endif

# moving from WORK to PTMP
$(PTMPROOT)/%.ok: $(WORKROOT)/%
ifeq ($(verbose),)
	-( test -d $< && $(MKDIR) $(PTMPROOT)/$* && ln -f -t $(PTMPROOT)/$* `$(FIND) $< $(FINDFLAGS)` >& /dev/null ) || \
	 ( test -f $< && $(MKDIR) $(@D) && ln -f -t $(@D) `$(FIND) $< $(FINDFLAGS)` >& /dev/null ) || \
	 $(LOCALCP) $< $(@D)
else
	-( test -d $< && $(MKDIR) $(PTMPROOT)/$* && ln -f -t $(PTMPROOT)/$* `$(FIND) $< $(FINDFLAGS)` ) || \
	 ( test -f $< && $(MKDIR) $(@D) && ln -f -t $(@D) `$(FIND) $< $(FINDFLAGS)` ) || \
	 $(LOCALCP) $< $(@D)
endif
ifneq ($(check),)
	-test -d $< && cd $< && $(SUM) `$(FIND) . -type f` > $@ || \
	 test -f $< && cd $(<D) && $(SUM) $(<F) > $@
else
	touch $@
endif
	@echo Created $(PTMPROOT)/$* from $<

# moving from WORK to ARCH
$(ARCHROOT)/%.cpio: $(WORKROOT)/%
	@-$(MKDIR) $(@D)
ifneq ($(check),)
# we create okfile in .. and then copy it in; otherwise it tries to checksum itself
	-test -d $< && cd $< && $(SUM) `$(FIND) . -type f` > ../$(*F).ok && \
	 ln -f ../$(*F).ok . && $(FIND) . -type f | $(CPIO) $@
else
	-test -d $< && cd $< && $(FIND) . -type f | $(CPIO) $@
endif
	@echo Created $@ from $<

$(ARCHROOT)/%.tar: $(WORKROOT)/%
	@-$(MKDIR) $(@D)
ifneq ($(check),)
# we create okfile in .. and then copy it in; otherwise it tries to checksum itself
	-test -d $< && cd $< && $(SUM) `$(FIND) . -type f` > ../$(*F).ok && \
	 ln -f ../$(*F).ok . && $(TAR) $@ .
else
	-test -d $< && cd $< && $(TAR) $@ .
endif
	@echo Created $@ from $<

# the dot variables
.LOW_RESOLUTION_TIME: $(PTMPROOT)/% $(ARCHROOT)/%.cpio $(ARCHROOT)/%.tar
.PRECIOUS: $(PTMPROOT)/% $(ARCHROOT)/%.cpio $(ARCHROOT)/%.tar
.SUFFIXES:
.SUFFIXES: .cpio .ok .tar
