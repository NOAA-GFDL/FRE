# Bronx-19 Release Notes

FRE Bronx-19 was released on July 20, 2021 to support the June-August 2021 PP/AN OS upgrade (RHEL/CentOS 7). In addition to bug fixes and small updates, Bronx-19 includes significant updates to the grid-generating and remapping tools.

## PP/AN OS transition schedule and Bronx-18 pending retirement
On Monday August 9th, all PP/AN batch hosts (nodes) will move to CentOS 7 and all analysis hosts will move to RedHat Enterprise Linux 7. Please refer to Tim Yeager’s July 16 email for more details.
* Bronx-19 is compatible with RHEL/CentOS 7 (“OS 7”) only and submits to the “batch7” partition which contains nodes that have already been converted to “OS 7”. When all batch nodes have been converted, the partitions will be renamed and Bronx-19 will submit to the regular “batch” partition.
* Bronx-18 is supported on RHEL/CentOS 6 (“OS 6”) only. Based on testing so far, Bronx-18 executables can run on “OS 7” but this is unsupported. If any problems are reported, the solution will be to update to Bronx-19. Currently, Bronx-18 submits to the “batch6” partition which contains nodes that have not yet been converted to “OS 7”. On August 9th, Bronx-18 will submit to the “batch” partition (which will contain only “OS 7” nodes) and will no longer be supported. Deprecation warnings will be added to the Bronx-1[5678] modules in October and **versions of FRE older than Bronx-19 will be removed at the end of 2021**.

## Recommended user actions
* **Starting now, use Bronx-19 for new experiments**. Continue to use Bronx-18 to postprocess currently running experiments on the legacy “OS 6” partition.
* **For Bronx-18 experiments that will not complete by August 9th, we recommend switching to Bronx-19 no later than August 9th** (see instructions below).  As an unsupported option, you may continue to use Bronx-18 which will submit to the “OS 7” nodes after August 9th.
* Instructions to update to Bronx-19 for currently running experiments:
  * Stop any production jobs that use the XML
  * Update your XML by updating the `<platform>/<freVersion>` tag
  * WARNING: If you have active Bronx-18 post-processing jobs, they may be adversely impacted when the Bronx-19 XML gets transferred back to GFDL (e.g. when frepp re-parses the XML to submit analysis scripts). If you have Bronx-18 postprocessing for this experiment, please either wait until the post-processing competes before submitting Bronx-19 runscripts, or kill the Bronx-18 frepp jobs and then re-frepp with Bronx-19 (or accept the possibility of failed frepp jobs)
  * Regenerate your runscript using the frerun --extend option
```
    module load fre/bronx-19
    frerun <other FRE options> --extend
```
  * Resubmit the runscript as usual

## Additional information on FRE-NCtools executables, RHEL/CentOS 6 and 7, and round-off floating-point differences
At GFDL, Bronx-19 fre-nctools executables are compiled on “OS 7” using the latest Spack-maintained modules (including NetCDF 4.7.3). Bronx-18 executables were compiled on “OS 6” using the legacy modules (including NetCDF 4.2). Bronx-19 executables can only run on “OS 7” hosts. Bronx-18 executables are not supported on “OS 7” hosts; however, during testing they have worked and produced floating-point output similar to when run on “OS 6”. Bronx-19 executables that are sensitive to floating point operations (e.g. fregrid, timavg, make_hgrid, make_coupler_mosaic) will produce slightly different output compared to Bronx-18 executables (low-order floating-point differences)

## Bronx-19 updates
- More resilient output.retry for restarting failed transfer jobs on gaea (from Tim Yeager)
  - Previously, failed transfer jobs were restarted 4 times with no delay, then required user intervention to modify the argFiles to reset the retry count. This could happen quickly as all output.stager jobs call output.retry.
  - Now, failed transfer jobs will be submitted to the scheduler with an increasing delay, and will retry 6 times: after 0, 1, 2, 4, 8, and 16 hours.
  - This should allow FRE transfer jobs to recover during a period of transfer instability without user intervention
- fremake to allow symlinks in source checkout directories (needed for recent MOM6 development)
- Opt-in support to use the new PP/AN shared fast scratch filesystem /xtmp as PTMP. Activate by editing the `<platform>/<directory>` section of the XML to set the ptmp directory to /xtmp:
  - `<ptmp>/xtmp/$USER/ptmp</ptmp>`
  - Testing so far has shown slight improvement in post-processing runtimes, and will be default on in the next Bronx release. Please send any xtmp feedback to oar.gfdl.workflow@noaa.gov

