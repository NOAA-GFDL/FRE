# Bronx-15 Release Notes

FRE Bronx-15 was released on April 15, 2019. The major feature is gaea Slurm support. MOAB is no longer used, including for PP/AN analysis scripts.

Gaea C3 was converted to Slurm on April 15. Gaea C4 will remain under MOAB until May 13; until then, either Bronx-13 or 14 may be used for C4.

## Slurm-related features and updates
* gaea Slurm support
  * MOAB-to-Slurm changes should largely be transparent to users, with two notable exceptions:
    1. **Executables compiled with OpenMP enabled using source code older than `warsaw_201803` (i.e., `warsaw_201710` and before) WILL NOT WORK under SLURM!!!** This is related to a bug in FMS shared code that was fixed in `warsaw_201803` that affects Slurm particularly. The symptoms are that the model appears to hang, but in fact is running very slow. **The recommended solution is to recompile with FMS shared code from `warsaw_201803` or newer.** If that's not feasible, MSD may have a workaround in some cases (please submit a help desk ticket).
    2. **Cshell runscript inserts that redefine the `runCommand` alias will not work, as the `aprun` command is no longer used.** Some XMLs use these blocks to implement hyperthreading. As hyperthreading is now properly supported in FRE (see notes next), **please remove c-shell that redefines the `runCommand` alias and use the FRE-supported hyperthreading feature if desired.**
  * Some scheduler-related frerun options have changed
    * `--windfall` / `-W` has become `--qos=windfall` / `-q windfall`
    * `--partition` / `-P` has become `--cluster`
    * `--queue` / `-q urgent` has become `--qos=urgent` / `-q urgent`
  * Hyperthreading is better supported
    1. "Partial" (i.e. atmos hyperthreading without ocean) is now allowed
    1. When hyperthreading is on, the threads passed to the namelists are no longer doubled (as they were since hyperthreading was added in Bronx-11). Instead, FRE will reduce the resources needed to maintain the same number of threads. This change was made to be more explicit, so that the user may fully define the configuration and FRE will allocate the proper resources for the given configuration.
    1. Use `frerun --verbose` option to diagnose hypertheading use
    1. Hyperthreading is configured in the `<resources>` tag (with the default off), rather than the `--ht` frerun option; e.g.
       ```
       <resources jobWallclock="00:30:00">
           <atm ranks="30" threads="2" hyperthread="on"  layout="1,30" io_layout="1,3"/>
           <ocn ranks="30" threads="1" hyperthread="off" layout="1,30" io_layout="1,3"/>
           <lnd                                          layout="1,30" io_layout="1,3"/>
           <ice                                          layout="1,30" io_layout="1,3"/>
       </resources>
       ```
       New, component-specific hypertheading shell variables are added: e.g. for the above case,
       ```
       set -r atm_hyperthread = .true.
       set -r ocn_hyperthread = .false.
       ```

* PP/AN Slurm support was nearly complete in Bronx-14, with two MOAB remaining dependencies now resolved:
  1. pp.starter jobs are run through Slurm
  2. Analysis template scripts without Slurm headers are now converted in-flight using a new FRE script `convert-moab-headers` (and then submitted to Slurm). **However, this is an interim solution, and MSD will work with analysis script owners in the coming months to properly convert all analysis scripts in use.**
      * `convert-moab-headers` converts only the subset of MOAB headers commonly in use, and is NOT a complete, all-purpose MOAB-to-Slurm converter tool!!
      * Please submit a help desk ticket if you see problems with analysis scripts header conversion or other Slurm-related issues
      * To convert your analysis scripts yourself, refer to the wiki (https://wiki.gfdl.noaa.gov/index.php/Moab-to-Slurm_Conversion), and try the
`convert-moab-headers` script; e.g. `convert-moab-headers input.csh > output.csh`

## Non-Slurm related features, updates, and fixes
  * fremake
    * Potential fix for the batch compile fork problem seen in recent months
  * frepp
    * Won't call `fredb` if `<publicMetadata DBswitch=(yes|on|true)>`. Instead, a message will be printed to stdout informing the user the appropriate `fredb` call to ingest their XML into Curator. This will resolve some cases of excessive fredb emails sent to users.
    * Add a particular option to the regridder (i.e. `fregrid`). using a new <postProcess xyInterpOptions="whatever"> option. For example, to request CONUS grid output instead of the default global grid, use something like `<component type="conus_conserve_order1" source="atmos_daily_cmip" sourceGrid="atmos-cubedsphere" xyInterp="282,603" interpMethod="conserve_order1" xyInterpOptions="--latBegin 23.4 --latEnd 51.6 --lonBegin 233.6 --lonEnd 293.9">`
    * /work is no longer an valid PTMP directory
  * New freconvert XML converter script
    * `freconvert.py` script convert Bronx-10,11,12 XMLs to Bronx-15.
    * Detailed documentation available (https://gitlab.gfdl.noaa.gov/fre-legacy/fre-commands/blob/release/bronx-15/docs/freconvert.md) and try `freconvert.py -h`
  * `list_paths` updated to ignore test files
  * `output.stager` no longer loads fre-nctools, hsm, and gcp seprately (fre/bronx modulefile now load dependent tools)
  * two F1-related runscript variables were added back to avoid breaking legacy csh inserts in common use

## Update instructions

To update an experiment from Bronx-13 or 14:

1. Verify your executable is using FMS shared code `warsaw_201803` or later. (Refer to the notes above for more information.)
1. Remove c-shell blocks that redefine the `runCommand` alias (`aprun` is no longer used). (Refer to the notes above for more information.)
1. Update your XML by updating the `<platform>/<freVersion>` tag. There are no required XML updates among Bronx-13,14,15.
1. Verify that you have no active Bronx-13 or 14 post-processing jobs. If you do, they may be adversely impacted when the Bronx-15 XML
gets transferred back to GFDL (e.g. when frepp re-parses the XML to submit analysis scripts). If you have Bronx-13,14 postprocessing
for this experiment, please either
   - wait until the post-processing competes before submitting Bronx-15 runscripts,
   - kill the Bronx-13,14 frepp jobs and then re-frepp with Bronx-15 (or accept the possibility of failed frepp jobs), or
   - rename the XML so that the old Bronx jobs at GFDL can continue to use the old XML. In this case, please verify that you aren't using the $(suite) FRE-defined property in your FRE directories (you can confirm this by frelist'ing Bronx-13,14 and Bronx-15 GDFL-side FRE directories (`frelist -d all -p <gfdl-platform>`) and verifying they are identical).
1. Regenerate your runscript using the `--extend` option
   * There are a couple options that have changed:
     * `--windfall` / `-W` has become `--qos=windfall` / `-q windfall`
     * `--queue` / `-q urgent` has become `--qos=urgent` / `-q urgent`
   ```
   module load fre/bronx-15
   frerun <other FRE options> --extend
   ```
1. Submit the runscript; `sbatch` is the Slurm submitting command
