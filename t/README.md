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


## run tests for branch `519.epmt-bug`
execute the following from this directory (`fre-commands/t`). warning: `bash` assumed.
```
cd ..
export FRE_COMMANDS_TEST=$PWD
module load fre/test
module load bats
cd t/FRE_tests
```

now edit `t/FRE_tests/run_tests` to only run `frepp` tests. replace the 
`do_tests` function with the following script:
```
do_tests () {
  pushd xml

  local command="bats -t ../frepp.bats"
  echo $command
  $command | tee frepp.tap 2>&1
  frepp_exit=$(evalTAP frepp.tap)
  rm -f frepp.tap

  echo ""

  popd

  local myExit=$(expr $frepp_exit)

  return $myExit
}
```

now we can run only `frepp` tests with `run_tests`