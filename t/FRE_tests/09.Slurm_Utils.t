#!/usr/bin/env perl

=head1 NAME

09.Slurm_Utils.t - Test Slurm::Utils perl package

=head1 DESCRIPTION

Slurm::Utils is a small perl module written at GFDL for gathering
information from the Slurm Batch Scheduler.

=cut

use Test::More;
use strict;

use Slurm::Utils;

# Check if Slurm is used on this site.  If not, skip all tests.
my $myCmd = 'which squeue 2> /dev/null';
my $cmdOutput = qx($myCmd);
if ( $? != 0 ) {
  plan skip_all => 'Slurm is not used on this site';
} else {
  plan tests => 21;
}

# Check return from simplified_state;
is(simplified_state('STOPPED'), 'blocked', "State STOPPED is blocked");
is(simplified_state('COMPLETED'), 'completed', "State COMPLETED is completed");
is(simplified_state('FAILED'), 'failed', "State FAILED is failed");
is(simplified_state('COMPLETING'), 'running', "State COMPLETING is running");
is(simplified_state('PENDING'), 'waiting', "State PENDING is waiting");

# Get the slurm clusters
my @cluster_list = getSlurmClusters();
my $cluster_string = getSlurmClusters();

ok(@cluster_list, "getSlurmCluster returns list");
ok($cluster_string, "getSlurmCluster returns string");
ok(@cluster_list == split(',',$cluster_string), "getSlurmCluster returns identical list and string");

# Valid state tests
my @state_test_list = qw/running waiting/;
my @state_list = valid_states(@state_test_list);
my $state_string = valid_states(@state_test_list);

ok(@state_list, "valid_states returns list");
ok($state_string, "valid_states returns string");
ok(@state_list == split(',',$state_string), 'valid_states returns identical list and string');
@state_list = valid_states(qw/running doesNotExist waiting/);
ok(@state_list == @state_test_list, "valid_states returns only valid states");

# Valid cluster tests
my @cluster_test_list = getSlurmClusters();
@cluster_list = valid_slurm_clusters(@cluster_test_list);
$cluster_string = valid_slurm_clusters(@cluster_test_list);

ok(@cluster_list, "valid_slurm_cluster returns list");
ok($cluster_string, "valid_slurm_cluster returns string");
ok(@cluster_list == split(',',$cluster_string), "valid_slurm_cluster returns identical list and string");

push @cluster_list, 'doesNotExist';
@cluster_list = valid_slurm_clusters(@cluster_list);
ok(@cluster_list == @cluster_test_list, "valid_slurm_cluster returns only valid clusters");

# Valid partitions test
my @partitions_test_list = qw/eslogin rdtn ldtn batch novel analysis ppshort stage/; # All known partitions ATT
my @partitions_list = valid_slurm_partitions(@partitions_test_list);
my $partitions_string = valid_slurm_partitions(@partitions_test_list);

ok(@partitions_list, "valid_slurm_partitions returns list");
ok($partitions_string, "valid_slurm_partitions returns string");
ok(@partitions_list == split(',',$partitions_string), "valid_slurm_partitions returns identical list and string");
ok(valid_slurm_partitions(@partitions_test_list, @cluster_test_list), "valid_slurm_partitions returns partitions available on cluster");

push @partitions_list, 'doesNotExist';
ok(valid_slurm_partitions(@partitions_list) == valid_slurm_partitions(@partitions_test_list), "valid_slurm_partitions returns only valid partitions");

