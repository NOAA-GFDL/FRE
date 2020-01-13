# FREPP Hole Filling

## Introduction

The Flexible Modeling System's (FMS) Runtime Environment (FRE) is a
set of tools to help scientists at the Geophysical Fluid Dynamics
Laboratory (GFDL) manage the workflow of building, running and
post-processing climate models.  The frepp utility, which creates
scripts to run standard post-processing of the GFDL climate model
data, has a feature which will automatically determine if any required
post-processing for the currently requested post-processing request is
missing.  If it is missing, frepp will attempt to create the run
scripts, and submit the scripts to the post-processing and Analysis
system.  In FRE terminology, this feature is called **Hole Filling**.
In this document, the process frepp uses to hole fill is described,
known issues are discussed along with currently known work arounds.

## Hole filling

Not entirely sure what will go here, but need to describe:

* How user get hole filling to work
* What a user expects to see
* Process frepp uses to fill in holes

Notes on how frepp determines how to handle hole filling.

*frepp* will only attempt hole filling if the user has specified *-s*
on the command line (*-s* will submit the jobs to the batch scheduler
system).  *frepp* builds the list of dependency years using the
chunkLength (for time series) or intervals (for time averages)
attributes to the `<postProcess>/<component>` XML tags.

*frepp* will check the dependent year's state using the state files.
If the state file contains `OK`, frepp will assume the required data
is available.  If the user has specified *-o* on the command line,
*frepp* will redo all dependent segments.

If the state file contains `FATAL`, the user **must** remove the state
file to retry the dependent year.

If the state file contains `INTERACTIVE`, *frepp* will attempt to
rerun, as it assumes the data has only partially been completed.

If the state file contains `ERROR`, *frepp* will attempt to rerun the
post-processing.

If the state file contains `HISTORYDATAERROR`, *frepp* will attempt
orerun the post-processing.

If the state file is empty, *frepp* will not attempt to do anything
for this component.

If the state file contains a job ID, *frepp* will check if the job is
still on the system.  If still in the system the current segment will
be submitted with a dependency hold.  If the job is not running,
*frepp* will rerun the dependent segment.

If the state file does not exist, then *frepp* will attempt to run the
segment.


## Known Failure Cases

