# $Id: hsmput.mk,v 18.0.2.1 2010/03/17 16:04:23 arl Exp $
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
# (some of these could have further dependencies within them...)
# should come from FRE *site* configuration
ifneq ($(time),)
#timer
TIMECMD = /usr/bin/time -f "Command took %E secs."
commands += $(firstword $(TIMECMD))
endif
# remote copy
REMOTEID = $(GFDLUSER)@p-09.rdhpcs.noaa.gov:/staging-1/$(GFDLUSER)
#20090526, using the force option because bbcp is only invoked by hsmget -f
REMOTECP = bbcp -f $(verbose) # no recursive copy
commands += $(firstword $(REMOTECP))
# retrieve from deep storage on remote host
DEEPGET = hsi -q $(verbose) get -p
commands += $(firstword $(DEEPGET))
DEEPPUT = hsi -q $(verbose) put -P -p -u -r
commands += $(firstword $(DEEPGET))
# use localcp on same filesystem
LOCALCP = ln -f --backup=numbered $(verbose) #/bin/ln
commands += $(firstword $(LOCALCP))
#checksum file
SUM = md5sum -b
commands += $(firstword $(SUM))
#checksum, read from ok file
CHECK = md5sum -c
commands += $(firstword $(CHECK))
#cpio
CPIO = cpio -o -O $(verbose)
commands += $(firstword $(CPIO))
#tar
TAR = tar -b 1024 -cf $(verbose)
commands += $(firstword $(TAR))
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
	$(TIMECMD) $(LOCALCP) $< $(@D)
ifneq ($(check),)
	-test -d $< && cd $< && $(TIMECMD) $(SUM) `find . -type f` > $@ || \
	 test -f $< && cd $(<D) && $(SUM) $(<F) > $@
else
	touch $@
endif
#always put to HPSS; bbcp if -force?
	-test -f $(ARCHROOT)/$* && $(DEEPPUT) $(ARCHROOT)/$* : $*
ifneq ($(force),)
	-test -f $(ARCHROOT)/$* && $(REMOTECP) $(ARCHROOT)/$* $(REMOTEID)/$*
	$(REMOTECP) $@ $(REMOTEID)/$*.ok
endif
#moving from WORK to PTMP
$(PTMPROOT)/%.ok: $(WORKROOT)/%
	@$(MKDIR) $(@D)
	$(TIMECMD) $(LOCALCP) $< $(@D)
ifneq ($(check),)
	-test -d $< && cd $< && $(TIMECMD) $(SUM) `find . -type f` > $@ || \
	 test -f $< && cd $(<D) && $(SUM) $(<F) > $@
else
	touch $@
endif

#operations on WORK
$(WORKROOT)/%.cpio: $(WORKROOT)/%
ifneq ($(check),)
# we create okfile in .. and then copy it in; otherwise it tries to checksum itself
	-test -d $< && cd $< && $(TIMECMD) $(SUM) `find . -type f` > ../$(*F).ok && \
	 ln -f ../$(*F).ok . && $(TIMECMD) find . -type f | $(CPIO) $@
else
	-test -d $< && cd $< && $(TIMECMD) find . -type f | $(CPIO) $@
endif
$(WORKROOT)/%.tar: $(WORKROOT)/%
ifneq ($(check),)
# we create okfile in .. and then copy it in; otherwise it tries to checksum itself
	-test -d $< && cd $< && $(TIMECMD) $(SUM) `find . -type f` > ../$(*F).ok && \
	ln ../$(*F).ok . && $(TIMECMD) $(TAR) $@ .
else
	-test -d $< && cd $< && $(TIMECMD) $(TAR) $@ .
endif

#the dot variables
.LOW_RESOLUTION_TIME: $(PTMPROOT)/% $(WORKROOT)/%.cpio $(WORKROOT)/%.tar
.PRECIOUS: $(PTMPROOT)/% $(WORKROOT)/%.cpio $(WORKROOT)/%.tar
.SUFFIXES:
.SUFFIXES: .cpio .ok .tar
