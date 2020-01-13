#!/usr/bin/env perl

=head1 NAME

10.batch_scheduler_time.t - Test GFDL batch scheduler query utility

=head1 DESCRIPTION

batch_scheduler_time is a GFDL utility that returns the total and remaining
time in seconds for a given batch job ID.

These tests are only a quick reality test on the Seconds() subroutine
that parses the time-output from the batch system, and doesn't cover
the retrieval and printing of the batch system time information.

The Slurm date format is:
  days-hours:min:sec
and larger units can be omitted except for seconds.

Input outside the format should just return the input.

=cut

use Test::More;

use lib "$ENV{FRE_COMMANDS_HOME}/sbin";
require 'batch.scheduler.time';

%test_data = (
    '104-20:50:30'  => 104*24*60*60 + 20*60*60 + 50*60 + 30,
    '9-08:00:00'    => 9*24*60*60 + 8*60*60,
    '2-00:00:03'    => 2*24*60*60 + 3,
    '9:30:00'       => 9*60*60 + 30*60,
    '55:55'         => 55*60 + 55,
    '0:55'          => 55,
    '34'            => '34',
    'cat'           => 'cat',
);

while (my ($input, $output) = each %test_data) {
    is(batch_scheduler_time::Seconds($input), $output, "Converting '$input' to seconds");
}

done_testing();
