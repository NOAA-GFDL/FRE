#
# $Id: FREXML.pm,v 18.0.2.3 2010/06/18 16:10:29 afy Exp $
# ------------------------------------------------------------------------------
# FMS/FRE Project: General XML Processing Module
# ------------------------------------------------------------------------------
# arl    Ver  18.00  Merged revision 1.1.2.2 onto trunk             March 10
# afy -------------- Branch 18.0.2 -------------------------------- March 10
# afy    Ver   1.00  Use Scalar::Util::reftype subroutine           April 10
# afy    Ver   1.01  Modify FREXMLCreate (allow refs to strings)    April 10
# afy    Ver   2.00  Modify FREXMLCreate (allow refs to arrays)     April 10
# afy    Ver   2.01  Modify FREXMLCreate (canonicalize strings)     April 10
# afy    Ver   3.00  Redesigned using the XML::Dumper module        June 10
# ------------------------------------------------------------------------------
# Copyright (C) NOAA Geophysical Fluid Dynamics Laboratory, 2000-2010
# Designed and written by V. Balaji, Amy Langenhorst and Aleksey Yakovlev
#

package FREXML;

use strict;

use Scalar::Util();
use XML::Dumper();

# //////////////////////////////////////////////////////////////////////////////
# ///////////////////////////////////////////////////////////////// Utilities //
# //////////////////////////////////////////////////////////////////////////////

my $standardize;
$standardize = sub($$)

    # ------ arguments: $ref $refType
{
    my ( $r, $t ) = @_;
    if ( !$t or $t eq 'SCALAR' ) {
        ${$r} =~ s/^\s*#.*$//gm;
        ${$r} =~ s/(?:^\s+|\s+$)//gs;
        ${$r} =~ s/\s+/ /gs;
    }
    elsif ( $t eq 'ARRAY' ) {
        for ( my $i = 0; $i < scalar @{$r}; $i++ ) {
            my $v = $r->[$i];
            if ($v) {
                my $t = Scalar::Util::reftype($v);
                $standardize->( ($t) ? $v : \$r->[$i], $t );
            }
        }
    }
    elsif ( $t eq 'HASH' ) {
        delete $r->{lineNumber} if exists $r->{lineNumber};
        foreach my $k ( keys %{$r} ) {
            my $v = $r->{$k};
            if ($v) {
                my $t = Scalar::Util::reftype($v);
                $standardize->( ($t) ? $v : \$r->{$k}, $t );
            }
        }
    }
    else {

        # ------ for future extensions ???
    }
};

# //////////////////////////////////////////////////////////////////////////////
# //////////////////////////////////////////////////////// Exported Functions //
# //////////////////////////////////////////////////////////////////////////////

sub save($$)

    # ------ arguments: $fileName $refToHash
    # ------ called as regular function
    # ------ save hash as an XML document file
{
    my ( $n, $r ) = @_;
    my %h = %{$r};
    $standardize->( \%h, 'HASH' );
    XML::Dumper::pl2xml( \%h, $n );
}

sub verify($$)

    # ------ arguments: $filename $refToHash
    # ------ called as regular function
    # ------ pass an XML document file and a hash of values to verify
    # ------ return true if ALL the subnodes have the prescribed value
{
    my ( $n, $r ) = @_;
    if ( open my $handle, '<', $n ) {
        my $x1 = join '', <$handle>;
        close $handle;
        my %h = %{$r};
        $standardize->( \%h, 'HASH' );
        my $x2 = XML::Dumper::pl2xml( \%h );
        return XML::Dumper::xml_compare( $x1, $x2 );
    }
    else {
        return 1;
    }
}

# //////////////////////////////////////////////////////////////////////////////
# //////////////////////////////////////////////////////////// Initialization //
# //////////////////////////////////////////////////////////////////////////////

return 1;
