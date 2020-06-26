# Bronx-18 Release Notes

FRE Bronx-18 was released on June 22, 2020 to support the June 20-21 gaea software update, and adds new support for the Mississippi State University Orion system.

## Important note about NCO tools: `ncap` tool no longer available on gaea
During the gaea CLE7 software update on June 20-21, the NetCDF Command Operator (NCO) tools were updated from 4.6.4 to 4.7.9. The commonly-used `ncap` tool has been replaced with the newer, backward-compatible `ncap2`. `ncap` is no longer available! Please check all c-shell plugin sections in your XML for ncap use, and replace any calls to `ncap` with `ncap2`.

If you have run FRE experiments with c-shell sections that depend on `ncap` (e.g. for modifying input data files), your output may be incorrect.

## New
* Support for MSU Orion system
  * Similar cross-site functionality as gaea
  * See [Using FRE on Orion wiki](https://wiki.gfdl.noaa.gov/index.php/Using_FRE_on_Orion) for more details
* `pp.starter` to unpack history files in PTMP before running frepp
  * Will support the future VAST filesystem (new `/xtmp` filesystem to be shared among pp nodes)
  * Runs `hsmget` to stage history files to PTMP before running frepp
  * After one retry, will email user with instructions on restarting (running `pp.starter` manually)
  * 6-hour wallclock limit
  * When VAST (`/xtmp`) filesystem is installed, users can use it by setting the FRE PTMP directory to `/xtmp/$USER/ptmp` in the `<platform>/<directory>` tags
* New performance metric gathering capability available for `frepp`
  * Currently off by default; enable with `--epmt`
  * Allows detailed, statistical analysis of all performance metrics associated with a frepp job using the EPMT package
* New convenience parallel FRE wrappers for fremake and frerun (from Tom Robinson)
  * Allows multiple platforms and targets; convenient for regression testing
  * `multi-fremake` runs make scripts interactively using fremake --execute; default parallelism of 4 can be adjusted with command-line option
  * `multi-frerun` generates runscripts for and optionally submits any number of platform/target combinations
* New diff’ing tool `ardiff.py` (from Ray Menzel)
  * Python implementation of the c-shell `ardiff`
  * Identical functionality; able to specify files to check as command-line options instead of standard input (i.e. `ardiff.py reference.tar test.tar` instead of `ls reference.tar test.tar | ardiff`)
  * Additionally, can specify directories in addition to containers
* New simple hydrography grid generating script `make_simple_hydrog.csh` (from Krista Dunne)
  * Currently experimental! If you try this tool send any feedback to oar.gfdl.workflow@noaa.gov
  * Designed to quickly generate a simple hydrography for model development and testing; later, a more labor-intensive hydrography may be needed later (with more accurate river routing, and including lakes and coastal plains)
  * Wrapper script calls `runoff_regrid` and two new tools; `rmv_parallel_rivers` and `cp_river_vars`, which removes parallel rivers and post-processes that output
  * Works in `$TMPDIR`; designed for PP/AN use but may work on other sites as well
  * Run without arguments for usage help
  * Takes 3 required arguments: minimum land fraction (-f), land threshold (-t), and grid mosaic file (-m)
  * 1 optional argument, output directory, -o, to copy the output hydrography files to; otherwise, leaves them in `$TMPDIR`
## Fixes
  * `frepp` bug fix for cubed-sphere pp output having a erroneous double `tileX` extension; this bug was introduced in Bronx-16 due to a change in split_ncvars)
  * `output.stager` bug fix to more optimally set mppnccombine’s chunking behavior based on memory needed and memory available.
  * Cosmetic bug fix for `batch.scheduler.list` to return only the job-id instead of the entire sbatch output (“Submitted batch job 67203437 on cluster es”). The bug had resulted in the extra `sbatch` output getting into `reload_commands` and FRE logs.
## Updates
* Two new FRE-generated resource-related runscript variables: `$atm_nxblocks` and `$atm_nyblocks`
  * If desired, use in atmosphere and coupler namelists to avoid creating csh plugins for this purpose
  * If using openmp,
```
    $atm_nxblocks = 1
    $atm_nyblocks = 2 * $atm_threads
```
  * If not using openmp,
```
    $atm_nxblocks = $atm_nyblocks = 1
```
* Requeueing support for `output.stager` (from Tim Yeager). `output.stager` will now remove its lock file, requeue itself using `squeue reqeueue`, and `exit 0` when it receives a SIGINT signal 
* Decrease `output.stager` lockfile time-out time from 24 hours to 16 hours
* New `frerun` --force-pp option to enable post-processing for unique runs
* FRE version included in Slurm `--comment` directive (e.g. `--comment=fre/bronx-18`)
## Documentation
* Updated installation instructions; in `docs/install`
* Improved developer documentation

## FRE-NCtool updates
* Use Autotools build system (replacing legacy build script): config files for GFDL-ws, GFDL-pan, ncrc
* Use updated Intel compilers; 18 at GFDL (from 15), 18 at gaea (from 16), 19 at orion
* Expanded CI testing, including basic tests for all tools, and Bronx-16 reference tests for the combiners (`mppnccombine`, `combine-ncc`, and `decompress-ncc`)
* Added site config files for MSU orion site
* Bug fix for make_coupler_mosaic segmentation faults (https://github.com/NOAA-GFDL/FRE-NCtools/issues/4)
* Fix for locating `ceil()` function on some sites (i.e. Hera) (from Marshall Ward)
* Removed compilation warnings (from Tom Robinson)
* New simple hydrography grid generating script `make_simple_hydrog.csh` (from Krista Dunne)
