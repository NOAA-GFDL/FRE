# -*- Makefile -*-
# $Id: hsmget.mk,v 1.1.2.1 2012/04/04 17:32:13 afy Exp $
# ------------------------------------------------------------------------------
# FMS/FRE Project: Common Makefile for the HSM Data-Pulling Tool (hsmget)
# ------------------------------------------------------------------------------
# afy    Ver   1.00  Initial version (copied from NCRC and split)   April 12
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

# random string for names, different for each invocation of hsmget.mk
uuid := $(shell uuidgen)

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
else
	touch $@
endif
	@echo Created $(PTMPROOT)/$* from $<

$(PTMPROOT)/%.ok: $(ARCHROOT)/%.tar
	rm -rf $(PTMPROOT)/$*
	@$(MKDIR) $(PTMPROOT)/$* $(PTMPROOT)/tmp/$(uuid)
	cd $(PTMPROOT)/tmp/$(uuid) && $(TAR) $< && mv -f $(PTMPROOT)/tmp/$(uuid)/* $(PTMPROOT)/$* && rm -rf $(PTMPROOT)/tmp/$(uuid)
ifneq ($(check),)
	cd $(PTMPROOT)/$* && $(SUM) `$(FIND) . -type f` > $@
else
	touch $@
endif
	@echo Created $(PTMPROOT)/$* from $<

$(PTMPROOT)/%.ok: $(ARCHROOT)/%.nc.tar
	rm -rf $(PTMPROOT)/$*
	@$(MKDIR) $(PTMPROOT)/$* $(PTMPROOT)/tmp/$(uuid)
	cd $(PTMPROOT)/tmp/$(uuid) && $(TAR) $< && mv -f $(PTMPROOT)/tmp/$(uuid)/* $(PTMPROOT)/$* && rm -rf $(PTMPROOT)/tmp/$(uuid)
ifneq ($(check),)
	cd $(PTMPROOT)/$* && $(SUM) `$(FIND) . -type f` > $@
else
	touch $@
endif
	@echo Created $(PTMPROOT)/$* from $<

$(PTMPROOT)/%.ok: $(ARCHROOT)/%.cpio
	rm -rf $(PTMPROOT)/$*
	@$(MKDIR) $(PTMPROOT)/$* $(PTMPROOT)/tmp/$(uuid)
	cd $(PTMPROOT)/tmp/$(uuid) && $(CPIO) $< && mv -f $(PTMPROOT)/tmp/$(uuid)/* $(PTMPROOT)/$* && rm -rf $(PTMPROOT)/tmp/$(uuid)
ifneq ($(check),)
	cd $(PTMPROOT)/$* && $(SUM) `$(FIND) . -type f` > $@
else
	touch $@
endif
	@echo Created $(PTMPROOT)/$* from $<

$(PTMPROOT)/%.ok: $(ARCHROOT)/%.nc.cpio
	rm -rf $(PTMPROOT)/$*
	@$(MKDIR) $(PTMPROOT)/$* $(PTMPROOT)/tmp/$(uuid)
	cd $(PTMPROOT)/tmp/$(uuid) && $(CPIO) $< && mv -f $(PTMPROOT)/tmp/$(uuid)/* $(PTMPROOT)/$* && rm -rf $(PTMPROOT)/tmp/$(uuid)
ifneq ($(check),)
	cd $(PTMPROOT)/$* && $(SUM) `$(FIND) . -type f` > $@
else
	touch $@
endif
	@echo Created $(PTMPROOT)/$* from $<

# moving from PTMP to WORK
$(WORKROOT)/%: $(PTMPROOT)/%
	@$(MKDIR) $(@D)
ifeq ($(verbose),)
	ln -f $< $@ >& /dev/null || $(LOCALCP) $< $@
else
	ln -f $< $@ || $(LOCALCP) $< $@
endif
	chmod a-w $<
	@echo Created $@ from $<

# the dot variables
.LOW_RESOLUTION_TIME: $(WORKROOT)/% $(PTMPROOT)/%
.PRECIOUS: $(PTMPROOT)/%
.SUFFIXES:
.SUFFIXES: .cpio .ok .tar
