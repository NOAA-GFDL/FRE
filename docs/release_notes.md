# Bronx-15 Release Notes

FRE Bronx-15 was released on April 15, 2019. The major feature is gaea Slurm support. MOAB is no longer used, including for PP/AN analysis scripts.

Gaea C3 was converted to Slurm on April 15, and Gaea C4 is being converted to Slurm on May 14. After May 13, Bronx-15 is the only supported FRE on gaea.

## Known issues (updated 2019-05-13)
* Not-yet-resolved
  * **FRE emails from the compute node environment don't work.** When the runscript fails, Slurm will send an email as usual with an empty body, but the more descriptive FRE email with paths to the stdout location and any core files are not sent. We are working with ORNL on a solution so these helpful FRE emails are again sent, and hope to have a plan to resolve this by May 24.
  * **Automated post-processing (at GFDL) uses an incorrect group.** Slurm assumes the user/group environment is homogeneous across clusters, which for GFDL users is true for users but not for groups (currently). In particular, the default group of GFDL users at gaea is "gfdl"/gid=500; when automated post-processing starts, it runs under the gid=500 group, which users aren't a member of. The result is that files produced by the automated postprocessing are owned by group "500" rather than the user's default group. We are working on a solution to have pp.starter run frepp under the user's default group, which will be patched to Bronx-15 soon (May). Additionally, we believe the Systems group will name the "500" group "gfdl" and add all users to it, so that the group ownership of existing Bronx-15 post-processing is more consistent.
* Resolved
  * A few users hit out-of-memory errors in their LDTN output.stager jobs, due to Slurm's default memory allocation, which previously was 8 GB. (MOAB handled memory allocation differently). Since May 7, ORNL has increased the default LDTN memory allocation to 16 GB, which we believe is sufficient. Please submit a help desk ticket if you encounter this issue.
  * Between April 15 and May 3, frepp contained a bug that impacted the regridding method used by fregrid. The bug forced fregrid to ignore the `interp_method` variable attribute in the history files and instead use `conserve_order2`. This directly affected the variables that should have used either `interp_method="NONE"` or `interp_method="conserve_order1"`.
    * The regridding method used by fregrid is in the `interp_method` variable attribute within the post-processed files, which you can view using `ncdump`; e.g.
    ```
    >ncdump -h /archive/oar.gfdl.cmip6/CM4/warsaw_201803/CM4_amip/gfdl.ncrc4-intel16-prod-openmp/pp/aerosol_cmip/ts/monthly/6yr/aerosol_cmip.200901-201412.ua.nc | grep interp_method

    ua:interp_method = "conserve_order2" ;
    ```
    In that case, `ua` was regridded using 2nd order conservation.
    * We have contacted users whose post-processed output was affected.
    * If your work was affected, the solution is to rerun the postprocssing (please open a help desk ticket if you need help).
    * We believe these variables were most likely to have been regridded with 2nd order conservation when 1st order should have been used: land_mask, zsurf, IWP_all_clouds, WP_all_clouds, WVP, ice_mask, prc_deep_donner, prc_mca_donner, prec_conv, prec_ls, precip, snow_conv, snow_ls, snow_tot, swdn_sfc, swdn_sfc_clr, swdn_toa, swdn_toa_clr, swup_sfc, swup_sfc_clr, swup_toa, swup_toa_clr, uw_precip, wind_ref
  * Since April 22, gcp now works on the compute node environment. Many production XMLs transfer the `awg_include` directory in a runscript c-shell block. Before then, the failure to transfer `awg_include` could result in frepp failures about missing namelists.
  * Since April 23, `output.retry` correctly queries the Slurm queue to determine whether an `output.stager` job was already submitted. Before then, `output.retry` submitted duplicate output.stager jobs to process the same argFile. When the duplicate job ran, it would fail due to the argFile already being processed, and the user would get a somewhat alarming email. These errors were spurious as the `output.stager` jobs had already runs successfully.

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
       **NOTE: Some XMLs contain c-shell sections that set the variable `atm_hyperthread`; this variable is now a read-only runscript-defined variable and can no longer be used in c-shell blocks.** Moreover, c-shell hyperthreading logic is no longer needed as FRE supports hyperthreading now.

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
