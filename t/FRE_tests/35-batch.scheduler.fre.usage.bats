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
@test "batch.scheduler.fre.usage is in PATH" {
    run which batch.scheduler.fre.usage
    print_output_and_status
    [ "$status" -eq 0 ]
}

@test "batch.scheduler.fre.usage prints help message" {
    run batch.scheduler.fre.usage -h
    print_output_and_status
    [ "$status" -eq 0 ]
}

@test "batch.scheduler.fre.usage returns list of FRE versions" {
    if [ "$skip_test" = "true" ]
    then
        skip "Cannot find slurm"
    fi
    run batch.scheduler.fre.usage
    print_output_and_status
    [ "$status" -eq 0 ]
}

@test "batch.scheduler.fre.usage report FRE versions for cluster" {
    if [ "$skip_test" = "true" ]
    then
        skip "Cannot find slurm"
    fi
    run batch.scheduler.fre.usage -M c3,gfdl
    print_output_and_status
    [ "$status" -eq 0 ]
}

@test "batch.scheduler.fre.usage report FRE versions for partitions" {
    if [ "$skip_test" = "true" ]
    then
        skip "Cannot find slurm"
    fi
    run batch.scheduler.fre.usage -p batch,analysis
    print_output_and_status
    [ "$status" -eq 0 ]
}

@test "batch.scheduler.fre.usage report FRE versions for partitions/cluster" {
    if [ "$skip_test" = "true" ]
    then
        skip "Cannot find slurm"
    fi
    run batch.scheduler.fre.usage -M es,gfdl -p rdtn,analysis
    print_output_and_status
    [ "$status" -eq -0 ]
}
