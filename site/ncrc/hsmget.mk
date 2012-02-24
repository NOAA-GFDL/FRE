# -*- Makefile -*-
# $Id: hsmget.mk,v 1.1.2.15.6.1 2013/03/27 23:47:03 afy Exp $
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
# remote host for operations
dtn := rdtn.lb.princeton.rdhpcs.noaa.gov
dtn := $(shell host $(dtn) | head -n 1 | cut -f4 -d\  )
# live will fail if link is down
live = $(shell gsissh $(dtn) hostname\; pwd)
# remote copy
# TODO: rename as REMOTEGET or something...
# in hpcs/hsmget.mk, REMOTECP is arch->ptmp, LOCALCP is ptmp->work
# may need the same here: we're assuming that ptmp is writable by user
# but it may not be if arch->ptmp uses ln
REMOTEID = gfdl:
LOCALID = # cmrs:
# LOCALID =
GCP ?= gcp
GCPOPTS := --disable-checksum
ifeq ($(verbose),)
REMOTECP ?= $(GCP) $(GCPOPTS) --quiet
else
REMOTECP ?= $(GCP) $(GCPOPTS) --verbose
endif
commands += $(firstword $(REMOTECP))
ifneq ($(time),)
#timer
REMOTECP := $(TIMECMD) -f "$(firstword $(REMOTECP)) took %e secs." $(REMOTECP)
endif
# use localcp between LTFS and FS
LOCALCP ?= cp -f --preserve=mode,timestamps $(verbose) #/bin/ln
commands += $(firstword $(LOCALCP))
ifneq ($(time),)
#timer
LOCALCP := $(TIMECMD) -f "$(firstword $(LOCALCP)) took %e secs." $(LOCALCP)
endif
# resolve symbolic links
RESOLVE = readlink -f
commands += $(firstword $(RESOLVE))
ifneq ($(time),)
#timer
RESOLVE := $(TIMECMD) -f "$(firstword $(RESOLVE)) took %e secs." $(RESOLVE)
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
CPIO := cpio -C 524288 $(verbose) -i -I
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
	@echo dtn = $(dtn)
	@echo $(live)
which:
	@echo Command paths: $(shell which $(commands))
# data movement: this is HSMget/put
# for remote get you may need to preface target with $(REMOTEID)
# the extra / after $(REMOTEID) is because hsmget starts from a relpath
ifneq ($(force),)
$(ARCHROOT)/%:
	@$(MKDIR) $(@D)
#ifneq ($(check),)
#	$(REMOTECMD) test -f /$*.ok && echo ok
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
#TODO: need to include .tar.gz?

#20090508: tar/cpio unpacking is now followed by touching an ok file
#to ensure that the unpacking actually finished, the direct approach
#had problems if you ^C'd in the middle of an untar...
$(PTMPROOT)/%.ok: $(ARCHROOT)/%
	@touch $@.LOCK
	-test -f $< && $(MKDIR) $(@D) && $(LOCALCP) `$(RESOLVE) $<` $(@D) || \
	 test -d $< && $(MKDIR) $(PTMPROOT)/$* && $(LOCALCP) `$(FIND) $< $(FINDFLAGS)` $(PTMPROOT)/$*
ifneq ($(check),)
	-test -f $< && cd $(@D) && $(SUM) $(*F) > $@ && cd $(<D) && $(CHECK) $@ || \
	test -d $< && cd $(PTMPROOT)/$* && $(SUM) `$(FIND) . $(FINDFLAGS)` > $@ && cd $< && $(CHECK) $@
else
	touch $@
endif
	echo Created $(PTMPROOT)/$* from $<
	@rm -f $@.LOCK
$(PTMPROOT)/%.ok: $(ARCHROOT)/%.tar
	@touch $@.LOCK
	rm -rf $(PTMPROOT)/$*
	@$(MKDIR) $(PTMPROOT)/$* $(PTMPROOT)/tmp/$(uuid)
	cd $(PTMPROOT)/tmp/$(uuid) && $(TAR) $< && mv -f $(PTMPROOT)/tmp/$(uuid)/* $(PTMPROOT)/$* && rm -rf $(PTMPROOT)/tmp/$(uuid)
ifneq ($(check),)
	cd $(PTMPROOT)/$* && $(SUM) `$(FIND) . -type f` > $@
else
	touch $@
endif
	@echo Created $(PTMPROOT)/$* from $<
	@rm -f $@.LOCK
$(PTMPROOT)/%.ok: $(ARCHROOT)/%.nc.tar
	@touch $@.LOCK
	rm -rf $(PTMPROOT)/$*
	@$(MKDIR) $(PTMPROOT)/$* $(PTMPROOT)/tmp/$(uuid)
	cd $(PTMPROOT)/tmp/$(uuid) && $(TAR) $< && mv -f $(PTMPROOT)/tmp/$(uuid)/* $(PTMPROOT)/$* && rm -rf $(PTMPROOT)/tmp/$(uuid)
ifneq ($(check),)
	cd $(PTMPROOT)/$* && $(SUM) `$(FIND) . -type f` > $@
else
	touch $@
endif
	@echo Created $(PTMPROOT)/$* from $<
	@rm -f $@.LOCK
$(PTMPROOT)/%.ok: $(ARCHROOT)/%.cpio
	@touch $@.LOCK
	rm -rf $(PTMPROOT)/$*
	@$(MKDIR) $(PTMPROOT)/$* $(PTMPROOT)/tmp/$(uuid)
	cd $(PTMPROOT)/tmp/$(uuid) && $(CPIO) $< && mv -f $(PTMPROOT)/tmp/$(uuid)/* $(PTMPROOT)/$* && rm -rf $(PTMPROOT)/tmp/$(uuid)
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
	rm -rf $(PTMPROOT)/$*
	@$(MKDIR) $(PTMPROOT)/$* $(PTMPROOT)/tmp/$(uuid)
	cd $(PTMPROOT)/tmp/$(uuid) && $(CPIO) $< && mv -f $(PTMPROOT)/tmp/$(uuid)/* $(PTMPROOT)/$* && rm -rf $(PTMPROOT)/tmp/$(uuid)
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
	chmod a-w $<
	@echo Created $@ from $<

#the dot variables
.LOW_RESOLUTION_TIME: $(WORKROOT)/% $(PTMPROOT)/%
.PRECIOUS: $(PTMPROOT)/%
.SUFFIXES:
.SUFFIXES: .cpio .ok .tar
