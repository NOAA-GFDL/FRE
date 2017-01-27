NiNaC is Not another Curator
============================

Rather its a collection of hacks to extend the abilities to harvest, store, and mine data.  Currently its only implimented for use on Gaea.

Contents
--------

Currently:

* Scripts to build the hashForest
  * getSrcDirSignature.sh : Generates a srcTree
  * getBldDirSignature.sh : Generates a bldTree
  * getRunDirSignature.sh : Generates a runTree
* nml2json.py : Some python and regex foo to parse FORTRAN (input.)nmls into python dictionaries, compact serialized JSON or pretty-printed JSON files.  These are natively more portable and allow for easier diffs...


Slated:

* nmlDiffer.py : Extend json_diff to wrap nml2json.py if needed, and allow for pretty printing etc...
* diag_table2json.py : Target parsing the diag_tables into similar...
* getXmlSignature.sh : Generates an xmlTree
* NiNaC as module
* Lustre to GFDL archiving cron/daemon
* Extend to other sites..


To Use
------

Add to PATH:

	setenv PATH ${PATH}:<NiNaC/bin>

or:

	export PATH=${PATH}:<NiNaC/bin>

