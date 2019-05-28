=head1 NAMAE

Slurm::Utils - A collection of routines that interact with the Slurm batch schedule

=head1 SYNOPSIS

    use Slurm::Utils;

    @clusters = getSlurmClusters();

=head1 DESCRIPTION

These routines allow the user to interact with the Slurm batch scheduler.

=cut

package Slurm::Utils;

use strict;
use 5.006;
use warnings;
our(@ISA, @EXPORT, $VERSION, $Fileparse_fstype, $Fileparse_igncase);
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(getSlurmClusters simplified_state valid_states valid_slurm_clusters valid_slurm_partitions);
$VERSION = "1.00";

our @JOB_STATES = ( 'blocked', 'completed', 'failed', 'running', 'waiting' );

=over 4

=item C<simplified_state>
X<simplified_state>

Takes a state string (as given by Slurm) and translates the state to a
simplified state.  This is done as Slurm has many states.

=cut

sub simplified_state($) {
  my $s = shift;

  my %state_mapping = (
		       RESV_DEL_HOLD => 0,
		       STOPPED       => 0,
		       SUSPENDED     => 0,
		       COMPLETED     => 1,
		       BOOT_FAIL     => 2,
		       CANCELLED     => 2,
		       DEADLINE      => 2,
		       FAILED        => 2,
		       NODE_FAIL     => 2,
		       OUT_OF_MEMORY => 2,
		       PREEMPTED     => 2,
		       REQUEUE_FED   => 2, # not sure- job is being run again with a new id but this one is a goner
		       REQUEUE_HOLD  => 2, # same
		       REQUEUED      => 2, # same
		       REVOKED       => 2, # similar
		       SPECIAL_EXIT  => 2,
		       TIMEOUT       => 2,
		       COMPLETING    => 3,
		       RESIZING      => 3, # going to be resized, but presumably still running ok
		       RUNNING       => 3,
		       SIGNALING     => 3, # signalling doesn't sound good, but it's running now (I think)
		       STAGE_OUT     => 3,
		       CONFIGURING   => 4,
		       PENDING       => 4,
		      );

  $Slurm::Utils::JOB_STATES[$state_mapping{$s}];
}

=over 4

=item C<interset>
X<intersect>

  my $string = string_list_intersect($inString, @inList);

The C<string_list_intersect> routine takes a comma separated string of items,
and compares it to the elements in a list.  The return is a list or comma 
separated string of items that match in the two.

=cut

sub intersect(\@\@) {
  my @intersect = map {my $b = $_; grep { $_ eq $b } @{$_[0]}} @{$_[1]};
  wantarray ? (@intersect) : (join(',',@intersect));
}

=over 4

=item C<getSlurmClusters>
X<getSlurmClusters>

  my @clusters = getSlurmClusters();
  my $clusters = getSlurmClusters();

The C<getSlurmClusters> routine returns the list of known clusters known 
to the Slurm deamon.

=cut

sub getSlurmClusters {
  my @clusters;
  my $sacctmgr_cmd = 'sacctmgr list clusters -n -P';
  my @sacctmgr_out = qx($sacctmgr_cmd);
  if ($? == 0) {
    @clusters = map { (split '\|', $_)[0] } @sacctmgr_out;
  }
  wantarray ? (@clusters) : (join(',',@clusters));
}

=over 4

=item C<valid_states>
X<valid_states>


Returns a comma separated string, or list of simplified states that
match the list of simplified states used in this module.

=cut

sub valid_states(@) {
  my @inStates = @_;
  # Get the list of valid states.
  my @valid_states = intersect(@inStates, @Slurm::Utils::JOB_STATES);
  wantarray ? (@valid_states) : (join(',',@valid_states));
}

=over 4

=item C<valid_slurm_clusters>
X<valid_slurm_clusters>

Takes a list  of Slurm clusters, and returns a comma separated string
or list of Slurm clusters that match the clusters the Slurm Daemon knows
about.

=cut

sub valid_slurm_clusters(@) {
  my @inClusters = @_;
  # Get the list of valid clusters on this site.
  my @known_clusters = getSlurmClusters();
  my @slurm_clusters = intersect(@inClusters, @known_clusters);
  wantarray ? (@slurm_clusters) : (join(',',@slurm_clusters));
}

=over 4

=item C<valid_slurm_partitions>
X<valid_slurm_parititions>

=cut

sub valid_slurm_partitions(\@;\@) {
  #
  # Take a comma separated list of partitions, and optional cluster, and return the
  # valid partitions.
  my @inPartitions = @{$_[0]};
  my @inClusters;
  @inClusters = @{$_[1]} if $_[1];
    my @partitions;
    if (@inClusters) {
        # Need to loop through clusters to get partitions
        foreach my $cluster (@inClusters) {
            my @scontrol_out = qx/scontrol show partitions -M $cluster/;
            if ($? == 0) {
                push @partitions, map { $_ =~ /PartitionName=(\S+)/ } @scontrol_out;
            }
        }
    } else {
        my @scontrol_out = qx/scontrol show partitions/;
        if ($? == 0) {
            @partitions = map { $_ =~ /PartitionName=(\S+)/ } @scontrol_out;
        }
    }
    # Return the intersection of clusters from sacctmgr and passed in by the
    # user
    my @slurm_partitions = intersect(@inPartitions, @partitions);
    wantarray ? (@slurm_partitions) : (join(',',@slurm_partitions));
}

1;

