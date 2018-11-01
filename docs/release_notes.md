# Bronx-13 Release Notes

FRE Bronx-13 was released on October 31, 2018. The major feature is support for the Gaea f2 filesystem. Additional features (including PPAN Slurm support) and bug fixes will be released as future patches.

## Features
* Support for the Gaea /lustre/f2 filesystem
  * New default directory locations for the f2 filesystem
  * Removed FRE-defined properties `$(CTMP)`, `$(CPERM)`, `$(CDATA)`, and `$(CHOME)`. No new FRE properties are being defined for f2; instead, please use the ORNL-defined environment variables `$SCRATCH`, `$DEV`, and `$PDATA` (or equivalently, `${SCRATCH}`, `${DEV}`, and `${PDATA}`)

## Fixes
* Fix for ardiff to handle colored ls output ("ls --color")
* Fix to prevent bash environment variable functions from causing a runscript error

## Instructions for upgrading from Bronx-12
All users now have F2 access. While F1 and F2 will both be available for a few months, we encourage users to start new experiments using Bronx-13. Compared to bronx-12, Bronx-13 requires no XML changes aside from F1->F2 directory locations.
1. Migrate your input data to F2. Pdata directories are arranged by institution and group, e.g. `/lustre/f2/pdata/gfdl/gfdl_B`. As Pdata isn't backed up, please copy any input from GFDL's `/archive`
1. Update the FRE directories in your XML. If you use FRE's default directories, no changes may be needed except Pdata. Since Pdata directories on F2 are now organized by institution, you'll need to add a `/gfdl` to your input file directory. e.g `$(CDATA)/fms` should be changed to `$PDATA/gfdl/fms`
1. Double-check that no parts of your XML reference F1. While the $(CDATA) FRE property has been removed, the environment variable `$CDATA` continues to point to `/lustre/f1/pdata`. While F1 is still mounted, referencing F1 paths will still work; however, you *must* update the location before F1 is removed. Please take the time now to ensure your XML isn't dependent on F1.
1. Update your XML to use bronx-13 by updating the `<platform>/<freVersion>` tag.
1. Use FRE on your Bronx-13 XML as usual. `module load fre/bronx-13`
