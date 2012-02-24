# -*- Makefile -*-
# $Id: hsmget.mk,v 1.1.4.15.4.1 2013/03/27 23:24:27 afy Exp $
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
ptmptmp := $(PTMPROOT)/tmp/$(uuid)

#filesystem where arch and ptmp reside, assume /arch and /ptmp|/work
archfs := $(shell echo $(ARCHROOT) | cut -c2-5)
ptmpfs := $(shell echo $(PTMPROOT) | cut -c2-5)
ifeq ($(archfs),arch)
ifeq ($(ptmpfs),ptmp)
#GFDL host for data transfer optimization
dtn := cdtn.lb.princeton.rdhpcs.noaa.gov
dtn := $(shell host $(dtn) | head -n 1 | cut -f4 -d\  )
# delay is used at GFDL to get over the NFS file-cache problem
DELAY := && sleep 70
else ifeq ($(ptmpfs),work)
#GFDL host for data transfer optimization
dtn := cdtn.lb.princeton.rdhpcs.noaa.gov
dtn := $(shell host $(dtn) | head -n 1 | cut -f4 -d\  )
# delay is used at GFDL to get over the NFS file-cache problem
DELAY := && sleep 70
endif
endif

ifdef dtn
checkdtn := $(shell ssh $(dtn) pwd\; hostname)
# dtn is defined at this point if writing from /archive to /ptmp or /work
endif

# commands: these are all the external dependencies
# (some of these could have further dependencies within them...)
# should come from FRE *site* configuration
commands :=
ifneq ($(time),)
#timer
TIMECMD := /usr/bin/time
commands += $(firstword $(TIMECMD))
endif
# remote copy
# TODO: rename as REMOTEGET or something...
# in hpcs/hsmget.mk, REMOTECP is arch->ptmp, LOCALCP is ptmp->work
# may need the same here: we're assuming that ptmp is writable by user
# but it may not be if arch->ptmp uses ln
REMOTEID = gaea:
LOCALID = # cmrs:
# LOCALID =
GCP ?= gcp
GCPOPTS := # --disable-checksum
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
ifeq ($(verbose),)
LOCALCP ?= $(GCP) $(GCPOPTS) --quiet
else
LOCALCP ?= $(GCP) $(GCPOPTS) --verbose
endif
commands += $(firstword $(LOCALCP))
ifneq ($(time),)
#timer
LOCALCP := $(TIMECMD) -f "$(firstword $(LOCALCP)) took %e secs." $(LOCALCP)
endif
# get from tape
DEEPGET := dmget
commands += $(firstword $(DEEPGET))
ifneq ($(time),)
#timer
DEEPGET := $(TIMECMD) -f "$(firstword $(DEEPGET)) took %e secs." $(DEEPGET)
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
ifdef dtn
SUM := ssh $(dtn) cd `pwd`\; $(SUM)
endif
ifneq ($(time),)
#timer
SUM := $(TIMECMD) -f "md5sum took %e secs." $(SUM)
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
ifdef dtn
CPIO := ssh $(dtn) cd `pwd`\; $(CPIO)
endif
ifneq ($(time),)
#timer
CPIO := $(TIMECMD) -f "cpio took %e secs." $(CPIO)
endif
#tar
TAR := tar $(verbose) -b 1024 -xf
commands += $(firstword $(TAR))
ifdef dtn
TAR := ssh $(dtn) cd `pwd`\; $(TAR)
endif
ifneq ($(time),)
#timer
TAR := $(TIMECMD) -f "tar took %e secs." $(TAR)
endif
#mkdir
MKDIR = mkdir -p
commands += $(firstword $(MKDIR))
#find: one level only
FIND = find -L
FINDFLAGS = -maxdepth 1 -type f
commands += $(firstword $(FIND))
# rm and mv
RM := rm
MV := mv
ifdef dtn
RM := ssh $(dtn) $(RM)
MV := ssh $(dtn) $(MV)
endif


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
	@echo ptmptmp = $(ptmptmp)
	@echo dtn = $(dtn) archfs = $(archfs) ptmpfs = $(ptmpfs)
	@echo $(checkdtn)
which:
	@echo Command paths: $(shell which $(commands))
# data movement: this is HSMget/put
# for remote get you may need to preface target with $(REMOTEID)
# the extra / after $(REMOTEID) is because hsmget starts from a relpath
ifneq ($(force),)
$(ARCHROOT)/%:
	@$(MKDIR) $(@D)
	cd $(ARCHROOT) && $(REMOTECP) $(REMOTEID)/$* $(LOCALID)$@
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
	$(DEEPGET) $<
	-test -f $< && $(MKDIR) $(@D) && $(LOCALCP) `$(RESOLVE) $<` $(@D) || \
	 test -d $< && $(MKDIR) $(PTMPROOT)/$* && $(LOCALCP) `$(FIND) $< $(FINDFLAGS)` $(PTMPROOT)/$* $(DELAY)
ifneq ($(check),)
	-test -f $< && cd $(@D) && $(SUM) $(*F) > $@ && cd $(<D) && $(CHECK) $@ || \
	test -d $< && cd $(PTMPROOT)/$* && $(SUM) `$(FIND) . $(FINDFLAGS)` > $@ && cd $< && $(CHECK) $@
