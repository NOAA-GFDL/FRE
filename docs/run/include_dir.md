# Include directory feature

## Background and motivation
As FRE has developed over the last decade, users have wanted FRE to do more with the XML description of the model.  As the FRE development moves slower than the users would like, groups at GFDL have come up with methods to get FRE to do things it was never designed to handle.  This has lead to the current situation in use in some of the workhorse models at GFDL where <csh> sections have added the manual transfer of files and directories back to GFDL to allow post-processing to work.

This include directory feature can transfer needed include files (diag tables, namelists, analysis scripts, etc) from computing sites to postprocessing sites, and provides a cross-site reference $(includeDir) to use within XMLs.

## Usage summary
The *include* directory is defined in the `<platform>/<directory>/<include>` tag with the other FRE directories.

`frerun` sets the runscript variables $includeDir and $includeDirRemote if the remote site *include* directory exists, and the runscript conveys those variables to the `output.stager` via the arg file. The `output.stager` copies $includeDir to GFDL's $includeDirRemote if those variables are defined.

You may set the *include* directory to be within the directory containing the XML by using the FRE-defined property $(xmlDir). This would mimic how some groups organize their include files. For example,

```
<directory stem="$(FRE_STEM)">
    <include>$(xmlDir)/awg_include</include>
</directory
```

You may also referencing include files using $(includeDir). e.g.
`<namelist file="$(AWG_INPUT_HOME)/nml/am4p12r13_common.nml"/>` could be replaced with with
`<namelist file="$(includeDir)/awg/nml/am4p12r13_common.nml"/>`.

## Defaults
The default *include* directory location is `$(xmlDir)/include`.

## Errors
`frerun` will fail
* If the *include* directory exists, but isn't a directory
* If the *include* directory is greater than 300 MB

If configured to transfer (i.e. frerun sets $includeDir and $includeDirRemote), `output.stager` will fail
* If the *include* directory doesn't exist or isn't readible
* If the copy transfer fails

## Diagnostics
`frerun --verbose` will print out whether the *include* directory will be configured to transfer and its size.

`output.stager` will print out if the transfer was successful, or if it wasn't configured to transfer.
