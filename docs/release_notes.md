# Bronx-13 Release Notes

FRE Bronx-13 was released on October 31, 2018, to support the Gaea f2 filesystem.

## Features
* Support for the Gaea /lustre/f2 filesystem
  * New default directory locations for the f2 filesystem
  * Removed FRE-defined properties `$(CTMP)`, `$(CPERM)`, `$(CDATA)`, and `$(CHOME)`. No new FRE properties are being defined for f2; instead, please use the ORNL-defined environment variables `$SCRATCH`, `$DEV`, and `$PDATA` (or equivalently, `${SCRATCH}`, `${DEV}`, and `${PDATA}`)

## Fixes
* Fix for ardiff to handle colored ls output ("ls --color")
* Fix to prevent bash environment variable functions from causing a runscript error

# Update instructions

## From Bronx-11 or 12
Updating from Bronx-11 or 12 requires a bit of care due to the F1 to F2 filesytem transition. If you feel comfortable updating your experiment yourself, please follow the instructions below.
Otherwise, please submit a help desk ticket.
1. Record the (old) `state` directory and executable location
```
module load fre/<old-bronx>
frelist -x <xml> -p <platform> -t <target> -d state <experiment>
frelist -x <xml> -p <platform> -t <target> --executable <experiment>
```
2. Stop any production jobs that use the XML
3. Update your XML to use F2 filesystem
    1. Migrate your input data to F2. Pdata directories are arranged by institution and group, e.g. `/lustre/f2/pdata/gfdl/gfdl_B`. As Pdata isn't backed up, please copy any input from GFDL's `/archive`
    1. Update the FRE directories in your XML. If you use FRE's default directories, no changes may be needed except Pdata. Since Pdata directories on F2 are now organized by institution, you'll need to add a `/gfdl` to your input file directory. e.g `$(CDATA)/fms` should be changed to `$PDATA/gfdl/fms`
    1. Double-check that no parts of your XML (including any c-shell!) reference F1. While the `$(CDATA)` FRE property has been removed, the environment variable `$CDATA` continues to point to `/lustre/f1/pdata`. While F1 is still mounted, referencing F1 paths will still work; however, you *must* update the location before F1 is removed. Please take the time now to ensure your XML isn't dependent on F1.
    1. Update the `<platform>/<freVersion>` tag to `bronx-13`.
4. Copy executable and state directories to F2 filesystem
    1. Record the new `state` directory and executable location.
    ```
    module unload fre
    module load fre/bronx-13
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
    ```
    4. Change the executable permission to make it runnable (otherwise, frerun will complain)
    ```
    chmod +x <new_exec>
    ```
5. Regenerate your runscript using the `--extend` option. Make a note of any warnings or errors related to files, and fix them before continuing.
```
module load fre/bronx-13
frerun <other FRE options> --extend
```
6. Resubmit the runscript as usual

## From Bronx-10
Updating Bronx-10 XMLs require changes to resource specification and platforms.
* You may update your XML yourself, by following the instructions in the Bronx-11 Release Notes (on the [FRE Version History wiki](http://wiki.gfdl.noaa.gov/index.php/FRE_Version_History))
* Work with your model liaison to update your XML
* Submit a help desk ticket; Kris Rand has developed an XML converter script and he's happy to update your XML for you.
