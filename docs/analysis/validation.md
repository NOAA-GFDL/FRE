# FRE Analysis Validation Suite

## Introduction

Frepp launches hundreds of analysis scripts accompanying any given fre experiment. Monitoring and hole filling for missing analysis is an arduous task, that is nearly impossible with the current infrastructure currently in place. Users best approach at the moment is to compare their analysis output directory against an example experiment that is thought to be correct. The Fre Analysis Validation Suite (FAVS) is an attempt to remedy this and give users a stand-alone tool that can be incorporated in the workflow to automatically check the output of any given experiment.

FAVS, based around a python utility, will check the output directory of an analysis script against expected results logged in a MySQL database currently residing in a production virtual machine. Any files that are found to be missing will be logged and possibly accessible via a web interface that can be linked to from Curator or mdteam's experiments page.

## Accessing the Code

On GFDL workstations and PPAN:

```module load FAVS```

*NOTE: No other platforms are currently supported*

## Database Overview

The database is a simple MySQL database consisting of five tables dedicated to FAVS. Information contained in this database include the following:

1. Information associated with the Analysis Scripts
 * Script Name (eg: pjk_atmos_mon.csh)
 * Script Version
 * Expected Output Files
1. Information associated with the failed frepp scripts:
 * User Information
 * Experiment Name 
 * Years Being Anayzed

## Commandline Options

The main driver script for FAVS, fre-analysis-validation.py, has the following commandline options:

| Short Option | Long Option | Definition |
|:-----:|:----:|:------------|
| -m | --mode | Mode for the tool to run. (Valid options: add, validate, update) |
| -s | --script | Script name that was run (eg: pjk_atmos_ave_mon.csh) |
| -v | --version | Version of the script that is to be analyzed/ingested. |
| -d |--directory | Ouput directory for the tool to scrape. |
| -u | --user | Username |
| -r | --runscript | Path to the original script that ran |
| -y | --years | Comma delimited years to analyze |
| -b | --batch | Check all subdirectories for multiple runs ( Not yet implemented ) |

*NOTE: There is no option for experiment name, it should be specified alone to remain unified with the rest of fre/frepp*

## Sample Usage

The years, descriptor, and user options allow the tool to dereference and validate output that may include these values in analysis products.

### Ingesting Scripts

Ingesting a new script into FAVS is a quick, simple call to the main python driver on the commandline. Pointing the tool at the output directory where the output is on the commandline.

```fre-analysis-validation.py [ -v version ] -m add -s scriptname -y YR1,YR2 -d OUTPUT/PATH -u $USER descriptor```

This will allow the tool to scrape the output directory that is in the ```OUTPUT/PATH``` and log all of the files that the tool finds in the database.

### Updating Scripts

If the user makes adjustments to their analysis scripts it is easy to make changes to the database.

```fre-analysis-validation.py [-v version ] -m update -s scriptname -y YR1,YR2 -d OUTPUT/PATH -u $USER descriptor```

### Validating Analysis

Once the script has been ingested into the database, users may then check their results quickly with a simple call to the tool.

``` fre-analysis-validation.py [ -v version -m validate ] -s scriptname -d OUTPUT/PATH -y YR1,YR2 descriptor```

Putting these calls at the tail of your frepp analysis wrappers will allow the tool to run automatically at the completion of the script and log any missing files.

## Upcoming Development

* Notifications methods and/or viewable webpages for the missing analysis output.
