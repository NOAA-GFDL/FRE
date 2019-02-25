# Bronx-14 Release Notes

FRE Bronx-14 was released on February 27, 2018. The major feature is PP/AN Slurm support. Bronx-14 is a bridge release
that will be replaced by Bronx-15 which will have full Slurm (gaea+GFDL) support

## Features
* PP/AN Slurm support
  * All normal scheduler changes are transparent and work in Slurm as expected
    * Slurm changes should be transparent to users; output file locations, dependent job behavior, error emailing
      should work as expected
    * frepp option change (--moab to --resourceManager, still short option -m) to pass scheduler options
    * Updated GFDL site utilities: batch.scheduler.fre.usage, batch.scheduler.list, batch.scheduler.time
  * Caveats
    * Still sends unconverted analysis scripts to MOAB with a warning and instructions for converting.
      We are investigating online analysis script conversion as a B-15 feature
    * Still gets started from MOAB pp.starter. (Bronx-15 will contain full--i.e. gaea-side--Slurm support)
  * Disabled job schooling feature that was not often used
    Job schooling was previously activated if 1) FRE ptmp directory was set to /vftmp and 2) job is on one of the pp nodes.
    We don't think this feature is currently (intentionally) used; please let us know if you miss this feature
* Other updates
  * Updated batch.scheduler.fre.usage (still MOAB) to track C4 usage

## Fixes
* ardiff fix (from (Tom). Background: newer versions of nccmp are needed for compressed land files.
  Such a more recent nccmp 1.8.2.0 is used on gaea login nodes, GFDL workstations, and PPAN
  ardiff needed a small change to account for recent behavior change
* (Another) fix to prevent bash environment variable functions from causing a runscript error
* Fix for XMLs not being transferred back from gaea if they were on lustre. Now XMLs will transfer back from f2 as expected
* Fix for gaea fre.properties to correctly identify t4 as a c3 (not c4) test cluster

## Instructions for upgrading from Bronx-13
Bronx-13 is (almost) identical to Bronx-14 except for PP/AN Slurm support. To switch a Bronx-13 XML to Bronx-14,
1. Update your XML by updating the `<platform>/<freVersion>` tag
1. Use FRE on your Bronx-14 XML as usual. `module load fre/bronx-14`

## Instructions for upgrading from Bronx-12
Compared to bronx-12, Bronx-14 requires no XML changes aside from F1->F2 directory locations.
1. Migrate your input data to F2. Pdata directories are arranged by institution and group, e.g. `/lustre/f2/pdata/gfdl/gfdl_B`. As Pdata isn't backed up, please copy any input from GFDL's `/archive`
1. Update the FRE directories in your XML. If you use FRE's default directories, no changes may be needed except Pdata. Since Pdata directories on F2 are now organized by institution, you'll need to add a `/gfdl` to your input file directory. e.g `$(CDATA)/fms` should be changed to `$PDATA/gfdl/fms`
1. Double-check that no parts of your XML reference F1. While the $(CDATA) FRE property has been removed, the environment variable `$CDATA` continues to point to `/lustre/f1/pdata`. While F1 is still mounted, referencing F1 paths will still work; however, you *must* update the location before F1 is removed. Please take the time now to ensure your XML isn't dependent on F1.
1. Update your XML to use bronx-13 by updating the `<platform>/<freVersion>` tag.
1. Use FRE on your Bronx-13 XML as usual. `module load fre/bronx-13`
