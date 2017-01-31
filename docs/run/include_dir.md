# Include directory feature

## Background and motivation
As FRE has developed over the last decade, users have wanted FRE to do more with the XML description of the model.  As the FRE development moves slower than the users would like, groups at GFDL have come up with methods to get FRE to do things it was never designed to handle.  This has lead to the current situation in use in some of the workhorse models at GFDL where <csh> sections have added the manual transfer of files and directories back to GFDL to allow post-processing to work.  Each group developed their own method.

This include directory feature is can transfer needed include files (diag tables, namelists, etc) from computing sites to postprocessing sites.

## Usage summary
A new *include* directory type has been created, with defaults for all sites (described next) and can be defined in the `<platform>/<directory>/<include>` tag with the other FRE directories.

`frerun` sets the runscript variables $includeDir and $includeDirRemote if the remote site *include* directory exists, and the runscript conveys those variables to the `output.stager` via the arg file. The `output.stager` copies $includeDir to GFDL's $includeDirRemote if those variables are defined.

On remote computing sites, you may set the *include* directory to be within the directory containing the XML by using the FRE-defined property $(xmlDir). This would mimic how some groups organize their include files. For example,

```
<directory stem="$(FRE_STEM)">
    <include>$(xmlDir)/awg_include</include>
</directory
```

## Defaults
At GFDL, the *include* directory defaults to `/nbhome/$USER/$(stem)/$(name)/include`. On computing platforms, the default is alongside the `src` directory in unswept or the equivalent.

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
