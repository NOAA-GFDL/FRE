# Bronx-16 Release Notes

Bronx-16 was released on October 21, 2019. It contains mainly bug fixes, some Slurm adjustments, and a few small features.

## FRE
* Features
  * User-specified email list for FRE notifications
    * fremake, frerun, and frepp accept a comma-separated list of emails to email FRE notifications to (both Slurm-sent and FRE-native emails) instead of $USER@noaa.gov using the option --mail-list=user1@noaa.gov,user2@company.com
    * email list will be passed from frerun to frepp via pp.starter
  * output.stager to not combine distributed files if the variables differ (a current diag manager bug for some regional output).
    * Users will be emailed if this problem is found.

* Bug fixes
  * frepp to use the "julian" default calendar if coupler_nml cannot be found
  * Fix for frerun --no-combine-history option (which had been broken since Bronx-12's ocean_static feature)
  * Improved error message from frerun when incompatible ranks and threads are specified in the <resources> tag

* Slurm updates
  * Two pp.starter Slurm cross-site fixes: (again) use a default 022 umask and run under the user's primary group
  * Submit the pp.starter job using the GFDL-side account (if specified)
  * Fix for output.stager to more accurately determine the memory available to pass to mppnccombine (should alleviate occasional out-of-memory output.stager errors seen)
  * Many Slurm updates to FRE sub-tools that were not converted in Bronx-15 (output.retry, batch.scheduler.list, batch.scheduler.fre.usage, batch.scheduler.submit)

* Updates and cleanup
  * Perl update to 5.30.0
  * Consolidation of some site-specific FRE sub-tools into general sub-tools (batch.scheduler.(time|list|fre.usage)
  * Removal of unsupported sites olcf (titan), theia
  * Remove group-checking for ptmp directory setup at GFDL

## New hsm/1.2.4
  * Check to see if work needs to be done before placing PTMP file locks
  * Should alleviate the delays seen by some users where PTMP cache is complete but frepp jobs are still waiting for locks

## FRE-NCtools
* split_ncvars
  * New option -u to split files without .nc extension (i.e. distributed output files)
  * Deprecate old cshell and python split_ncvars (will print warning and call split_ncvars.pl)
* list_ncvars
  * Make the temporary input namelist file more unique, to help when running in parallel
* make_hgrid
  * support very high-resolution grid (e.g. 43200 x 21600 lat-lon grid)
  * New option --do_cube_transform to re-orient tile #6 upwards
  * New option --no_length_angle to not output dx, dy, angle_dx, and angle_dy
* make_solo_mosaic
  * Ability to create fold-north contact for MOM6 horizontal grid
* make_remap_file
  * New tool to create low-resolution remap file from high-resolution remap file
  * Input and output mosaic files can be cubed-sphere or not
* mppncscatter
  * bug fix when data has record dimension
