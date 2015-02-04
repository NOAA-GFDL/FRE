# -*- Makefile -*-
# $Id: hsmget.mk,v 18.0.2.1 2010/03/17 16:04:23 arl Exp $
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
REMOTEID = $(GFDLUSER)@p-09.rdhpcs.noaa.gov:/staging-1/$(GFDLUSER)
#20090526, using the force option because bbcp is only invoked by hsmget -f
REMOTECP ??= bbcp -f $(verbose) # no recursive copy
commands += $(firstword $(REMOTECP))
ifneq ($(time),)
#timer
REMOTECP := $(TIMECMD) -f "$(firstword $(REMOTECP)) took %e secs." $(REMOTECP)
endif
# retrieve from deep storage on remote host
DEEPGET ?= hsi -q $(verbose) get -p -u
commands += $(firstword $(DEEPGET))
ifneq ($(time),)
#timer
DEEPGET := $(TIMECMD) -f "$(firstword $(DEEPGET)) took %e secs." $(DEEPGET)
endif
DEEPPUT = hsi -q $(verbose) put -P -p -u
commands += $(firstword $(DEEPGET))
# use localcp on same filesystem
LOCALCP = ln -f --backup=numbered $(verbose) #/bin/ln
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
SUM = md5sum -b
commands += $(firstword $(SUM))
ifneq ($(time),)
#timer
SUM := $(TIMECMD) -f "$(firstword $(SUM)) took %e secs." $(SUM)
endif
#checksum, read from ok file
CHECK = md5sum -c
commands += $(firstword $(CHECK))
ifneq ($(time),)
#timer
CHECK := $(TIMECMD) -f "$(firstword $(CHECK)) took %e secs." $(CHECK)
endif
#cpio
#Balaji 2008-08-13, removed -mu, problem if extracted file is older than source
CPIO = cpio $(verbose) -i -I
commands += $(firstword $(CPIO))
ifneq ($(time),)
#timer
CPIO := $(TIMECMD) -f "$(firstword $(CPIO)) took %e secs." $(CPIO)
endif
#tar: use htar? TODO
TAR = tar $(verbose) -b 1024 -xf
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
which:
	@echo Command paths: $(shell which $(commands))
# data movement: this is HSMget/put but depends on some FRE variables to define
# source/target correspondence.
# for remote get you may need to preface target with $(REMOTEID)
ifneq ($(force),)
$(ARCHROOT)/%:
	@$(MKDIR) $(@D)
	-cd $(ARCHROOT) && $(DEEPGET) $* || $(REMOTECP) $(REMOTEID)/$* $@ && $(DEEPPUT) $@ : $*
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
	-test -f $< && $(MKDIR) $(@D) && $(LOCALCP) `$(RESOLVE) $<` $(@D) || \
	 test -d $< && $(MKDIR) $(PTMPROOT)/$* && $(LOCALCP) `$(FIND) $< $(FINDFLAGS)` $(PTMPROOT)/$*
ifneq ($(check),)
	-test -f $< && cd $(@D) && $(SUM) $(*F) > $@ && cd $(<D) && $(CHECK) $@ || \
	test -d $< && cd $(PTMPROOT)/$* && $(SUM) `$(FIND) . $(FINDFLAGS)` > $@ && cd $< && $(CHECK) $@
else
	touch $@
endif
# at this point (since LOCALCP=ln) we aren't using the same
# PTMPROOT/tmp/uuid method we used in hpcs/hsmget.mk
$(PTMPROOT)/%.ok: $(ARCHROOT)/%.tar
	@$(MKDIR) $(PTMPROOT)/$*
	cd $(PTMPROOT)/$* && $(TAR) $<
ifneq ($(check),)
	cd $(PTMPROOT)/$* && $(SUM) `$(FIND) . -type f` > $@
else
	touch $@
endif
$(PTMPROOT)/%.ok: $(ARCHROOT)/%.nc.tar
	@$(MKDIR) $(PTMPROOT)/$*
	cd $(PTMPROOT)/$* && $(TAR) $<
ifneq ($(check),)
	cd $(PTMPROOT)/$* && $(SUM) `$(FIND) . -type f` > $@
else
	touch $@
endif
$(PTMPROOT)/%.ok: $(ARCHROOT)/%.cpio
	@$(MKDIR) $(PTMPROOT)/$*
	cd $(PTMPROOT)/$* && $(CPIO) $<
ifneq ($(check),)
	cd $(PTMPROOT)/$* && $(SUM) `$(FIND) . -type f` > $@
else
	touch $@
endif
$(PTMPROOT)/%.ok: $(ARCHROOT)/%.nc.cpio
	@$(MKDIR) $(PTMPROOT)/$*
	cd $(PTMPROOT)/$* && $(CPIO) $<
ifneq ($(check),)
	cd $(PTMPROOT)/$* && $(SUM) `$(FIND) . -type f` > $@
else
	touch $@
endif

#moving from PTMP to WORK
$(WORKROOT)/%: $(PTMPROOT)/%
	@$(MKDIR) $(@D)
	$(LOCALCP) `$(RESOLVE) $<` $@

#the dot variables
.LOW_RESOLUTION_TIME: $(WORKROOT)/% $(PTMPROOT)/%
.PRECIOUS: $(PTMPROOT)/%
.SUFFIXES:
.SUFFIXES: .cpio .ok .tar