## Bronx-19 bug fixes and minor updates
- **fre/bronx-19 modulefile at GFDL no longer loads python/2.7.3 (and ncarg/6.2.1)** as they are no longer needed by FRE. If your refineDiag and analysis scripts are now failing due to missing a python module, please module load your desired python within your refineDiag and analysis scripts.
- During history file staging, frepp scripts no longer crash if a history file pointed to by another history file’s “associated_files” global attribute is missing
- Fixed bug that resulted in time and time_bounds in static pp files for native cubed sphere output
- Small updates for the EPMT performance metric collection system within frepp. Still off by default, activate with the frepp --epmt option. (Will be default on in future Bronx releases)
- refineDiag scripts to no longer call “frepp -A”. This had caused frepp errors in unusual cases where the pp directory doesn’t yet exist, refineDiag-called frepp has no work to do, and the subsequent “frepp -A” fails due to lack of pp directory.
- gaea and orion runscripts to no longer call srun/srun-multi with the --verbose option which had resulted in a large amount of unnecessary output in the stdout logs. The only useful information was the nodelist, which is available in the Slurm accounting database.
- Orion’s modules initialized by $MODULESHOME environment variable
- Cosmetic fix for output.stager to report the pp.starter job ID correctly
- Update for gaea’s pgi make template (from github.com/NOAA-GFDL/mkmf)

## Bronx-19 FRE-NCtools updates
- **make_hgrid** was enhanced with the capability to generate multiple nested telescoping grids on the cubed sphere. This new feature is described in the --nest_grids option documentation and in usage example 8 in the usage help (make_hgrid --help). From Bill Ramstrom, Joseph Mouallem, and Kyle Ahern.
NOTE: Global refinement, a method used to create two grids such that the higher-resolution one overlays the course one with identical intersecting points, is unsupported as we revisit its requirements, though the feature still works for now. See the usage help for instructions, and please create a github issue if you use this feature (https://github.com/NOAA-GFDL/FRE-NCtools/issues)
- **remap_land** was enhanced to support the new fields and dimensions in lm4.1 and lm4.2 (proposed) restart files
- **make_coupler_mosaic** includes a fix to reuse the atmos grid for land when they are the same (instead of re-calculating, which has unavoidable inaccuracies) when NOT using the great circle algorithm. (The tool already had the correct behavior when using the great circle algorithm).
- **make_coupler_mosaic** includes a fix for calculating polygon areas correctly when a polygon side crosses a pole. This occurs mostly for stretched, non-great circle algorithm atmos grids; previously the bug caused tiling errors and holes in the Antarctic land mask.
- **create_xgrid** includes a fix for certain exchange grid errors for grid cells adjacent to ocean tripolar fold in the vicinity of the Poles (often involving a stretched atmos grid and tripolar ocean).
- **fregrid** was fixed to set the NetCDF file type of the output file to be the same type as the input file when the user does not specify the type in the command argument list and the --weight_file option is used
- **combine_restarts** was updated to support icebergs
- **iceberg_comb.sh** was updated to properly check for prerequisite tool “ncdump”
- New tool **nc_null_check** was added to diagnose a particular problem with mppio related to reading in latitude and longitude bounds when there is a null string in the latitude/longitude “bounds” variable attribute (NOAA-GFDL/FMS#578). This tool will be removed soon as mppio is deprecated within FMS.
- **combine_blobs** was removed. (Historically used for combining MOM5 Lagrangian Blobs)
- Updates to build environment and compiling procedures
  - Automake macros to better detect NetCDF configurations on systems with broken n[cf]-config
  - Updates for GFDL sites, including NCRC Intel compiler flags for greater reproducibility while being able to run on AMD hardware as well, GDFL-WS and PP/AN updates to use CentOS 7 “Spack” modules, and updated NetCDF and mpich libraries.
  - Adds site configuration files for compiling on NESCC systems
- Numerous C language files were updated to be in compliance with the C99 standard.
- Set the executable rpath to included needed NetCDF libraries
- Copyright and licensing headers standardized throughout the repository.
- Added .editorconfig file to standardize code formatting across varying user editors and IDEs. (https://editorconfig.org)
