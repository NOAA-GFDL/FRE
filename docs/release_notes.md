# Bronx-23 Release Notes

Bronx-23 was released in January 2025, to provide better support for FMS YAML input files, NetCDF-4, and compatibility with the next-generation of FRE tools ("FRE 2025").

## New
* Compatibility with FRE 2025 'fre make'
  * Users may use FRE 2025 'fre make' to create a bare-metal executable or a model container with dependencies and executable, and run with Bronx-23 frerun.
  * For bare metal executables, specify path to the executable in the `<experiment>/<executable>` tag and run frerun as usual.
  * For the model container, specify path to the container in the `<experiment>/<container>` tag and run `frerun --container`
  * FRE 2025 documentation available: https://noaa-gfdl.github.io/fre-cli/usage.html#build-fms-model
  * More detailed [step-by-step instructions](run/model_container_integration.md) to use model containers is available.
* Compatibility with FRE 2025 'fre pp'
  * Configure by creating postprocessing YAMLs; FRE 2025 documentation available: https://noaa-gfdl.github.io/fre-cli/usage.html#postprocess-fms-history-output
  * Set GFDL platform's FRE version (`<setup>/<platform>/<freVersion>`) to "2025.XX" (use the latest available)

**FRE users may use FRE 2025 for make and/or pp (i.e. "fre make" and "fre pp"), or continue to use Bronx fremake and frepp. Both sets of compile and postprocessing tools will be supported for some time. However, we encourage users to update, as FRE 2025 is being actively developed and Bronx is receiving only essential updates. Over time standard FMS model configurations and labwide model configurations will transition to FRE 2025 configurations for compiling and postprocessing.**

* Proper support for rewritten FMS diag, field, data manager YAML configuration
  * The FMS diag manager, field manager, and data managers are being rewritten, and as part of the updates they accept YAML input instead of the traditional (legacy) table formats. Please refer to the FMS release notes for more details and how to configure which input format should be used (i.e. namelist flags).
  * For each FMS manager (diag, field, data), choose either the legacy table format or the new YAML format. Specify YAML input files like tables: as external files (set Label to “diagYaml”, “fieldYaml”, or “dataYaml”), inline (use `<diagYaml>`, `<fieldYaml>`, or `<dataYaml>`), or “inline appended”.
  * frerun will check that you have specified either the table or yaml format for each of the 3 FMS managers. Specifying both is a fatal error. `frelist --diagtable` prints out the diagtable or diagYaml, whichever frerun would use.
  * If YAML formats are used, frerun will combine and validate them using fms-yaml-tools (developed on https://github.com/noaa-gfdl/fms_yaml_tools and module available at GFDL)
  * The combined YAMLs are saved by the runscript in the workDir (diag_table.yaml, field_table.yaml, data_table.yaml), and also copied to the archived restart tarfile. If the YAMLs cannot be combined or are invalid, frerun will report a fatal error and leave the $TMPDIR for inspection. Please remove the tmpdir afterwards.
  * FRE will not convert tables to YAMLs! Also included in fms-yaml-tools are conversion tools that you may use to update your XMLs offline.

**Use Bronx-23 if you are using modern FMS yaml (diag, field, data) input files.**

* End-to-end NetCDF4 support
  * NetCDF4 supports larger filesizes and other useful features (chunking and compression)
  * Various tool usages updated to not output Netcdf-3 format (and instead respect the input format)

**To use NetCDF4, set your diag manager namelists to save history files in NetCDF4 format (`netcdf_default_format = "netcdf4"`), and your postprocessed output will also be in NetCDF4 format.**

## Fixes
* Removed subregional variable/dimension checking for restart files.
* Several tool updates and output.stager fixes for problems that can occur when the gaea filesystem is having problems (such as being unmounted while the staging job is running). The updates reduce the possibility of data loss in such scenarios.
  * Output stager checks that history files are NetCDF files before processing them.
  * mppnccombine and combine-ncc now sync output to filesystem for exiting
* Reduce number of batch.scheduler.submit retries to 2. batch.scheduler.submit is a sbatch wrapper that includes some error and retry logic that was more valuable for MOAB than Slurm. Some heavy FRE users ran into unfortunate thrashing conditions where an output.stager job was trying to submit more stagers but could not due to the Slurm per-user running/pending job limit (currently 50).
* add --export=ALL for non-coupler experiments

## Updates
* The Bronx-23 module (fre/bronx-23) does not bring "ncdump" into the PATH. Traditionally, on gaea, the FRE modules loaded cray-netcdf in order to make "ncdump" available for users, scripts, and within fre-nctools; separately, the default platform cshell is maintained in fre-commands, which also contains cray-hdf5 and cray-netcdf module loads. Previously, we ensured that those versions are identical, which limited flexibility. FRE-NCtools is now more self-contained w.r.t dependencies such as NCO tools and ncdump, and removing the cray-netcdf module load from the FRE modules makes FRE more robust and easier to maintain.
* Reduce load on gaea DTNs. gaea DTN policy currently limits the number of running/pending jobs to 50 per user. Users with multiple streams or ensembles can easily hit this limit, and FRE's output.stager is not designed to handle scenarios where a batch job cannot be submitted. Therefore, we sought to reduce the number of FRE-generated DTN jobs by about half:
  * Regression runs are no longer transferred by default; use frerun --transfer to enable
  * Combine output.stager ascii-save, ascii-transfer, and restart-save processing into one batch job with the "AR" label. The argFiles are still separate, though (i.e. H, R, A). If the initial job fails, output.retry will retry the jobs as separate jobs.
  * Run work-dir cleaning jobs on the login nodes (to reduce load on DTNs)
* New output.retry option `-o` to override transfer limits and submit staging jobs immediately
* ardiff updates: New options to compare metadata/data only and limit number of differences when force comparing. Use "ardiff -h" to see the options.
* Updated set of mkmf templates, 2024.01
* refineDiag pass thru Slurm options, e.g. for requesting nodes with certain qualities. To use, add the desired Slurm sbatch directives to the `SlurmOptions` attribute within the `refineDiag` tag. For example, to submit refineDiag jobs with the `--constraint=bigmem` sbatch directive, use `<refineDiag script="/path/to/my/refinediag.csh" slurmOptions="--constraint=bigmem" />`. The frepp --verbose option will print the custom sbatch directives to stdout.
* Subregional variable/dimension checking (done by output.stager) is unnecessary if using the modern diag manager and is now skipped

## Patch notes
* 2025-06-16 (patch 1): Default Cray Programming Environment update: PrgEnv 8.6.0, cray-hdf5/1.14.3.5, cray-netcdf/4.9.0.17. Updated mkmf templates (2025.02)
