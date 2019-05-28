#!/usr/bin/env bats
# -*- mode: sh; eval: (sh-set-shell "sh"); -*-
load test_helpers

setup() {
    # Determine if we should skip tests.
    if [ ! "$(command -v squeue)" ]
    then
        # No squeue, assume no slurm, and skip tests
        skip_test=true
    else
        skip_test=false
    fi
}

# Run several tests for batch.scheduler.fre.usage.
@test "batch.scheduler.list is in PATH" {
    run which batch.scheduler.list
    print_output_and_status
    [ "$status" -eq 0 ]
}

@test "batch.scheduler.list prints help message" {
    run batch.scheduler.list -h
    print_output_and_status
    [ "$status" -eq 0 ]
}

@test "batch.scheduler.list returns list of Slurm jobs" {
    if [ "$skip_test" = "true" ]
    then
        skip "Cannot find slurm"
    fi
    run batch.scheduler.list
    print_output_and_status
    [ "$status" -eq 0 ]
}

@test "batch.scheduler.list report cluster" {
    if [ "$skip_test" = "true" ]
    then
        skip "Cannot find slurm"
    fi
    run batch.scheduler.list -M c3,gfdl
    print_output_and_status
    [ "$status" -eq 0 ]
}

@test "batch.scheduler.list report partition" {
    if [ "$skip_test" = "true" ]
    then
        skip "Cannot find slurm"
    fi
    run batch.scheduler.list -p batch,analysis
    print_output_and_status
    [ "$status" -eq 0 ]
}

@test "batch.scheduler.list report cluster/partition" {
    if [ "$skip_test" = "true" ]
    then
        skip "Cannot find slurm"
    fi
    run batch.scheduler.list -M es,gfdl -p rdtn,analysis
    print_output_and_status
    [ "$status" -eq -0 ]
}

@test "batch.scheduler.list errors if unknown clusters given" {
   if [ "$skip_test" = "true" ]
   then
      skip "Cannot find slurm"
   fi
   run batch.scheduler.list -M doesNotExist
   print_output_and_status
   [ $status -ne 0 ]
}

