# Single-level namelist inheritance/override feature

## Background and motivation

Experiment inheritance is a FRE feature that allows an experiment to inherit parameters from another experiment. Namelists are collections of key/value pairs used to configure FMS model components; each collection or namelist has a name that indicates its purpose and uniqueness from other namelists.

Currently, namelists are inherited on an entire namelist/all-or-nothing basis based on the namelist's name, using these priorities (see http://wiki.gfdl.noaa.gov/index.php/FRE_User_Documentation#Special_Case:_Namelists):
1. experiment's inline namelists
1. experiment's external namelists
1. parent experiment's inline namelists
1. parent experiment's external namelists
1. repeat for additional experiment ancestors

If a namelist is specified twice, the one with the higher priority is included and the others are ignored.

A common task is creating an experiment to be identical to another experiment except one or two parameters of one namelist. Currently, you must copy the entire namelist to the child experiment, then add or change the desired parameters. To make that exercise easier and less error-prone, users have requested a partial namelist inheritance option. For a namelist using this requested option, its values would be combined with the immediate lower priority namelist, with the child settings overwriting any values that they both have.

MS has been concerned this feature could result in greater confusion of which namelist settings are actually used in the experiment. In today's inheritance and xinclude-rich XMLs, having some namelists partially inherit and some not would undoubtedly be harder to visually inspect, and may do more harm than good for experiment XML maintenance, inspection, and clarity.

Moreover, FRE's namelist management code doesn't yet use a proper namelist parser; the result is that this override feature is limited to simple namelists (one key/value pair per line). In particular, multiple declarations per line and embedded newlines in values aren't handled properly, AND doesn't warn the user about the mis-handling.

Thus, we consider this override feature experimental in Bronx-12, intended for one-off model development use by advanced FRE users. More proper namelist parsing may be added to a future FRE version.

## Usage summary

This feature will allow a child experiment's namelist to override/partially inherit the namelist values of the next inherited namelist. The child namelist will be combined with the parent namelist, using the child's values for keys shared by both namelists.

Activate the feature by setting a new <namelist> attribute *override* to *yes*, *true*, or *on*. The feature is not supported in external namelists. This feature may only be used in child experiments; FRE will throw a fatal error if an inherited experiment's namelist has the `override="yes"` attribute set.

The overridden resulting namelist's order should be sensible and expected. Settings in the child namelist that exist in the base namelist will be placed identically to facilitate diff tools. Settings in the child namelist that don't exist in the base are added to the top of the resulting namelist.

## Example

As an example, consider an experiment identical to *c96_solo_lm3p6*, except overriding the *atmos_bottom* setting of the *atmos_prescr_nml* namelist and adding a *checksum_required* setting to the *fms_io_nml* namelist. The child experiment would look like:

```
<experiment name="c96_solo_lm3p6_mod" inherit="c96_solo_lm3p6">
	<input>
		<namelist name="atmos_prescr_nml" override="yes">
			atmos_bottom = 35.0,
		</namelist>
		<namelist name="fms_io_nml" override="yes">
			checksum_required = .false.,
		</namelist>
	</input>
</experiment>
```

For inline namelists only, use the `frelist --evaluate` option to see what the ancestor/base namelist settings would be. For example,
```
> frelist --evaluate "input/namelist[@name='atmos_prescr_nml']" -x lm3.xml -p ncrc3.intel c96_solo_lm3p6
         read_forcing = .true.,
         gust_to_use  = 'computed',
         gust_min     = 0.01,
         atmos_bottom = 50.0,
```

Run `frerun` with the verbose option to print the inherited namelist, child namelist, and the resulting overridden namelist.
```
> frerun -v -x lm3.xml -p ncrc3.intel c96_solo_lm3p6_mod
<NOTE> : Extracting namelists...
<NOTE> : Namelist override for atmos_prescr_nml, child settings:
<NOTE> : 		atmos_bottom = 35.0,
<NOTE> : Namelist override for atmos_prescr_nml, base settings:
<NOTE> :        	atmos_bottom = 50.0,
                  	gust_min     = 0.01,
                  	gust_to_use  = 'computed',
                  	read_forcing = .true.,
<NOTE> : Namelist override for atmos_prescr_nml, combined settings:
<NOTE> :          	atmos_bottom = 50.0,
         		atmos_bottom = 35.0,
                  	gust_to_use  = 'computed',
                  	gust_min     = 0.01,
                  	read_forcing = .true.,
<NOTE> : Namelist override for fms_io_nml, child settings:
<NOTE> : 		checksum_required = .false.,
<NOTE> : Namelist override for fms_io_nml, base settings:
<NOTE> : 	 	max_files_w = 100,
         		threading_read  = 'multi',
         		max_files_r = 100,
<NOTE> : Namelist override for fms_io_nml, combined settings:
<NOTE> : 	 	threading_read  = 'multi',
         	 	max_files_w = 100,
         		checksum_required = .false.,
         		max_files_r = 100,
```
