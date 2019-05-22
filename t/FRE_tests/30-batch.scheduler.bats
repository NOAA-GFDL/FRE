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

@test "batch.scheduler.list report partitions/cluster" {
    if [ "$skip_test" = "true" ]
    then
        skip "Cannot find slurm"
    fi
    run batch.scheduler.list -M c3,gfdl
    print_output_and_status
    [ "$status" -eq 0 ]
    run batch.scheduler.list -P batch,analysis
    print_output_and_status
    [ "$status" -eq 0 ]
    run batch.scheduler.list -M es,gfdl -M rdtn,analysis
    print_output_and_status
    [ "$status" -eq -0]
}
