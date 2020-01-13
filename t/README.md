# Test scripts for FRE

This directory holds the test scripts for FRE legacy.  These tests are run
automatically with each commit to the main FRE repositories.  These tests
_can_ be run manually.

## Running the tests manually

You will need to install bats from https://github.com/sstephenson/bats, and
ensure it is in your PATH.  Systems in use by GFDL have bats installed in a
location known to the test scripts.

You must use the `fre/test` module to run the tests.  Before loading the
`fre/test` module, ensure the environment variable `FRE_COMMANDS_TEST` is set
and points to the base directory of FRE.  Also ensure (if availalbe) the Slurm
commands are in PATH.  On some sites there is a Slurm module.

Once your environment is setup, enter the `t/FRE_tests` directory, and run the
command: `run_tests`.  The command will produce TAP output of the tests.
