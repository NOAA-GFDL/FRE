# -*- Makefile -*-
# $Id: hsmget.mk,v 1.1.2.5.2.1 2013/03/27 23:26:50 afy Exp $
# data transfer using three-level storage model

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

# random string for names, different for each invocation of hsmget.mk
uuid := $(shell uuidgen)
ptmptmp := $(PTMPROOT)/tmp/$(uuid)

# if the ptmp filesystem = NFS, then copy/move/remove ptmp data on a DTN
ptmpfstype := $(shell df -PT /$(shell echo $(PTMPROOT) | cut -d/ -f2) | tail -n 1 | cut -d' ' -f2)

ifeq ($(ptmpfstype),nfs)
  # GFDL host for data transfer optimization
  balancer := cdtn.lb.princeton.rdhpcs.noaa.gov
  dtn := $(shell host $(balancer) | head -n 1 | cut -d' ' -f4)
  # delay is used at GFDL to get over the NFS file-cache problem
  DELAY := sleep 70
else
  DELAY := sleep 0
endif

# commands: these are all the external dependencies
# (some of these could have further dependencies within them...)
# should come from FRE *site* configuration
commands :=
ifneq ($(time),)
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
  REMOTECP := $(TIMECMD) -f "$(firstword $(REMOTECP)) took %e secs." $(REMOTECP)
endif

# local copy
ifeq ($(verbose),)
  LOCALCP ?= $(GCP) $(GCPOPTS) --quiet
else
  LOCALCP ?= $(GCP) $(GCPOPTS) --verbose
endif
commands += $(firstword $(LOCALCP))
ifneq ($(time),)
  LOCALCP := $(TIMECMD) -f "$(firstword $(LOCALCP)) took %e secs." $(LOCALCP)
endif

# get from tape
DEEPGET := dmget
commands += $(firstword $(DEEPGET))
ifneq ($(time),)
  DEEPGET := $(TIMECMD) -f "$(firstword $(DEEPGET)) took %e secs." $(DEEPGET)
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
  SUM := $(TIMECMD) -f "md5sum took %e secs." $(SUM)
endif

# checksum, read from ok file
CHECK := md5sum -c
commands += $(firstword $(CHECK))
ifneq ($(time),)
  CHECK := $(TIMECMD) -f "$(firstword $(CHECK)) took %e secs." $(CHECK)
endif

# cpio
#Balaji 2008-08-13, removed -mu, problem if extracted file is older than source
CPO := cpio -C 524288 $(verbose) -i -I
commands += $(firstword $(CPO))
ifneq ($(time),)
  CPO := $(TIMECMD) -f "cpio took %e secs." $(CPO)
endif

# tar
TAR := tar $(verbose) -b 1024 -xf
commands += $(firstword $(TAR))
ifneq ($(time),)
  TAR := $(TIMECMD) -f "tar took %e secs." $(TAR)
endif

# mkdir
MKDIR = mkdir -p
commands += $(firstword $(MKDIR))

# find: one level only
FIND = find -L
FINDFLAGS = -maxdepth 1 -type f
commands += $(firstword $(FIND))

# rm
RM := rm -rf
commands += $(firstword $(RM))

# mv
MV := mv -f
commands += $(firstword $(MV))

# ssh
SSH := gsissh -oForwardX11=no
commands += $(firstword $(SSH))

# Directory trees in home, archive, ptmp, home follow identical
# tree below the root directory, typically something like
# ARCHROOT = /archive/$(USER)
# PTMPROOT = /work/$(USER)
# WORKROOT = $(TMPDIR)
# you can set these as environment variables or pass them to make:
# e.g make ARCHROOT=/archive/foo -f hsmget.mk

# first target
what:
	@echo Using Makefile $(firstword $(MAKEFILE_LIST)) ...
	@echo "ARCHROOT   = $(ARCHROOT)"
	@echo "PTMPROOT   = $(PTMPROOT)"
	@echo "WORKROOT   = $(WORKROOT)"
	@echo "ptmptmp    = $(ptmptmp)"
	@echo "ptmpfstype = $(ptmpfstype)"
	@echo "dtn        = $(dtn)"

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
# TODO: need to include .tar.gz?

# 20090508: tar/cpio unpacking is now followed by touching an ok file
# to ensure that the unpacking actually finished, the direct approach
# had problems if you ^C'd in the middle of an untar...

