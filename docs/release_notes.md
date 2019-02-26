# Bronx-14 Release Notes

FRE Bronx-14 was released on February 27, 2018. The major feature is PP/AN Slurm support; Bronx-14
will be replaced by Bronx-15 which will have full (gaea & GFDL) Slurm support.

## Features
* PP/AN Slurm support
  * MOAB-to-Slurm changes should be transparent to users; output file locations, dependent job behavior, error emailing
      should work as before
    * frepp option change (--moab to --resourceManager, still short option -m) to pass scheduler options
    * Updated GFDL site utilities: batch.scheduler.fre.usage, batch.scheduler.list, batch.scheduler.time
  * Caveats
    * Still sends unconverted analysis scripts to MOAB with a warning and instructions for converting.
      We are investigating online analysis script conversion as a B-15 feature
    * Still gets started from MOAB pp.starter
  * Removed job schooling feature that was not often used.
    Job schooling was previously activated if 1) FRE ptmp directory was set to /vftmp and 2) job was on one of the pp nodes.
    We don't think this feature is currently (intentionally) used; please let us know if you miss it.
* Other updates
  * Updated batch.scheduler.fre.usage (still MOAB) to track C4 usage

## Fixes
* ardiff fix (from (Tom). Newer versions of nccmp are needed for compressed land files.
  Such a more recent nccmp 1.8.2.0 is used on gaea login nodes, GFDL workstations, and PPAN.
  ardiff needed a small change to account for recent behavior change.
* (Another) fix to prevent bash environment variable functions from causing a runscript error
* Fix for XMLs not being transferred back from gaea if they were on lustre. Now XMLs will transfer back from f2 as expected
* Fix for gaea fre.properties to correctly identify t4 as a c3 (not c4) test cluster

# Update instructions

## From Bronx-13
Bronx-13 is (almost) identical to Bronx-14 except for PP/AN Slurm support. To switch a Bronx-13 experiment to Bronx-14,
1. Stop any production jobs that use the XML
1. Update your XML by updating the `<platform>/<freVersion>` tag
1. Regenerate your runscript using the `--extend` option
```
module load fre/bronx-14
frerun <other FRE options> --extend
```
4. Resubmit the runscript as usual

## From Bronx-11 or 12
Updating from Bronx-11 or 12 to Bronx-14 requires a bit of care due to the F1 to F2 filesytem transition. If you feel comfortable updating your experiment yourself, please follow the instructions below.
Otherwise, please submit a help desk ticket.
1. Record the (old) FRE `state` directory and executable location
```
module load fre/<old-bronx>
frelist -x <xml> -p <platform> -t <target> -d state <experiment>
frelist -x <xml> -p <platform> -t <target> --executable <experiment>
```
3. Stop any production jobs that use the XML
4. Update your XML to use F2 filesystem
    1. Migrate your input data to F2. Pdata directories are arranged by institution and group, e.g. `/lustre/f2/pdata/gfdl/gfdl_B`. As Pdata isn't backed up, please copy any input from GFDL's `/archive`
    1. Update the FRE directories in your XML. If you use FRE's default directories, no changes may be needed except Pdata. Since Pdata directories on F2 are now organized by institution, you'll need to add a `/gfdl` to your input file directory. e.g `$(CDATA)/fms` should be changed to `$PDATA/gfdl/fms`
    1. Double-check that no parts of your XML (including any c-shell!) reference F1. While the `$(CDATA)` FRE property has been removed, the environment variable `$CDATA` continues to point to `/lustre/f1/pdata`. While F1 is still mounted, referencing F1 paths will still work; however, you *must* update the location before F1 is removed. Please take the time now to ensure your XML isn't dependent on F1.
    1. Update the `<platform>/<freVersion>` tag to `bronx-14`.
4. Copy executable and state directories to F2 filesystem
    1. Record the new `state` directory and executable location.
    ```
    module unload fre
    module load fre/bronx-14
    frelist -x <xml> -p <platform> -t <target> -d state <experiment>
    frelist -x <xml> -p <platform> -t <target> --executable <experiment>
    ```
    2. Copy the old `state` directory to the new location. `gcp` with the `-cd -r` options will do this, with some care; remove the last target directory (or else you'll end up with `state/state/run` where we want only `state/run`) and add a trailing slash to the target directory (or else gcp will give an error).
    ```
    gcp -cd -r -v <old_state_dir> <new_state_dir>
    # e.g. old_state_dir = /lustre/f1/unswept/Chris.Blanton/warsaw_201803/CM2.5_A_Control-1990_FLOR_B01/ncrc4.intel16-prod-openmp/state
    #      new_state_dir = /lustre/f2/dev/Chris.Blanton/warsaw_201803/CM2.5_A_Control-1990_FLOR_B01/ncrc4.intel16-prod-openmp/state
    #      gcp -cd -r -v /lustre/f1/unswept/Chris.Blanton/warsaw_201803/CM2.5_A_Control-1990_FLOR_B01/ncrc4.intel16-prod-openmp/state /lustre/f2/dev/Chris.Blanton/warsaw_201803/CM2.5_A_Control-1990_FLOR_B01/ncrc4.intel16-prod-openmp/
    ```
    3. Copy the executable to the new location using `gcp` with the `-cd` option
    ```
    gcp -cd <old_exec> <new_exec>
    # e.g. old_exec = /lustre/f1/unswept/Chris.Blanton/warsaw_201803/CM2.5_FLOR_exec/ncrc4.intel16-prod-openmp/exec/fms_CM2.5_FLOR_exec.x
    #      new_exec = /lustre/f2/dev/Chris.Blanton/warsaw_201803/CM2.5_FLOR_exec/ncrc4.intel16-prod-openmp/exec/fms_CM2.5_FLOR_exec.x
    #      gcp -cd -v /lustre/f1/unswept/Chris.Blanton/warsaw_201803/CM2.5_FLOR_exec/ncrc4.intel16-prod-openmp/exec/fms_CM2.5_FLOR_exec.x /lustre/f2/dev/Chris.Blanton/warsaw_201803/CM2.5_FLOR_exec/ncrc4.intel16-prod-openmp/exec/fms_CM2.5_FLOR_exec.x
5. Regenerate your runscript using the `--extend` option
```
module load fre/bronx-14
frerun <other FRE options> --extend
```
6. Resubmit the runscript as usual

## From Bronx-10
Updating Bronx-10 XMLs require changes to resource specification and platforms.
* You may update your XML yourself, by following the instructions in the Bronx-11 Release Notes (on the [FRE Version History wiki](http://wiki.gfdl.noaa.gov/index.php/FRE_Version_History))
* Work with your model liaison to update your XML
* Submit a help desk ticket; Kris Rand has developed an XML converter script and he's happy to update your XML for you.
