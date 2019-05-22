# Manual tests

At this time, not all tests are automated.  Some of this is due to planned
updates that will be done on the systems that make automated testing more
difficult (and will require the tests to be changed in the future).  One example
of this is the Moab to Slurm transition -- systems will do the transition in
parts.  Below are some of the tests that should be run manually (with
instructions on how to perform the tests).

## batch.scheduler.fre.usage

The `batch.scheduler.fre.usage` command reports which versions of FRE (and which
users) are currently in the queue on the system.  This application is not vital
to the user usage of FRE, and is only a reporting tool.  The following tests
should be performed.  Not all tests can be performed on all systems.

1. Verify the program will print the help message.
   ```
   export FRE_COMMANDS_TEST=<FRE_DEV_LOCATION>
   module load fre/test
   batch.scheduler.fre.usage -h
   echo $?
   # If help message printed, and exit status 0, tests passed.
   ```

2. Verify default command runs.
   ```
   export FRE_COMMANDS_TEST=<FRE_DEV_LOCATION>
   module load fre/test
   batch.scheduler.fre.usage
   echo $?
   # A list of FRE versions and users (with a number in parenthesis) should be
   # printed to stdout.  Exit status should be 0.
   ```

3. Verify ability to change partition using `-P/--partition` option.  Test
   only valid on gaea.
   ```
   export FRE_COMMANDS_TEST=<FRE_DEV_LOCATION>
   module load fre/test
   batch.scheduler.fre.usage -p c3
   echo $?
   batch.scheduler.fre.usage -p c4
   echo $?
   batch.scheduler.fre.usage -p c3:c4
   echo $?
   # A list of FRE versions and users (with a number in parenthesis) should be
   # printed to stdout.  Each call should have a different list, with the last
   # call (c3:c4) will contain all the information in the first two.  (Some
   # information may be different as jobs enter/leave the system.)
   ```

4. Verify ability to list waiting jobs (default prints running only), using the
   `-s` option.  Valid only under Moab.
   ```
   export FRE_COMMANDS_TEST=<FRE_DEV_LOCATION>
   module load fre/test
   batch.scheduler.fre.usage -s waiting
   echo $?
   batch.scheduler.fre.usage -s running
   echo $?
   batch.scheduler.fre.usage -s "waiting,running"
   echo $?
   # A list of FRE versions and user (with a number in parenthesis) should be
   # printed to stdout.  Each call should produce a different list, with the
   # last call containing all the information in the first two.  (Some
   # may be different as jobs enter/leave the system.)
   ```
