# $Id: hsmput.mk,v 1.1.2.2 2011/04/01 18:00:58 afy Exp $
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
#remote path, if non-blank this is used for remote archival
remotepath =
# commands: these are all the external dependencies
# (some of these could have further dependencies within them...)
# should come from FRE *site* configuration
ifneq ($(time),)
#timer
TIMECMD := /usr/bin/time
commands += $(firstword $(TIMECMD))
endif
# remote copy
REMOTEID = # gfdl:
LOCALID = # cmrs:
GCP ?= gcp
GCPOPTS := -cd --disable-checksum
ifeq ($(verbose),)
REMOTECP ?= gmpscp --quiet
else
REMOTECP ?= gmpscp --debug
endif
commands += $(firstword $(REMOTECP))
ifneq ($(time),)
#timer
REMOTECP := $(TIMECMD) -f "$(firstword $(REMOTECP)) took %e secs." $(REMOTECP)
endif
# put to remote host
DEEPPUT = ssh gfdl dmput $(verbose)
commands += $(firstword $(DEEPPUT))
ifneq ($(time),)
#timer
DEEPPUT := $(TIMECMD) -f "$(firstword $(DEEPPUT)) took %e secs." $(DEEPPUT)
endif
# use localcp on same filesystem
LOCALCP = cp -p -r $(verbose) #/bin/ln
commands += $(firstword $(LOCALCP))
ifneq ($(time),)
#timer
LOCALCP := $(TIMECMD) -f "$(firstword $(LOCALCP)) took %e secs." $(LOCALCP)
endif
#checksum file
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
CPIO = cpio $(verbose) -C 524288 -o -O
commands += $(firstword $(CPIO))
ifneq ($(time),)
#timer
CPIO := $(TIMECMD) -f "$(firstword $(CPIO)) took %e secs." $(CPIO)
endif
#tar
TAR = tar $(verbose) -b 1024 -cf
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
	$(LOCALCP) $< $(@D)
ifneq ($(check),)
	-test -d $< && cd $< && $(SUM) `find . -type f` > $@ || \
	 test -f $< && cd $(<D) && $(SUM) $(<F) > $@
else
	touch $@
endif
	echo Created $(ARCHROOT)/$* from $<
# if the variable remotepath is passed in, this attempts a copy
# currently only for tar/cpio (see test -f below) but could move dirs
#   as well, (but gcp currently doesn't)
ifneq ($(remotepath),)
	test -f $(ARCHROOT)/$* && $(REMOTECP) $(LOCALID)$(ARCHROOT)/$* $(REMOTEID)$(remotepath)/
	@echo Created $(REMOTEID)$(remotepath) from $(ARCHROOT)/$*
endif
#moving from WORK to PTMP
$(PTMPROOT)/%.ok: $(WORKROOT)/%
# unless verbose, don't report an error from this ln
ifeq ($(verbose),)
	-( test -d $< && mkdir -p $(PTMPROOT)/$* && ln -f -t $(PTMPROOT)/$* `find $< -maxdepth 1 -type f` >& /dev/null ) || \
	 ( test -f $< && mkdir -p $(@D) && ln -f -t $(@D) `find $< -maxdepth 1 -type f` >& /dev/null ) || \
	 $(LOCALCP) $< $(@D)
else
	-( test -d $< && mkdir -p $(PTMPROOT)/$* && ln -f -t $(PTMPROOT)/$* `find $< -maxdepth 1 -type f` ) || \
	 ( test -f $< && mkdir -p $(@D) && ln -f -t $(@D) `find $< -maxdepth 1 -type f` ) || \
	 $(LOCALCP) $< $(@D)
endif
ifneq ($(check),)
	-test -d $< && cd $< && $(SUM) `find . -type f` > $@ || \
	 test -f $< && cd $(<D) && $(SUM) $(<F) > $@
else
	touch $@
endif
	echo Created $(PTMPROOT)/$* from $<

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
