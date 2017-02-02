# FRE Analysis Validation Suite

## Introduction

 Frepp launches hundreds of analysis scripts accompanying any given fre experiment. Monitoring and hole filling for missing analysis is an arduous task, that is nearly impossible with the current infrastructure currently in place. Users best approach at the moment is to compare their analysis output directory against an example experiment that is thought to be correct. The Fre Analysis Validation Suite (FAVS) is an attempt to remedy this and give users a stand-alone tool that can be incorporated in the workflow to automatically check the output of any given experiment.

FAVS, based around a python utility, will check the output directory of an analysis script against expected results logged in a MySQL database currently residing in a production virtual machine. Any files that are found to be missing will be logged and possibly accessible via a web interface that can be linked to from Curator or mdteam's experiments page.

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