Describe the known failures in hole filling, and any known workarounds
for these failure cases.  The known ways hole filling can fail are
somewhat documented in the
[gitlab issue #48](https://gitlab.gfdl.noaa.gov/fre-legacy/fre-commands/issues/48).

From the issue, I see the following cases where frepp failed to
produce the post-processed files.  Although several of these are not
hole filling cases, these need to be documented.  Here, for now, is as
good a place as any.

**Note**: The current state of the work arounds assumes the user has
good knowledge of where FRE leaves files (e.g. script and state
directories, data directories, etc).  As this document evolves, better
information on how the user can figure this out will be included.

### pp.starter did not run

**Symptoms**: Though the pp.starter job was correctly submitted, the
batch job did not migrate correctly to the GFDL PAN system.  This
casued the batch job to not run.  User visiable symptoms: the
pp.starter job is not in the queueing system, the *pp.starter* batch
script does not exist for this segment, and a standard out file was
not generated.

**Downstream effects**: The post-processing that whould have been
created during this segment is missing.

**Hole filling**: In this stage, hole filling may repare the issue.
However, the hole filling in this case will only happen at the
multi-year chunck boundaries (i.e. 5, 10, 20).  If the XML does not
request multi-year segments, or this is the largest multi-year segment
the post-processing will not get done.

**Workaround**: To resolve this, the user can extract from the history
transfer standard out file the *pp.starter* command, and rerun this
command on the remote system.  *Note*: the user must be extremely
careful with the quotes in the *pp.starter* command.  Another solution
is to extract from another pp.starter run script, in the experiment's
run/postProcess directory, the *frepp* command and modify it for the
missing segment.  Some standard modifications for this second case are
the *-t <yyyymmdd>* option.  The user will change *<yyyymmdd>* to the
year, month, day of the missing segment.

### Incomplete data transfer

**Symptoms**: In the history transfer (HT) standard out file, a
transfer error occured.  In the archive directory of the experiment
the history file does not exist, and possibly a partial history file
does exists.  The partial history file has a *.gcp* extension
(i.e. 19700101.nc.tar.gcp).

**Downstream effects**: The history file for this segment is missing,
and the post-processing that would have been created is also missing.
This could lead to other segment's post-processing to not complete.

**Hole filling**: FRE on the remote system will attempt to retry the
transfer.  If the transfer retry is successful, FRE will submit the
pp.starter job which will run the post-processing for this segment.
However, if a later segment runs, and that later segment required data
from this segment, that later segment will not be run automatically
--- unless it's data is needed from another later segment.

If the transfer retry is not successful, than hole filling cannot
automatically resolve this problem as the data does not exist on the
PAN system.

**Workaround**: On the remote system, verify that a retry of the
transfer is not currently in the batch the system.  If the retry job
is in the batch system, monitory to verify the data transfers
successfully, and the post-processing completes as expected.  You may
also want to verify that later segments that my have been dependent on
this segment are rerun.

If a transfer retry for this segment is not running, the user should
check if a reason for the failed transfer is in the standard out file
for the last transfer attempt.  One common reason for the transfer
retry jobs to fail is the original transfer failure left a lock file
in place.  An example of a transfer retry that was blocked due to a
lock file:

```
<NOTE> : ====== FRE OUTPUT RETRYER $Id: output.retry,v 1.1.2.6.4.2 2014/03/10 19:48:58 Seth.Underwood Exp $ ======
<NOTE> : Starting at gaea3 on Fri Jun 26 18:37:36 EDT 2015
<NOTE> : <<< OM4_SIS2_CORE2_baseline.o2392699.output.stager.19700101.H.args >>> Beginning
lockfile: Sorry, giving up on "/lustre/f1/unswept/Amy.Langenhorst/ulm_mom6_2015.05.27/OM4_SIS2_CORE2_baseline/ncrc2.intel-prod/state/run/OM4_SIS2_CORE2_baseline.o2392699.output.stager.19700101.H.args.lock"
*ERROR*: The argument file is locked by another process - skipping ...
```

If a lock file is in place, the user must *rm* the lock file.  The
user can then attempt to retry the transfer manuualy with
*output.retry <stateDir>*.  However, in some cases the transfer may
not happen if the transfer retry attempted to retry the transfer five
or more times.  In that case, the user must check the **.args* file
for this segment and remove the last line that should look like `@
xferRetry++`.

**TODO**: It is possible that *output.retry* or *output.stager* could
be written to include a `--force` option that will attempt another
transfer even if the max transfer attempts has been reached.  The FRE
development team should look into this option.  This option can also
clean up any left over lock files that may have been left from a
previous transfer attempt.

**TODO**: For the lock files, a idea is to have the *output.retry* or
*output.stager* check to see if any transfers of the attempted job are
in the queue, if not and a lock file is in place, assume the lock file
is stale, remove it, and attempt the transfer again.

### PP job failed due to transfer error

**Symptoms**: The post-process job failed due to a transfer error, and
*ERROR* was placed in the segment's post-processing state file.

**Downstream Effects**: The post-processing that whould have been
created during this segment is missing.  This could lead to other
segment's post-processing to not complete.

**Hole filling**: If the transfer error was due to a temporary system
issue, and that issue has been resolved, a rerun of the
post-processing job will usually run successfully.  If this segment is
required for a later segment, then frepp's hole filling will
automatically attempt a rerun of this segment.  If this segment isn't
required, than the user must manually resubmit the post-processing
script for this segment.

**Workaround**: If the frepp hole filling did not attempt to rerun
this segment, then the user must manually rerun this segment.  It is
possible that a retry of this segment's post-processing failed a
number of times, leaving a state file with a message that indicates
this job cannot be rerun without user intervention.  In this case, the
user must remove the segment's state file(s) and then resubmit the
segment's post-processing script.

**TODO**: The FRE development team will investigate to see if there is
a way to have jobs with this failure type to get rerun even if this
segment is not required by a later segment.  Perhaps these types of
failures can leave some type of crumb in the `frepp.log` file or the
segments state file to indicate it should be attempted again.

### msub terminated

**Symptoms**: The *pp.starter* job failed, and something similar to
the following is in the pp.starter's standard out file:

```
Executing 'sleep 2;msub ...
Terminated
```

**Downstream Effects**: The post-processing that would have been
created during this segment is missing.

**Hole Filling**: If this segment is required by a later segment, the
frepp hole filling will attempt to run this segment.  However, if this
segment is not needed then the user must submit the post-processing
script(s) for this segment manually.

**Workaround**: If the hole filling did not attempt this segment, then
the user must submit the post-processing script(s) for this segment
manually.  If the scripts do not exist, then the user must manually
run the *frepp* command for this segment.  *Note*: the frepp command
for this will be left in the segment's pp.starter standard out file.

**TODO**: The FRE development team should check if something similar
to the *batch.scheduler.submit* script that is used on the gaea
system can be used on the PAN system.  This error usually
happens due to the batch server fails to return a job ID to the submit
client command before the client's time out limit is reached.