FINALCOPY = $(MKDIR) $(PTMPROOT)/$* && (set nonomatch; $(RM) $(PTMPROOT)/$*/*) && $(MV) $(ptmptmp)/* $(PTMPROOT)/$*

TARCOPY_DIRECT = $(MKDIR) $(ptmptmp) && (cd $(ptmptmp); $(TAR) $<) && $(FINALCOPY) && $(RM) $(ptmptmp)
TARCOPY_STAGED = $(MKDIR) $(ptmptmp) && $(LOCALCP) $< $(ptmptmp) && (cd $(ptmptmp); $(TAR) $(<F)) && $(RM) $(ptmptmp)/$(<F) && $(FINALCOPY) && $(RM) $(ptmptmp)

CPOCOPY_DIRECT = $(MKDIR) $(ptmptmp) && (cd $(ptmptmp); $(CPO) $<) && $(FINALCOPY) && $(RM) $(ptmptmp)
CPOCOPY_STAGED = $(MKDIR) $(ptmptmp) && $(LOCALCP) $< $(ptmptmp) && (cd $(ptmptmp); $(CPO) $(<F)) && $(RM) $(ptmptmp)/$(<F) && $(FINALCOPY) && $(RM) $(ptmptmp)

CHKSUM = cd $(PTMPROOT)/$* && $(SUM) `$(FIND) . $(FINDFLAGS)`

$(PTMPROOT)/%.ok: $(ARCHROOT)/%
	$(DEEPGET) $<
	-test -f $< && $(MKDIR) $(@D) && $(LOCALCP) `$(RESOLVE) $<` $(@D) || \
	 test -d $< && $(MKDIR) $(PTMPROOT)/$* && $(LOCALCP) `$(FIND) $< $(FINDFLAGS)` $(PTMPROOT)/$*
	$(DELAY)
  ifneq ($(check),)
	-test -f $< && cd $(@D) && $(SUM) $(*F) > $@ && cd $(<D) && $(CHECK) $@ || \
	 test -d $< && cd $(PTMPROOT)/$* && $(SUM) `$(FIND) . $(FINDFLAGS)` > $@ && cd $< && $(CHECK) $@
  else
	touch $@
  endif
	echo Created $(PTMPROOT)/$* from $<

$(PTMPROOT)/%.ok: $(ARCHROOT)/%.tar
	$(DEEPGET) $<
  ifdef dtn
	$(SSH) $(dtn) '$(TARCOPY_DIRECT)'
  else
	$(TARCOPY_STAGED)
  endif
	$(DELAY)
  ifneq ($(check),)
	$(CHKSUM) > $@
  else
	touch $@
  endif
	@echo Created $(PTMPROOT)/$* from $<

$(PTMPROOT)/%.ok: $(ARCHROOT)/%.nc.tar
	$(DEEPGET) $<
  ifdef dtn
	$(SSH) $(dtn) '$(TARCOPY_DIRECT)'
  else
	$(TARCOPY_STAGED)
  endif
	$(DELAY)
  ifneq ($(check),)
	$(CHKSUM) > $@
  else
	touch $@
  endif
	@echo Created $(PTMPROOT)/$* from $<

$(PTMPROOT)/%.ok: $(ARCHROOT)/%.cpio
	$(DEEPGET) $<
  ifdef dtn
	$(SSH) $(dtn) '$(CPOCOPY_DIRECT)'
  else
	$(CPOCOPY_STAGED)
  endif
	$(DELAY)
  ifneq ($(check),)
	$(CHKSUM) > $@
  else
	touch $@
  endif
	@echo Created $(PTMPROOT)/$* from $<

$(PTMPROOT)/%.ok: $(ARCHROOT)/%.nc.cpio
	$(DEEPGET) $<
  ifdef dtn
	$(SSH) $(dtn) '$(CPOCOPY_DIRECT)'
  else
	$(CPOCOPY_STAGED)
  endif
	$(DELAY)
  ifneq ($(check),)
	$(CHKSUM) > $@
  else
	touch $@
  endif
	@echo Created $(PTMPROOT)/$* from $<

# moving from PTMP to WORK
$(WORKROOT)/%: $(PTMPROOT)/%
	$(MKDIR) $(@D)
	ln -f $< $@ >& /dev/null || $(LOCALCP) $< $@
	chmod a-w $<
	@echo Created $@ from $<

# the dot variables
.LOW_RESOLUTION_TIME: $(WORKROOT)/% $(PTMPROOT)/%
.PRECIOUS: $(PTMPROOT)/%
.SUFFIXES:
.SUFFIXES: .cpio .ok .tar
