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
* $FRE_SYSTEM_TMP defines the ardiff working directory, is set in the FRE modulefiles, and the runscript checks that this directory is writable. As F5's scratch space is project-specific, the FRE modulefiles cannot easily set this value automatically. As a workaround, the FRE modulefiles are currently using `/gpfs/f5/gfdl/scratch/$USER`, but this directory location is not supported and will be removed in the future. If you encounter this problem, you may comment out the check for `$FRE_SYSTEM_TMP` in your runscript, but then frerun's dual-run feature will not work.
* During early access F5 testing, an intermittent issue was seen where a “staging” FRE output.stager job attempts to remove a lockfile and reports success, but in fact the lockfile is not removed. Subsequent “transfer” output.stager jobs check for the lockfile, see it was not removed as expected by the “staging” job, and exit with a error message. If you see this problem in your FRE output.stager jobs, please report it to the Gaea helpdesk. (ORNL believes that this problem can be improved with DTN system settings related to caching small files.)

## Bug fixes and minor updates
* Simplified frepp workdir cleaning logic to hopefully resolve occasional problems due to overly large arguments passed to “find”.
* Use maximum pp.starter wallclock time of 16 hours for large history file sizes. If your pp.starter jobs time-out due to large history tarfiles, consider reducing your simulation segment size and saving fewer diagnostics.
* Runscript stdout log included in the ascii tarfile output
