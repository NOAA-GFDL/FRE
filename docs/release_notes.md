# Bronx-23 Release Notes

Bronx-23 was released on --------, 2025.

## New
* Compatibility with FRE 2025 'fre make'
Use FRE 2025 to create an executable or model container based off of a model, compile, and platform yaml configuration and run with Bronx-23 frerun. Details on how the yaml framework looks/built can be found in the FRE 2025 documentation (https://noaa-gfdl.github.io/fre-cli/usage.html#yaml-framework)
  * Choose between bare metal executable (traditional) executable or container with dependencies and the executable (new)
    * Step-by-step guide: https://noaa-gfdl.github.io/fre-cli/usage.html#guide
    * On gaea, module load FRE 2025 (module load fre/2025.01 currently)
  * Use the FRE 2025-generated executable or container in Bronx-23
    * Make sure the created executable or container is on a gaea filesystem
    * For bare metal executables, set path to executable created by 'fre make' with the <excutable> tag (within <experiment>). Then run frerun as usual.
    * For the model container, set path to container created by 'fre make' with the <container> tag (also within <experiment>)
         `<container file="[path/to/container]"/>` under the `experiment name` in an experiment.xml
      Then add --container to your frerun options.
* Compatibility with FRE 2025 'fre pp'
  * 
Recommendations: Choice to use FRE 2025 for make and pp ("fre make" and "fre pp", with spaces), or contnue to use Bronx fremake and frepp. Both sets of compile and pp tools will be supported for some time. However, we encourage users to update, as FRE 2025 is being actively developed and Bronx is receiving only essential updates. In the next year, the MSD workflow team will work with the standard FMS model configurations and labwide model configurations to transition to FRE 2025 configurations for compiling and postprocessing, so that new FRE users can use FRE 2025 without creating all configuration files.
* Proper support for rewritten FMS diag, field, data managers
  * Modular fms-yaml-tools, not part of FRE
  * baseDate expansion in diagyamls
  * Validation and combining. Done in a $TMPDIR which is removed on success.
  * Errors. On error, the $TMPDIR is preseved for interactive inspection, with command showing problem. Please remove the tmpdir afterwards.
* End-to-end NetCDF4 support
  * mppnccombine tool update, and remove hard-coded -64
  * split_ncvars.pl tool update

## Fixes
* Removed subregional variable/dimension checking for restart files
* Several tool updates and output.stager fixes for problems that can occur when the gaea filesystem is having problems (such as being unmounted while the staging job is running). The updates reduce the possibility of data loss in such scenarios.
  * Output stager checks that history files are NetCDF files before processing them.
  * mppnccombine and combine-ncc now sync output to filesystem for exiting
* Reduce number of batch.scheduler.submit retries to 2. batch.scheduler.submit is a sbatch wrapper that includes some error and retry logic that was more valuable for MOAB than Slurm. Some heavy FRE users ran into unfortunate thrashing conditions where an output.stager job was trying to submit more stagers but could not due to the Slurm per-user running/pending job limit (currently 50).
* add --export=ALL for non-coupler experiments

## Updates
* The Bronx-23 module (fre/bronx-23) does not bring "ncdump" into the PATH. Traditionally, on gaea, the FRE modules loaded cray-netcdf in order to make "ncdump" available for users, scripts, and within fre-nctools; separately, the default platform cshell is maintained in fre-commands, which also contains cray-hdf5 and cray-netcdf module loads. Previously, we ensured that those versions are identical, which limited flexibility. FRE-NCtools is now more self-contained w.r.t dependencies such as NCO tools and ncdump, and removing the cray-netcdf module load from the FRE modules makes FRE more robust and easier to maintain.
* Reduce load on gaea DTNs. gaea DTN policy currently limits the number of running/pending jobs to 50 per user. Users with multiple streams or ensembles can easily hit this limit, and FRE's output.stager is not designed to handle scenarios where a batch job cannot be submitted. Therefore, we sought to reduce the number of FRE-generated DTN jobs by about half, with these updates:
  * Do not transfer regression output by default; use frerun --transfer (to reduce load on DTNs)
  * Combine output.stager ascii-save, ascii-transfer, and restart-save processing into one batch job with the "AR" label (to reduce load on DTNs). The argFiles are still separate, though (i.e. H, R, A). If the initial job fails, output.retry will retry the jobs as separate jobs.
  * Run work-dir cleaning jobs on the login nodes (to reduce load on DTNs)
* ardiff updates from Uriel: compare metadata/data only and limit number of differences when force comparing. Use "ardiff -h" to see the options.
* Updated set of mkmf templates, 2024.01
* refineDiag pass thru Slurm options, e.g. for requesting nodes with certain qualities

## FRE-NCtool updates
* Recent deployment improvements
* Tool updates

## `output.retry` Update
## SRUN Bug Fix
## FRE 2025 pp.starter 
## Batch Scheduler Updates
## FRE 2025 / FRE Bronx Integration Update
