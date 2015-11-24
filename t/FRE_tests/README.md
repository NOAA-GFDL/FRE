# Test scripts for FRE jenkins tests

This repository holds the scripts needed for the FRE legacy tests
that will be run via Jenkins. 

The Jenkins jobs must be configured to clone this repository somewhere
in the script.  It may be possible to set this repository as a one the
jenkins job should also monitor, to automatically run tests if/when the
scripts are updated.
 
## Running the tests

You will need to install bats from https://github.com/sstephenson/bats
Then ````cd xml```` and run the tests with ````bats ..```` or run a
specific test file by specifying the filename (e.g.
````bats ../frelist.bats````).
