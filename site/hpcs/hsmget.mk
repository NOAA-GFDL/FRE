# -*- Makefile -*-
# $Id: hsmget.mk,v 18.0.6.2 2010/09/01 18:37:43 vb Exp $
# HSM.mk: data transfer using three-level storage model

#use csh, with no user .cshrc
SHELL = /bin/csh -f

#verbose flag: set to -v to get verbose commans
verbose =
#timer off by default
time =
#flag to force remote retrieval, non-empty string means ON
force =
#flag to turn on checksums
check =

#random string for names, different for each invocation of hsmget.mk
uuid := $(shell uuidgen)

# commands: these are all the external dependencies
# (some of these could have further dependencies within them...)
# should come from FRE *site* configuration
commands :=
ifneq ($(time),)
#timer
TIMECMD := /usr/bin/time
commands += $(firstword $(TIMECMD))
endif
# remote copy: remote ID could be a host-user combination
REMOTEID =
# optimization flags for cxfscp
CPOPTS = -t 1 -b 8 -s 65000
REMOTECP ?= cxfscp $(CPOPTS) -up $(verbose) # no recursive copy
commands += $(firstword $(REMOTECP))
ifneq ($(time),)
#timer
REMOTECP := $(TIMECMD) -f "$(firstword $(REMOTECP)) took %e secs." $(REMOTECP)
endif
# retrieve from deep storage on remote host
DEEPGET ?= dmget
commands += $(firstword $(DEEPGET))
ifneq ($(time),)
#timer
DEEPGET := $(TIMECMD) -f "$(firstword $(DEEPGET)) took %e secs." $(DEEPGET)
endif
# fast copy
LOCALCP ?= cxfscp $(CPOPTS) -up $(verbose) # no recursive copy
commands += $(firstword $(LOCALCP))
ifneq ($(time),)
#timer
LOCALCP := $(TIMECMD) -f "$(firstword $(LOCALCP)) took %e secs." $(LOCALCP)
endif
#checksum, written to ok file
SUM := md5sum -b
commands += $(firstword $(SUM))
ifneq ($(time),)
#timer
SUM := $(TIMECMD) -f "$(firstword $(SUM)) took %e secs." $(SUM)
endif
#checksum, read from ok file
CHECK := md5sum -c
commands += $(firstword $(CHECK))
ifneq ($(time),)
#timer
CHECK := $(TIMECMD) -f "$(firstword $(CHECK)) took %e secs." $(CHECK)
endif
#cpio
#Balaji 2008-08-13, removed -mu, problem if extracted file is older than source
CPIO := cpio $(verbose) -d -i -I
commands += $(firstword $(CPIO))
ifneq ($(time),)
#timer
CPIO := $(TIMECMD) -f "$(firstword $(CPIO)) took %e secs." $(CPIO)
endif
#tar
TAR := tar $(verbose) -b 1024 -xf
commands += $(firstword $(TAR))
ifneq ($(time),)
#timer
TAR := $(TIMECMD) -f "$(firstword $(TAR)) took %e secs." $(TAR)
endif
#mkdir
MKDIR = mkdir -p
commands += $(firstword $(MKDIR))
#find: one level only
FIND = find -L
FINDFLAGS = -maxdepth 1 -type f
commands += $(firstword $(FIND))
#chmod, make ptmp files readable
CHMOD = chmod -R -f a+r
commands += $(firstword $(CHMOD))

# Directory trees in home, archive, ptmp, home follow identical
# tree below the root directory, typically something like
# ARCHROOT = /archive/$(USER)
# PTMPROOT = /work/$(USER)
# WORKROOT = $(TMPDIR)
# you can set these as environment variables or pass them to make:
# e.g make ARCHROOT=/archive/foo -f hsmget.mk

#first target
what:
	@echo Using Makefile $(firstword $(MAKEFILE_LIST)) ...
#	module list #can't run module from make! paths must be explicit
	@echo ARCHROOT = $(ARCHROOT)
	@echo PTMPROOT = $(PTMPROOT)
	@echo WORKROOT = $(WORKROOT)
	@echo uuid = $(uuid)
which:
	@echo Command paths: $(shell which $(commands))
# data movement: this is HSMget/put but depends on some FRE variables to define
# source/target correspondence.
# for remote get you may need to preface target with $(REMOTEID)
ifneq ($(force),)
$(ARCHROOT)/%:
	-test -f $@ && $(DEEPGET) $@
endif

# moving from ARCH to PTMP
# first look for file of same name
# we've chosen not to retrieve entire directories from /archive... dangerous!
# if not found look for .cpio
# if not found look for .tar
# if not found look for .nc.cpio
# if not found look for .nc.tar
#TODO: need to include .tar.gz?

#20090508: tar/cpio unpacking is now followed by touching an ok file
#to ensure that the unpacking actually finished, the direct approach
#had problems if you ^C'd in the middle of an untar...

