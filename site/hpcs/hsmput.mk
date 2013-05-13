# $Id: hsmput.mk,v 18.0.2.1 2010/03/17 16:03:02 arl Exp $
# hsmget.mk: data transfer using three-level storage model

#use csh, with no user .cshrc
SHELL = /bin/csh -f

#verbose flag: set to -v to get verbose commans
verbose =
#timer off by default
time =
#flag to force remote archival, non-empty string means ON
force =
#flag to turn on checksums
check =

# commands: these are all the external dependencies
commands :=
# (some of these could have further dependencies within them...)
# should come from FRE *site* configuration
TIMECMD = /usr/bin/time
commands += $(firstword $(TIMECMD))
# remote copy: remote ID could be a host-user combination
REMOTEID =
# optimization flags for cxfscp
CPOPTS = -t 1 -b 8 -s 65000
REMOTECP ?= cxfscp $(CPOPTS) -upr $(verbose)
commands += $(firstword $(REMOTECP))
ifneq ($(time),)
#timer
REMOTECP := $(TIMECMD) -f "$(firstword $(REMOTECP)) took %e secs." $(REMOTECP)
endif
# put to deep storage
DEEPPUT ?= dmput $(verbose)
commands += $(firstword $(DEEPPUT))
ifneq ($(time),)
#timer
DEEPPUT := $(TIMECMD) -f "$(firstword $(DEEPPUT)) took %e secs." $(DEEPPUT)
endif
# fast copy
LOCALCP ?= cxfscp $(CPOPTS) -upr $(verbose)
commands += $(firstword $(LOCALCP))
ifneq ($(time),)
#timer
LOCALCP := $(TIMECMD) -f "$(firstword $(LOCALCP)) took %e secs." $(LOCALCP)
endif
#checksum, written to okfile
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
CPIO := cpio $(verbose) -o -O
commands += $(firstword $(CPIO))
ifneq ($(time),)
#timer
CPIO := $(TIMECMD) -f "$(firstword $(CPIO)) took %e secs." $(CPIO)
endif
#tar
TAR := tar $(verbose) -b 1024 -cf
commands += $(firstword $(TAR))
ifneq ($(time),)
#timer
TAR := $(TIMECMD) -f "$(firstword $(TAR)) took %e secs." $(TAR)
endif
#mkdir
MKDIR = mkdir -p
commands += $(firstword $(MKDIR))

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

# moving from WORK to ARCH
$(ARCHROOT)/%.ok: $(WORKROOT)/%
	@$(MKDIR) $(@D)
	$(REMOTECP) $< $(@D)
ifneq ($(check),)
	-test -d $< && cd $< && $(SUM) `find . -type f` > $@ || \
	 test -f $< && cd $(<D) && $(SUM) $(<F) > $@
else
	touch $@
endif
ifneq ($(force),)
	-test -f $(ARCHROOT)/$* && $(DEEPPUT) $(ARCHROOT)/$*
endif
	@echo Created $(ARCHROOT)/$* from $<
#moving from WORK to PTMP
$(PTMPROOT)/%.ok: $(WORKROOT)/%
	@$(MKDIR) $(@D)
	$(LOCALCP) $< $(@D)
	-@test -d $(PTMPROOT)/$* && touch $(PTMPROOT)/$*
ifneq ($(check),)
	-test -d $< && cd $< && $(SUM) `find . -type f` > $@ || \
	 test -f $< && cd $(<D) && $(SUM) $(<F) > $@
else
	touch $@
endif
	@echo Created $(PTMPROOT)/$* from $<

#operations on WORK
$(WORKROOT)/%.cpio: $(WORKROOT)/%
ifneq ($(check),)
# we create okfile in .. and then copy it in; otherwise it tries to checksum itself
	-test -d $< && cd $< && $(SUM) `find . -type f` > ../$(*F).ok && \
	 ln -f ../$(*F).ok . && find . -type f | $(CPIO) $@
else
	-test -d $< && cd $< && find . -type f | $(CPIO) $@
endif
	@echo Created $@ from $<
$(WORKROOT)/%.tar: $(WORKROOT)/%
ifneq ($(check),)
# we create okfile in .. and then copy it in; otherwise it tries to checksum itself
	-test -d $< && cd $< && $(SUM) `find . -type f` > ../$(*F).ok && \
	ln ../$(*F).ok . && $(TAR) $@ .
else
	-test -d $< && cd $< && $(TAR) $@ .
endif
	@echo Created $@ from $<

#the dot variables
.LOW_RESOLUTION_TIME: $(PTMPROOT)/% $(WORKROOT)/%.cpio $(WORKROOT)/%.tar
.PRECIOUS: $(PTMPROOT)/% $(WORKROOT)/%.cpio $(WORKROOT)/%.tar
.SUFFIXES:
.SUFFIXES: .cpio .ok .tar