else
	touch $@
endif
	echo Created $(PTMPROOT)/$* from $<
	@$(RM) -f $@.LOCK
$(PTMPROOT)/%.ok: $(ARCHROOT)/%.tar
	@touch $@.LOCK
	$(DEEPGET) $<
	$(RM) -rf $(PTMPROOT)/$*
	@$(MKDIR) $(PTMPROOT)/$* $(ptmptmp)
# if dtn defined do everything on dtn servers
ifdef dtn
	cd $(ptmptmp) && $(TAR) $< && $(MV) -f $(ptmptmp)/* $(PTMPROOT)/$* && $(RM) -rf $(ptmptmp) $(DELAY)
else
	$(LOCALCP) $< $(ptmptmp)
	cd $(ptmptmp) && $(TAR) $(<F) && $(RM) -f $(ptmptmp)/$(<F) && $(MV) -f $(ptmptmp)/* $(PTMPROOT)/$* && $(RM) -rf $(ptmptmp) $(DELAY)
endif
ifneq ($(check),)
	cd $(PTMPROOT)/$* && $(SUM) `$(FIND) . -type f` > $@
else
	touch $@
endif
	@echo Created $(PTMPROOT)/$* from $<
	@$(RM) -f $@.LOCK
$(PTMPROOT)/%.ok: $(ARCHROOT)/%.nc.tar
	@touch $@.LOCK
	$(DEEPGET) $<
	$(RM) -rf $(PTMPROOT)/$*
	@$(MKDIR) $(PTMPROOT)/$* $(ptmptmp)
# if dtn defined do everything on dtn servers
ifdef dtn
	cd $(ptmptmp) && $(TAR) $< && $(MV) -f $(ptmptmp)/* $(PTMPROOT)/$* && $(RM) -rf $(ptmptmp) $(DELAY)
else
	$(LOCALCP) $< $(ptmptmp)
	cd $(ptmptmp) && $(TAR) $(<F) && $(RM) -f $(ptmptmp)/$(<F) && $(MV) -f $(ptmptmp)/* $(PTMPROOT)/$* && $(RM) -rf $(ptmptmp) $(DELAY)
endif
ifneq ($(check),)
	cd $(PTMPROOT)/$* && $(SUM) `$(FIND) . -type f` > $@
else
	touch $@
endif
	@echo Created $(PTMPROOT)/$* from $<
	@$(RM) -f $@.LOCK
$(PTMPROOT)/%.ok: $(ARCHROOT)/%.cpio
	@touch $@.LOCK
	$(DEEPGET) $<
	$(RM) -rf $(PTMPROOT)/$*
	@$(MKDIR) $(PTMPROOT)/$* $(ptmptmp)
# if dtn defined do everything on dtn servers
ifdef dtn
	cd $(ptmptmp) && $(CPIO) $< && $(MV) -f $(ptmptmp)/* $(PTMPROOT)/$* && $(RM) -rf $(ptmptmp) $(DELAY)
else
	$(LOCALCP) $< $(ptmptmp)
	cd $(ptmptmp) && $(CPIO) $(<F) && $(RM) -f $(ptmptmp)/$(<F) && $(MV) -f $(ptmptmp)/* $(PTMPROOT)/$* && $(RM) -rf $(ptmptmp) $(DELAY)
endif
# 	test -d $@ && cd $@ && $(CPIO) $< || \
# 	test -f $@ || $(MKDIR) $@ && cd $@ && $(CPIO) $<
ifneq ($(check),)
	cd $(PTMPROOT)/$* && $(SUM) `$(FIND) . -type f` > $@
else
	touch $@
endif
	@echo Created $(PTMPROOT)/$* from $<
	@$(RM) -f $@.LOCK
$(PTMPROOT)/%.ok: $(ARCHROOT)/%.nc.cpio
	@touch $@.LOCK
	$(DEEPGET) $<
	$(RM) -rf $(PTMPROOT)/$*
	@$(MKDIR) $(PTMPROOT)/$* $(ptmptmp)
# if dtn defined do everything on dtn servers
ifdef dtn
	cd $(ptmptmp) && $(CPIO) $< && $(MV) -f $(ptmptmp)/* $(PTMPROOT)/$* && $(RM) -rf $(ptmptmp) $(DELAY)
else
	$(LOCALCP) $< $(ptmptmp)
	cd $(ptmptmp) && $(CPIO) $(<F) && $(RM) -f $(ptmptmp)/$(<F) && $(MV) -f $(ptmptmp)/* $(PTMPROOT)/$* && $(RM) -rf $(ptmptmp) $(DELAY)
endif
# 	test -d $@ && cd $@ && $(CPIO) $< || \
# 	test -f $@ || $(MKDIR) $@ && cd $@ && $(CPIO) $<
ifneq ($(check),)
	cd $(PTMPROOT)/$* && $(SUM) `$(FIND) . -type f` > $@
else
	touch $@
endif
	@echo Created $(PTMPROOT)/$* from $<
	@$(RM) -f $@.LOCK

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