# the DEEPGETs below can possibly be removed...
$(PTMPROOT)/%.ok: $(ARCHROOT)/%
	@touch $@.LOCK
	-test -f $< && $(DEEPGET) $< && $(MKDIR) $(@D) && $(REMOTECP) $< $(@D) || \
	 test -d $< && $(DEEPGET) `$(FIND) $< $(FINDFLAGS)` && $(MKDIR) $(PTMPROOT)/$* && $(REMOTECP) `$(FIND) $< $(FINDFLAGS)` $(PTMPROOT)/$*
	-$(CHMOD) $(PTMPROOT)/$*
ifneq ($(check),)
	-test -f $< && cd $(@D) && $(SUM) $(*F) > $@ || \
	test -d $< && cd $(PTMPROOT)/$* && $(SUM) `$(FIND) . $(FINDFLAGS)` > $@
else
	touch $@
endif
	@echo Created $(PTMPROOT)/$* from $<
	@rm -f $@.LOCK
$(PTMPROOT)/%.ok: $(ARCHROOT)/%.tar
	@touch $@.LOCK
	$(DEEPGET) $<
	@$(MKDIR) $(PTMPROOT)/$* $(PTMPROOT)/tmp/$(uuid)
	cd $(PTMPROOT)/tmp/$(uuid) && $(TAR) $< && mv -f $(PTMPROOT)/tmp/$(uuid)/* $(PTMPROOT)/$* && rm -rf $(PTMPROOT)/tmp/$(uuid)
	-$(CHMOD) $(PTMPROOT)/$*
ifneq ($(check),)
	cd $(PTMPROOT)/$* && $(SUM) `$(FIND) . -type f` > $@
else
	touch $@
endif
	@echo Created $(PTMPROOT)/$* from $<
	@rm -f $@.LOCK
$(PTMPROOT)/%.ok: $(ARCHROOT)/%.nc.tar
	@touch $@.LOCK
	$(DEEPGET) $<
	@$(MKDIR) $(PTMPROOT)/$* $(PTMPROOT)/tmp/$(uuid)
	cd $(PTMPROOT)/tmp/$(uuid) && $(TAR) $< && mv -f $(PTMPROOT)/tmp/$(uuid)/* $(PTMPROOT)/$* && rm -rf $(PTMPROOT)/tmp/$(uuid)
	-$(CHMOD) $(PTMPROOT)/$*
ifneq ($(check),)
	cd $(PTMPROOT)/$* && $(SUM) `$(FIND) . -type f` > $@
else
	touch $@
endif
	@echo Created $(PTMPROOT)/$* from $<
	@rm -f $@.LOCK
$(PTMPROOT)/%.ok: $(ARCHROOT)/%.cpio
	@touch $@.LOCK
	$(DEEPGET) $<
	@$(MKDIR) $(PTMPROOT)/$* $(PTMPROOT)/tmp/$(uuid)
	cd $(PTMPROOT)/tmp/$(uuid) && $(CPIO) $< && mv -f $(PTMPROOT)/tmp/$(uuid)/* $(PTMPROOT)/$* && rm -rf $(PTMPROOT)/tmp/$(uuid)
	-$(CHMOD) $(PTMPROOT)/$*
# 	test -d $@ && cd $@ && $(CPIO) $< || \
# 	test -f $@ || $(MKDIR) $@ && cd $@ && $(CPIO) $<
ifneq ($(check),)
	cd $(PTMPROOT)/$* && $(SUM) `$(FIND) . -type f` > $@
else
	touch $@
endif
	@echo Created $(PTMPROOT)/$* from $<
	@rm -f $@.LOCK
$(PTMPROOT)/%.ok: $(ARCHROOT)/%.nc.cpio
	@touch $@.LOCK
	$(DEEPGET) $<
	@$(MKDIR) $(PTMPROOT)/$* $(PTMPROOT)/tmp/$(uuid)
	cd $(PTMPROOT)/tmp/$(uuid) && $(CPIO) $< && mv -f $(PTMPROOT)/tmp/$(uuid)/* $(PTMPROOT)/$* && rm -rf $(PTMPROOT)/tmp/$(uuid)
	-$(CHMOD) $(PTMPROOT)/$*
# 	test -d $@ && cd $@ && $(CPIO) $< || \
# 	test -f $@ || $(MKDIR) $@ && cd $@ && $(CPIO) $<
ifneq ($(check),)
	cd $(PTMPROOT)/$* && $(SUM) `$(FIND) . -type f` > $@
else
	touch $@
endif
	@echo Created $(PTMPROOT)/$* from $<
	@rm -f $@.LOCK

#moving from PTMP to WORK
$(WORKROOT)/%: $(PTMPROOT)/%
	@$(MKDIR) $(@D)
# unless verbose, don't report an error from this ln
ifeq ($(verbose),)
	ln -f $< $@ >& /dev/null || $(LOCALCP) $< $@
else
	ln -f $< $@ || $(LOCALCP) $< $@
endif
	@echo Created $@ from $<

#the dot variables
.LOW_RESOLUTION_TIME: $(WORKROOT)/% $(PTMPROOT)/%
.PRECIOUS: $(PTMPROOT)/%
.SUFFIXES:
.SUFFIXES: .cpio .ok .tar
