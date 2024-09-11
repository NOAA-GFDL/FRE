# Bronx-21 Release Notes

Bronx-21 was released on January 18, 2024, to support the new gaea F5 filesystem and allow specification of FMS ascii configuration files in legacy table or new yaml format.

## Support for Gaea F5 filesystem
* Summary of F5, changes from F2, and user advice in [F5 Onboarding Guide](https://docs.google.com/document/d/1Z8YnZHaaWAWuyNfVGorrupBxtadOY04c4RL2Y2svZos/edit?usp=sharing)
* Default ncrc5 FRE directories are project-specific scratch location on F5
  * rootDir: `/gpfs/f5/$(project)/scratch/$USER/$(stem)`
  * srcDir: `$(rootDir)/$(name)/src`
  * execDir: `$(rootDir)/$(name)/$(platform)-$(target)/exec`
  * scriptsDir: `$(rootDir)/$(name)/$(platform)-$(target)/scripts`
  * stdoutDir: `$(rootDir)/$(name)/stdout`
  * archiveDir: `$(rootDir)/$(name)/$(platform)-$(target)`
  * workDir: `/gpfs/f5/$(project)/scratch/$USER/$FRE_JOBID`
  * ptmpDir: `/gpfs/f5/$(project)/scratch/$USER/ptmp/$(stem)/$(name)`
* New FRE-defined property $(project) expanded to the value set in the XML `<setup>/<platform>/<project>`
* ncrc5 output stager jobs are run on the `ldtn_c5` and `rdtn_c5` partitions.
* F5 is not swept. The working directory ($workDir) will be removed automatically after normal completion of the compute job. Use the frerun option --no-free to not remove the workDir automatically.

**Recommendations**
* **Use Bronx-21 for new and continuing C5 experiments. Continue to use Bronx-20 for C4 experiments.**
* **F5 is not swept, so you must periodically manually clean your `ptmpDir`.**
* **F5 is not backed up. Consider keeping your “src” FRE directory on $HOME if you are developing.**

## Support for FMS YAML input files
* The FMS diag manager, field manager, and data managers are being rewritten, and as part of the updates they will accept YAML input instead of the traditional (legacy) table formats. Please refer to the FMS release notes for more details and how to configure which input format should be used (i.e. namelist flags).
* For each FMS manager (diag, field, data), choose either the legacy table format or the new YAML format. Specify YAML input files like tables: as external files (set Label to “diagYaml”, “fieldYaml”, or “dataYaml”), inline (use `<diagYaml>`, `<fieldYaml>`, or `<dataYaml>`), or “inline appended”.
* frerun will check that you have specified either the table or yaml format for each of the 3 FMS managers. Specifying both is a fatal error. `frelist --diagtable` prints out the diagtable or diagYaml, whichever frerun would use.
* If YAML formats are used, frerun will combine them using python utilities in the fms-yaml-tools project (https://github.com/NOAA-GFDL/fms_yaml_tools), which are installed at gaea and GFDL and available after module loading FRE. If the YAMLs cannot be combined, frerun will report a fatal error. Otherwise, the combined YAMLs are saved by the runscript in the workDir (diag_table.yaml, field_table.yaml, data_table.yaml), and also copied to the restart archive.
* FRE will not convert tables to YAMLs! Also included in fms-yaml-tools (and available through module loading FRE) are the conversion tools diag-table-to-yaml, data-table-to-yaml, and field-table-to-yaml, that you may use to update your XMLs offline.

**Currently there are no XML changes required if you wish to continue using the legacy tables. FMS will support legacy tables and new YAML formats for some time, but eventually legacy tables will be dropped. Work with your model liaison to update your XMLs.**

## Updated HSM 1.2.7
* Switch to native file locking on PP/AN (from NFSLock). When hsmget tasks are interrupted (e.g. due to a cluster reboot), there are no longer stale lockfiles that previously required manual intervention or a time-out period.

## Updated FRE-NCtools 2023.01.02
* FRE-NCtools is independent of FRE, and is maintained on [github](https://github.com/NOAA-GFDL/FRE-NCtools)

## Known issues
* During early access F5 testing, an intermittent issue was seen where a “staging” FRE output.stager job attempts to remove a lockfile and reports success, but in fact the lockfile is not removed. Subsequent “transfer” output.stager jobs check for the lockfile, see it was not removed as expected by the “staging” job, and exit with a error message. If you see this problem in your FRE output.stager jobs, please report it to the Gaea helpdesk. (ORNL believes that this problem can be improved with DTN system settings related to caching small files.)

## Bug fixes and minor updates
* Update to how ardiff sets its temporary working directory. Previously, FRE modulefile set $FRE_SYSTEM_TMP, and the runscript checks that this directory is writable; frecheck and output.stager assume the variable is set due to module loading FRE. The problem is that F5's scratch space is project-specific, which can be set correctly through FRE but not FRE modules. Therefore, the ardiff tempdir is set in FRE properties (FRE.tool.ardiff.tmpdir) and used by frecheck and output.stager to set TMPDIR, which ardiff uses. Interactive ardiff users must set $TMPDIR themselves.
* Simplified frepp workdir cleaning logic to hopefully resolve occasional problems due to overly large arguments passed to “find”.
* Use maximum pp.starter wallclock time of 16 hours for large history file sizes. If your pp.starter jobs time-out due to large history tarfiles, consider reducing your simulation segment size and saving fewer diagnostics.
* Runscript stdout log included in the ascii tarfile output
* Removed orion and ncrc3 sites which are no longer supported

## Patch release notes
* 2024-01-31 (patch 1): Varied adjustments and bug fixes
  * Remove all mentions of $FRE_SYSTEM_TMP variable. Traditionally, this was set in FRE modules, but because F5's scratch directory is project-specific, the ardiff temporary directory is now set in FRE properties. frecheck and output.stager's dual-run checking are the only uses of ardiff. Interactive ardiff users can set TMPDIR themselves.
* 2024-02 (patch 2): Bug fix for the simplified frepp find cleaning logic
* 2024-07-25 (patch 3): Three bug fixes and two adjustments
  * Output stager fix to check exit status of NCO calls and exit if NetCDF file cannot be read. (Previously, the NCO error was incorrectly interpreted as subregional history files that cannot be combined.)
  * Output stager fix to remove temporary file if combiner fails. (Previously, if combine-ncc failed, its output file was left in the working directory which caused required manual removal in order to retry.)
  * frepp fix to not modify input PTMP history files. (Previously, frepp modified a NetCDF attribute before running fregrid. When using /xtmp for PTMP, sometimes the attribute would be modified twice resulting in a fregrid error.)
  * New ardiff options -d, -m, and -C to check only data, only metadata, and stop early.
  * Output stager to stop unnecessary checking for distributed subregional variable differences in restart files
* 2024-08-22 (patch 4): Add C6 site files and bug fix for verifying that the distributed history files can be combined
* 2024-09-11 (patch 5): Fix the C6 runscript
