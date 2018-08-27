# Bronx-12 Release Notes

FRE Bronx-12 was released in April 2017. The major features were support for the Warsaw FMS release and CMIP6, along with smaller features and bug fixes. There have been 8 patches, mostly containing additional changes needed for CMIP6 runs, and more bug fixes.

## Patches

**Patch 8: 10 August 2018**
- Updates to make template formats for Intel, GNU, Cray, and PGI from the NOAA-GFDL/mkmf project / MOM development (#314)
- Updates to the Intel make templates to support Intel-18 (-qoverride-limits/-qopenmp) (#314)
- New post-process `<timeAverage>/<variables>` tag to allow subsetting of variables similar to existing `<timeSeries>/<variables>` tag
- 2 fixes to the unmasked/reference ocean_static.nc appending feature. To help ocean regridding, publishing, and analysis, during output staging at gaea, if the gridSpec file is a tarfile and it contains "ocean_static.nc", that file will be appended to the ocean_static.nc history file. The fix only appends data, not metadata, to prevent a problem uncovered in testing where older/incorrect cell_methods from the gridSpec tarfile ocean_static was overwriting newer/correct cell_methods from the model output. The second fix allows the tarfile contents to be specified with "./" or not.

**Patch 7: 2 July 2018**
* output.stager and pp.starter jobs are submitted to the account used in the runscripts and configured in the XML. This corrects a long-standing bug where these output.stager/pp.starter jobs were submitted to the user's default allocation (which is often, but always, the same as the runscript/XML allocation).

**Patch 5/6: 30 April 2018**
* includeDir transfer bug-fix (Bronx-12 introduced a transfer mechanism to copy an awg_include-type directory from gaea to GFDL, which failed to work properly in some cases)
* adjust_dry_mass bug-fix (Bronx-12 introduced a FRE runscript variable to indicate whether the model start time is equal to the current model time, which was set incorrectly for restart regression runs)
* Updates from MOM development, which will be needed for CMIP runs that use MOM6
    * new POSIX Bourne shell list_paths. No difference, but includes a -L symlink option that will be used by MOM
    * mkmf updates from github NOAA-GFDL/mkmf project
* Change to Cray make template to handle non-OPENMP builds (fixes MOM build error when not using openmp)
* Update to make templates for intel and GNU for GFDL workstations (to fix build error)
* frepp 30-min timeseries update. “30min” is now an accepted timeseries frequency, e.g.
`
     <component type="CFsite" source="CFsites">
        <timeSeries freq="30min" chunkLength=”5yr"/>
      </component>
`
* frepp timeSeries <variables> tag update. When the <variables> tag is used to request a certain set of fields for timeseries, static fields are passed through fregrid. split_ncvars will then include these needed CMIP fields (a,b,*_bnds) in the split-out fields
* FRE tools now use a relative-path perl rather than the system perl, so that the modulefiles can load a suitable version of perl for each site.


**Patch 4: January 2018**
* Turn off default dual-running for C4
* Added `area` to frepp hard-wired exception list to regrid using conserve_order1

**Patch 3: November 2017**
* For regridding refineDiag history files, look for associated_files in regular history files in addition to history_refineDiag files
* Fix in output.stager that resulted in incorrect 600 permissions on some history files
* frepp fix to generate monthly timeseries from daily history data
* fremake fixes for cray compiler

**Patch 2: October 2017**
* Changes to handle the C3 software upgrade
* New scheme to pass unmasked ocean_static.nc fields into ocean_static.nc history file (needed for regridding certain ocean fields, and also desired generally e.g. for LAS). The feature is activated if a experiment uses an ocean mask is used. If activated, the output.stager will try to append an unmasked/reference ocean_static.nc file to the ocean_static.nc history file. If the gridSpec file is a tarfile and it contains ocean_static.nc that file will be used. Otherwise, it will use the ocean_static_no_mask.nc "history" file (style in some MDT XMLs). If no reference file is found, a warning will be printed but no error. The output.stager HS logs contain the logs for this feature.
* Added `frelist --diagtable` option that prints out the full diagtable to stdout
* output.stager bug fix related to uncompressing land restart files
* Bug fix for frepp automatic Curator ingestion feature
* Adjustment for frepp -A to allow out-of-order analysis scripts if -Y or -Z is used
* Changes to XML schema CMIP6 `<publicMetadata>` tags
* Added some ocean fields to the hard-wired unregriddable list
* Use associated_files in tripolar regridding (was already done for tiled regridding)

**Patch 1: June 2017**
* Bug fix for the frepp --plus option
* output.stager to not decompress particular type of compressed land history files (static_veg_out)
* use the PPAN bigmem queue for ocean_annual and ocean_monthly frepp jobs
* frepp changes to increase /ptmp: only active job schooling if ptmpDir is on /vftmp and change default ptmpDir to be /ptmp/$USER (#240)
* Change to XML schema to allow more xinclude use
* fremake fix for C4 Intel-15 openmp compiles
* frepp fix for regridded tripolar timeaverages

## Features
* **New FRE include directory and include directory transfer**. A new FRE directory `includeDir` is defined at all sites and is transferred by the `output.stager` from remote sites to GFDL. The goal is to standardize the referencing of AWG and OWG include files (e.g. diag tables, data tables, analysis scripts) within the XML and normalize the transfer process currently done within csh blocks. See [feature documentation](/docs/run/include_dir.md).
* **Analysis validation suite**. Not a FRE feature per se, but a tool to check expected output of analysis scripts. See [feature documentation](/docs/analysis/validation.md).
* **Namelist partial inheritance/override feature (experimental)**. Allows a child experiment's namelist to partially inherit from its ancestor namelist. Note: This behavior is limited to one level, see the [feature documentation](/docs/run/namelist_override.md) for more information.
* **First-year check part of frerun**. Users have been running a home-dir script to check whether it is the first year of the simulation, and setting a namelist variable accordingly. Now `frerun` has been updated to check for the first year and set the runscript shell variable $adjust_dry_mass to ".true." for the users on the first year, otherwise this value is ".false.".
	* Action Items for Users:
		* Update XML to remove Larry's script: `/ncrc/home1/Larry.Horowitz/bin/adjust_dry_mass.csh` or the equivalent logic and replace with $adjust_dry_mass
		* No adverse impacts if not removed from the user's XML
* **Native Scalar Diagnostics**: The scalar diagnostics have been subsumed into `frepp` and will run automatically if an experiment is ingested into the Curator database. These values are stored in the centralized MySQL database and out of the user's home directory.

## CMIP6 features and adjustments
**frepp**
* Calls `split_ncvars` with CMIP compliant flag if postprocess component contains attribute `cmip=yes|true|on`. 
	* Action Items for Users:
		* Set `cmip` attribute for postprocessing components that will be published for CMIP6. e.g.
```
    <component type="atmos_cmip" source="atmos_month_cmip" sourceGrid="atmos-cubedsphere" xyInterp="180,288" cmip="yes">
```
* Adjustment to handle case where `fregrid` produces no output due to all fields being unregriddable. Note that if there are no temporal fields to process, the frepp runscript will give a "No usable variables exist" error as before.
* Before generating a fregrid remap file, frepp will check whether a suitable remap file exists in a new shared FMS location. The reason for this is that remap files for ¼ degree tripolar can't be generated by ppan `fregrid`, so we generate them on gaea and store them in the FMS location.
	* Action Items for Users:
		* If you find `fregrid` unable to create a remap file on ppan (in stdout log, "FATAL Error: nxgrid is greater than MAXXGRID/nthreads, increase MAXXGRID, decrease nthreads, or increase number of MPI ranks"),
			* please open a Help Desk ticket and Modeling Systems will generate an appropriate remap file and save to the shared location, or
			* you may create a fregrid remap file on gaea yourself and reference it in your XML
				1. Find the gridSpec tarfile used by your experiment and untar it in $CTEMP
				2. Start an interactive batch session: `msub -I -l walltime=1:00:00,size=5`
				2. `aprun -n 120 fregrid_parallel --input_mosaic ocean_mosaic.nc --remap_file fregrid_remap_file_360_by_180.nc --nlon 360 --nlat 180
				3. Copy remap file to GFDL
				4. Tell frepp to use the remap file:
```
<component type="ocean" source="ocean_monthly" sourceGrid="ocean-tripolar" xyInterp="360,180">
<dataFile label="xyInterpRegridFile">
<dataSource site="gfdl">"/path/to/fregrid_remap_file_360_by_180.nc"</dataSource>
</dataFile>
```
* Don't regrid ocean_geometry history files or certain known non-regriddable fields

**fregrid**
* To preserve CMIP-compliant variable metadata, 0 and 1-dimension variables will be copied to regridded output. As before, unregriddable fields (i.e. those with attribute `interp_method=none`) will not be copied or regridded.
* If all requested regridded fields are unregriddable, returns 0.

**split_ncvars**
* Only coordinate variables used by the individual variable are copied to the output files.
* Support for *formula_terms* attribute. Static variables in the input file listed in *formula_terms* are included in the output file, otherwise are listed in global attribute *external_variables*
* Removal of degenerate *scalar_axis* dimension (typically included in near surface history files)
* Coordinate variable *heightN* is changed to *height* and *plevX* is changed to *plev*
* A CMIP option makes axis attributes CMIP-compliant and omits FMS-style time average attributes

## Adjustments
**fremake/frerun**
* To prepare for upcoming software updates to C4, **`fremake` and `frerun` now require full platform specification** (i.e. --platform ncrc4.intel16 rather than --platform intel16). Users may now submit fremake and frerun jobs to either C3 or C4 from any gaea head node.
* NCRC sites now use `-l nodes=\d+` for all queues

**frerun**
* `output.stager` updated to allow handling of unstructured grid land history files. Will decompress the land unstructured grid files before combining.
* Only validate the publicMetadata tags for CMIP experiments, these tags will otherwise be ignored by schema validation.

**frepp**
* Change of job dependencies from $PBS_JOBID to $MOAB_JOBID to support MOAB upgrade from 7 to 9.
* Slight optimization to using compressed netCDF4 files (experimental). frepp will generate compressed NetCDF4 output if the history files are compressed. Generate compressed NetCDF4 history output (compression level 2 and shuffle) using frerun -Z.
* Only validate the publicMetadata tags for CMIP experiments, these tags will otherwise be ignored by schema validation.

## Fixes
**fremake**
* Fixed user messages referencing outdated CVS source control system

**frerun**
* `output.stager` properly combines icebergs including for ensemble regression runs
* Resource specification-related runscript template shell variables are now added to the runscript even for non-coupled runs.

**frepp**
* Full support for the `--plus` option. The plus option specifies a range of years for frepp processing, i.e. for `-t YYYY --plus N`, produce products and analysis between YYYY and YYYY+N. Previously, the plus option required a 1-year chunksize or a refineDiag script as a placeholder to call the next year's frepp, and so was partially supported/deprecated. Now, the `--plus` option should work in all cases and is a supported way to re-process a range of years.
* Frepp only submits analysis script when ending analysis time is equal to the time passed by the `-t <time>` option. This was done to address an occasional problem where frepp processing on a chunk boundary would take longer than the next year's frepp job. The next year's frepp job would complete, kick off analysis scripts including for the previous year, which would obviously fail since the first year's postprocessing isn't complete. When the first year's frepp calls its analysis scripts, they are already generated, so frepp skips them. The result is missing analysis figures, which this adjustment will fix.
* frepp option -W to modify the job wallclock time is now used in all cases, which may be helpful for high-resolution postprocessing.
* Fix to expand which users can use /ptmp on GFDL sites.
* More flexible parsing of timeseries chunk length units (`<timeSeries chunkLength=Xunits>`), allowing *mo*, *mon*, *month*, and *months*, and *y*, *yr*, and *years*.

**fremake/frerun**
* Check to see if `<platform>/<project>` appears invalid (i.e. YOUR_GROUP_LETTER), and have fremake/frerun give an error (rather than have job mysteriously blocked).
* A user's group is checked to determine directory write privileges. Previously only the user's primary group was checked; now all the groups are checked.

**freppcheck**
* Now appropriately checks for output associated with min or max fields. (If a diagTable-requested maximum field ends in `max`, freppcheck would check for a field ending in `_max` unless the field already ended in `_max`. However if the field ended in `_MAX`, freppcheck would look for `_MAX_max`. This fixes the case-sensitive problem.)

**XML**
* XML schema now understands averageOf attribute in the <timeSeries> XML tag.
* Forbid experiment names that contain + (FRE uses + as a template filler)

## XML Changes
* Retirement of deprecated `<cubictoLatLon>` tag used for regridding cubed sphere model output to at Lat/Lon grid.
	* Action Item for Users:
		* Remove instances of cubicToLatLon="none"
		* Replace instances of cubicToLatLon"x,y" with xyInterp="x,y"
		* sourceGrid is mandatory if an xyInterp is specified within the component.

* New cmip attribute within `<postProcess>/<component>` tag, to make axis attributes CMIP compliant and omit FMS-style time average attributes.
	* Action Items for Users:
		* Set cmip attribute for postprocessing components that will be published for CMIP6. e.g.
```
<component type="atmos_cmip" source="atmos_month_cmip" sourceGrid="atmos-cubedsphere" xyInterp="180,288" cmip="yes">
```
* PublicMetadata XML Change to support CMIP6 global metadata.
    * Action Items for Users:
        * Make sure that all of your publicMetadata tags are correctly set if you’re running a CMIP6 experiment. For more information, visit the [schema documentation](http://cobweb.gfdl.noaa.gov/~pcmdi/CMIP6_Curator/xml_documentation/index.html). 

## Documentation
* [New document on frepp hole filling capabilities](/docs/postProcess/holeFilling.md)
* New document on guidance/best practices for XML xincludes

## Known issues
* freppcheck will incorrectly report missing output due to unregriddable fields
	* No Bronx fix is planned for this issue, as it requires pulling history from archive.
