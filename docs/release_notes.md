# Bronx-20 Release Notes

FRE Bronx-20 was released on October 28, 2022 to support the Gaea C5 partition; other updates include collection of workflow performance metrics, enabling /xtmp on PP/AN, loading fre-nctools as a submodule, and improved XML include directory transfer. There were 5 updates/patches, [summarized below](#patch-release-notes).

## Support for Gaea C5
* fremake/frerun forbids using ncrc5 platforms on C3/C4 and vice versa
* frerun warns if an inefficient number of threads is requested
* Better handling of environment variables across batch and compute environments

**Recommend using Bronx-20 for new experiments and to run on C5.**

## Updated make templates and default platform cshell
* Intel compilers available in three flavors: classic (ifort/icc), oneapi (ifx, icx), and "production" (ifort/icx).
* For consistency with module names, the GNU compiler templates have been renamed to `gcc`; XMLs referring to `gnu` will need to be updated.
* FRE targets updated; see the [C5 Onboarding Guide](https://docs.google.com/document/d/12tVJrDMon9tvvM1F-A5wn7oVHGxqRVWFzRcgctAkODQ/edit?usp=sharing) for more. In general, C5 (and C4 after mid-April 2023 update) `prod` settings are more optimized than C3/C4 `prod`.

**User action needed: Add XML platforms for C5 (and updated C4 mid-April 2023 and updated C5 mid-May 2023).** For each platform, the `<compiler type=MODULE version=VERSION>` tag should refer to an available compiler module and version. Supported compilers include `intel`, `intel-classic`, `intel-oneapi`, `gcc`, `cce`, and `nvhpc`. Use `module avail` to determine the available compiler versions. If you have `gnu` compiler platforms defined, update the compiler name to `gcc`.

**Recommendation: Use `repro` for reproducibility and `prod` for performance. Anything beyond run-to-run reproducibility may be limited when choosing the `prod` target.** Also, note that C5 runs will not reproduce runs on other clusters. `intel-classic` is the most similar to Intel-19.

## Improved batch compiling
* Optimized mkmf templates for parallel make
* fremake handles new Slurm enforcement of per-job memory limits on C5 login nodes (see the [C5 Onboarding Guide](https://docs.google.com/document/d/12tVJrDMon9tvvM1F-A5wn7oVHGxqRVWFzRcgctAkODQ/edit?usp=sharing) for more.)
* Simplified specification for compile parallelism. The number of make jobs is the number of cores/tasks requested if in a batch job (using fremake `--ncores=N` option), and will be 8 when run interactively. You may set $MAKEFLAGS as an override.
* For C5, the default `--ncores` is 16 and the maximum is 64. For C3/C4, the default and maximum `--ncores` is 8.
* The default and maximum `--ncores` is 8. Each requested core can use up to 2GB of memory, so by default compile scripts will request 8 cores giving access to 16 GB of memory.
* If your compile job exceeds the limit, it will be killed by Slurm (with an OUT-OF-MEMORY job code). Request more memory with the sbatch `--mem` option, or compile interactively (which is not subject to a per-job memory limit).

**No user action needed.**

## Collection of workflow performance metrics
* EPMT is a profiling toolkit designed to collect and analyze performance metadata for PP/AN batch jobs.
* Now enabled by default for frepp, and can be disabled with the option `--no-epmt`. EPMT will not disturb the job even on failure. (EPMT is not used when running frepp scripts interactively).
* [Documentation](https://gitlab.gfdl.noaa.gov/workflow-db/docs/-/wikis/home)
* ***Work-in-progress***: Example Jupyter notebooks to illustrate EPMT analysis features are being developed and improved. You can try them from the *jhan* analysis host:

```
$ module load epmt
$ cd /home/fms/local/opt/fre-commands/bronx-20/docs/epmt
$ epmt notebook -- --no-browser --ip=`hostname -f` --port=`jhp 1`
Enter the provided http address into your web browser
```

**No user action needed. You may see some harmless EPMT artifacts in your stdout.**

## Improved XML include directory transfer
* You can now use the FRE property $(xmlDir) to set the FRE XML `include` directory on compute and remote sites. FRE will transfer the XML include directory before starting the postprocessing, and you can refer to the $(includeDir) property within your XML.
* To use, set the `include` FRE directory in the `<setup>/<platform>/<directory>` section in your XML, for both the compute and GFDL platforms. For example if your XML include directory is named `awg_include`:
```
<directory>
    <include>$(xmlDir)/awg_include</include>
```
* [Documentation](run/include_dir.md)

**Recommended for all XMLs that use a shared include directory. It simplifies the XML for cross-site usage and will keep the GFDL copy of the include directory up-to-date.**

## Uses /xtmp filesystem as PTMP by default at GFDL
* Installed in 2021, /xtmp is a fast, shared scratch filesystem available on PP/AN, now used by frepp jobs by default.
* When PP/AN jobs are submitted with the "xtmp" sbatch comment, `$TMPDIR` points to /xtmp instead of /vftmp. When hsmget then uses `/xtmp/$USER/ptmp` as the PTMP cache, PTMP to WORKDIR transfers are done with hard links.
* Testing has shown some improvement in postprocessing runtimes when using /xtmp as PTMP, and further workflow optimizations to take advantage of /xtmp are planned.
* To use /ptmp as PTMP explicitly, set the ptmp FRE directory in your XML: `<ptmp>/ptmp/$USER</ptmp>`

**No user action needed. If you notice filesystem-related issues possibly related to /xtmp, please open a Help Desk ticket.**

## FRE-NCtools now a submodule
* FRE-NCtools is independent of FRE, and is maintained on [github](https://github.com/NOAA-GFDL/FRE-NCtools)
* `fre/bronx-20` loads `fre-nctools/2022.01` initially and will load `fre-nctools/2022.02` when available

**No user action needed**

## Initial transitional support for FMS YAML input formats
* The FMS diag manager, field manager, and data managers are being rewritten, and as part of the updates they will accept YAML input instead of the traditional (legacy) table formats. Please refer to FMS release notes for more details and how to configure which input format should be used.
* Bronx-20 does not allow usage of YAML input files natively, and this will be supported in a future release
* To facilitate testing and transition to the YAML input formats, Bronx-20 runscripts will convert field_table, diag_table, and data_table files to YAML using the [fms-yaml-tools](https://github.com/NOAA-GFDL/fms_yaml_tools), making both formats available to the model. If the converters fail, the runscript will continue on (set the environment variable $FRE_WARNINGS to "error" to upgrade the warning to a fatal error). If the YAML files are already present (e.g. using a cshell insert), the converters will not run.
* The [fms-yaml-tools](https://github.com/NOAA-GFDL/fms_yaml_tools) field-table-to-yaml, data-table-to-yaml, and diag-table-to-yaml are installed in the `python/3.9` environment on gaea and GFDL.

**Currently not recommended to use YAML input files for production.**

## Bug fixes and minor updates
* The default srcDir, execDir, and rootDir directories for gaea platforms has been updated to $HOME from $DEV. These changes were made to help reduce potential Git-contributed issues on the F2 (Lustre scratch) filesystem. The new defaults are:
  * srcDir: `$HOME/$(stem)/$(name)/src`
  * execDir: `$HOME/$(stem)/$(name)/$(platform)-$(target)/exec`
  * rootDir: `$HOME/$(stem)`
* The default PTMP directory for gaea platforms has been changed to `$SCRATCH/$USER/ptmp/$(stem)/$(name)` (from `$SCRATCH/$USER/ptmp`) to reduce the number of hsmget-created hardlinks which have caused issues with the scratch (Lustre) filesystem.
* The working directory ($workDir) will be removed automatically after normal completion of the compute job. Use the frerun option `--no-free` to not remove the workDir automatically.
* Skip unnecessary/duplicate timeSeries requests when using sub-chunks. When creating timeseries from multiple history files within a single component, each history file must be included in a separate `<timeSeries>` tag. When possible, frepp will try to create timeseries from existing timeseries in /archive; when it does this, variables from all history files will be used, so including multiple <timeSeries> tags results in duplicate work. This has been a long-standing bug in frepp that has become noticeable with increases in resolution and filesizes. When the unnecessary/duplicate timeSeries tags are encountered, they are skipped with a message (e.g. `NOTE: Skipping unnecessary <timeSeries> tag for ocean_z monthly 20-yr (due to TSfromTS calculation)`).
* Use latest NCO tools (5.0.1). Several ncks calls required small syntax updates
* Fixed ability for frepp to combine distributed history files on PP/AN. If the history file tarfile is uncombined (i.e. `YYYYMMDD.raw.nc.tar`), frepp will combine the files and replace the tarfile in archive, then submit the frepp scripts. NOTE: automated refineDiag processing will not occur in this case
* Initialize the Modules environment with the batch environment-provided $MODULESHOME variable instead of fre.properties
* Improved instructions in the error email from pp.starter on how to restart the postprocessing.
* Increased the ncks header pad from 16K to 32K
* Added `1hr` as a synonym for `hourly` for frepp timeSeries specification, and added XML schema enforcement for frequencies
* Various multi-frerun and multi-fremake updates
* XML upgrade utility fre-convert.py updated
* Small bug fix for diag_table_chk

## Patch release notes
* 2022-11-30 (patch 1): Minor adjustments to gaea site files, attempt to relieve pressure on /lustre/f2
  * Change gaea default ptmp to be per-stem, per-experiment
  * Change gaea default to remove workDir after successful exit. Use --no-free to preserve workDir
  * Change default fremake --ncores to be 8
  * Minor fix for multi-fremake
* 2023-01-17 (patch 2): More minor adjustments to gaea site files, attempt to relieve prsesure on /lustre/f2
  * Change gaea default srcDir, execDir, and rootDir to $HOME
  * Use $DEV and $SCRATCH in fre.properties instead of /lustre/f2
  * Test XML updates
  * epmt example notebook improvements
* 2023-04-12 (patch 3): C5 environment updates (needed for C5 OS update)
  * Default C5 platform cshell updated (cray-hdf5/1.12.2.3)
  * mkmf template updates for intel-classic and nvhpc (-DHAVE_GETTID needed). Uses mkmf release 2023.01
* 2023-04-21 (patch 4): C4 environment and mkmf template updates (needed for C4 OS update)
  * Default C4 platform cshell updated (cray-hdf5/1.12.1.3)
  * Use the updated mkmf templates on C4
  * fremake/frerun to disallow using ncrc3 platforms on C4 and vice versa
* 2023-05-12 (patch 5): C3 environment and mkmf template updates (needed for C3 OS update)
  * Default C3 platform cshell updated
  * Use the updated mkmf templates already used on C4/C5
  * fremake/frerun to again allow using ncrc3 plaforms on C4 and vice versa
* 2023-08-03 (patch 6): Compatibility update for output.stager to allow DTN update to use nco/4.7.9
* 2023-11-16 (patch 7): frepp update to process 4-dimensional time variables i.e. diurnal output
