#
# $Id: FRETargets.pm,v 18.0.2.2 2010/04/01 16:49:08 afy Exp $
# ------------------------------------------------------------------------------
# FMS/FRE Project: Targets Management Module
# ------------------------------------------------------------------------------
# afy -------------- Branch 18.0.2 -------------------------------- March 10
# afy    Ver   1.00  Add "all" subroutine                           March 10
# afy    Ver   1.01  Add "allCombinations" subroutine               March 10
# afy    Ver   2.00  Add "starters" subroutine                      March 10
# afy    Ver   2.01  Add "followers" subroutine                     March 10
# ------------------------------------------------------------------------------
# Copyright (C) NOAA Geophysical Fluid Dynamics Laboratory, 2009-2010
# Designed and written by V. Balaji, Amy Langenhorst and Aleksey Yakovlev
#

=head1 NAME

FRE-FRETargets

=cut

package FRETargets;

use strict;

use FREDefaults();

# //////////////////////////////////////////////////////////////////////////////
# ////////////////////////////////////////////////////////// Global Constants //
# //////////////////////////////////////////////////////////////////////////////

use constant TARGET_DEFAULT => FREDefaults::Target();
use constant TARGET_STARTERS => ( TARGET_DEFAULT, 'repro', 'debug' );
use constant TARGET_FOLLOWERS => ( 'hdf5', 'openmp' );

# //////////////////////////////////////////////////////////////////////////////
# //////////////////////////////////////////////////////// Exported Functions //
# //////////////////////////////////////////////////////////////////////////////

=head1 EXPORTED FUNCTIONS

=head2 $FRETargets->standardize($targetList)

Return standard representation of the target list (as a string) and optional error message

targetList: Target list string.

=cut

sub standardize($)

 # ------ arguments: $targetList
 # ------ return standard representation of the target list (as a string) and optional error message
{
    my ( $l, $r ) = @_;
    if ($l) {
        my @targets = split( /,|-/, $l );
        my @targetStarters = ();
        foreach my $targetStarter (TARGET_STARTERS) {
            if ( scalar( grep( $_ eq $targetStarter, @targets ) ) > 0 ) {
                push @targetStarters, $targetStarter;
            }
        }
        if ( scalar(@targetStarters) <= 1 ) {
            my @result = ( ( scalar(@targetStarters) == 1 ) ? $targetStarters[0] : TARGET_DEFAULT );
            foreach my $targetFollower (TARGET_FOLLOWERS) {
                if ( scalar( grep( $_ eq $targetFollower, @targets ) ) > 0 ) {
                    push @result, $targetFollower;
                }
            }
            my @userTargets = ();
            foreach my $target (@targets) {
                if (    scalar( grep( $_ eq $target, TARGET_STARTERS ) ) == 0
                    and scalar( grep( $_ eq $target, TARGET_FOLLOWERS ) ) == 0 ) {
                    push @userTargets, $target;
                }
            }
            if ( scalar(@userTargets) <= 1 ) {
                push @result, $userTargets[0] if scalar(@userTargets) == 1;
                return ( join( '-', @result ), '' );
            }
            else {
                my $userTargets = join( ',', @userTargets );
                return ( '',
                    "Targets '$userTargets' are contradictory - not more than one user target is allowed"
                );
            }
        } ## end if ( scalar(@targetStarters...))
        else {
            my $targetStarters = join( ',', @targetStarters );
            return ( '',
                "Targets '$targetStarters' are contradictory - only one of them is allowed" );
        }
    } ## end if ($l)
    else {
        return ( TARGET_DEFAULT, '' );
    }
} ## end sub standardize($)

=head2 $FRETargets->contains($targetList $target)

Returns number of instances of $target in $targetList.

target: Target string (e.g. prod-openmp).
targetList: Target list string.

=cut

sub contains($$)

    # ------ arguments: $targetList $target
{
    my ( $l, $t ) = @_;
    return scalar( grep( $_ eq $t, split( '-', $l ) ) ) > 0;
}

=head2 $FRETargets->containsProd($targetList)

Returns 1 if $targetList contains 'prod'. 

=cut

sub containsProd($)

    # ------ arguments: $targetList
{
    return FRETargets::contains( shift, 'prod' );
}

=head2 $FRETargets->containsRepro($targetList)

Returns 1 if $targetList contains 'repro'.

=cut

sub containsRepro($)

    # ------ arguments: $targetList
{
    return FRETargets::contains( shift, 'repro' );
}

=head2 $FRETargets->containsDebug($targetList) 

Returns 1 if $targetList contains 'debug'.

=cut

sub containsDebug($)

    # ------ arguments: $targetList
{
    return FRETargets::contains( shift, 'debug' );
}

=head2 $FRETargets->containsHDF5($targetList) 

Returns 1 if $targetList contains 'hdf5'.

=cut

sub containsHDF5($)

    # ------ arguments: $targetList
{
    return FRETargets::contains( shift, 'hdf5' );
}

=head2 $FRETargets->containsOpenMP($targetlist) 

Returns 1 if $targetList contains 'openmp'. 

=cut

sub containsOpenMP($)

    # ------ arguments: $targetList
{
    return FRETargets::contains( shift, 'openmp' );
}

=head2 $FRETargets->starters()

return TARGET_STARTERS;

=cut

sub starters()

    # ------ arguments: none
{
    return TARGET_STARTERS;
}

=head2 $FRETargets->followers()

return TARGET_FOLLOWERS;

=cut

sub followers()

    # ------ arguments: none
{
    return TARGET_FOLLOWERS;
}

=head2 $FRETargets->all()

return (TARGET_STARTERS, TARGET_FOLLOWERS);

=cut


sub all()

    # ------ arguments: none
{
    return ( TARGET_STARTERS, TARGET_FOLLOWERS );
}

=head2 $FRETargets->allCombinations()

Returns list of all possible combinations of target starters and followers.

=cut

sub allCombinations()

    # ------ arguments: none
{
    my @res            = ();
    my $nmbOfFollowers = scalar(TARGET_FOLLOWERS);
    for ( my $i = 0; $i < scalar(TARGET_STARTERS); $i++ ) {
        for ( my $j = 0; $j < ( 1 << $nmbOfFollowers ); $j++ ) {
            my $combination = (TARGET_STARTERS)[$i];
            for ( my $k = 0; $k < $nmbOfFollowers; $k++ ) {
                $combination .= '-' . (TARGET_FOLLOWERS)[$k] if $j & ( 1 << $k );
            }
            push @res, $combination;
        }
    }
    return @res;
}

# //////////////////////////////////////////////////////////////////////////////
# //////////////////////////////////////////////////////////// Initialization //
# //////////////////////////////////////////////////////////////////////////////

return 1;
