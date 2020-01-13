#!/usr/bin/env bats
# -*- mode: sh; eval: (sh-set-shell "sh"); -*-
load test_helpers

@test "getFreeMem is in PATH" {
  run which getFreeMem
  print_output_and_status
  [ "$status" -eq 0 ]
}

@test "getFreeMem prints help message" {
  run getFreeMem -h
  print_output_and_status
  [ "$status" -eq 0 ]
}

@test "getFreeMem gets system free memory" {
  # since it is difficult to prove getFreeMem returns the correct
  # number, we simple check the error status.
  run getFreeMem
  print_output_and_status
  [ "$status" -eq 0 ]
}

@test "getFreeMem returns memory per cpu" {
  output_good="124"
  export SLURM_JOB_ID=1234
  export SLURM_MEM_PER_CPU=${output_good}
  run getFreeMem
  print_output_status_and_diff_expected
  [ "$status" -eq 0 ]
  [ "$output" = "$output_good" ]
}

@test "getFreeMem returns memory per node (no cpus per node)" {
  output_good="256"
  export SLURM_JOB_ID=1234
  export SLURM_MEM_PER_NODE=${output_good}
  run getFreeMem
  print_output_status_and_diff_expected
  [ "$status" -eq 0 ]
  [ "$output" = "$output_good" ]
}

@test "getFreeMem returns memory per node (with cpus per node)" {
  output_good="512"
  export SLURM_JOB_ID=1234
  export SLURM_JOB_CPUS_PER_NODE=2
  export SLURM_MEM_PER_NODE=$(expr $output_good \* $SLURM_JOB_CPUS_PER_NODE)
  run getFreeMem
  print_output_status_and_diff_expected
  [ "$status" -eq 0 ]
  [ "$output" = "$output_good" ]
}
