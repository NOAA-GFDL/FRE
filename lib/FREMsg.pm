#
# $Id: FREMsg.pm,v 18.0.4.2 2011/12/23 23:10:02 afy Exp $
# ------------------------------------------------------------------------------
# FMS/FRE Project: System Messaging Module
# ------------------------------------------------------------------------------
# afy    Ver   1.00  Initial version                                November 09
# afy -------------- Branch 18.0.4 -------------------------------- December 10
# afy    Ver   1.00  Add symbolic names for messages levels         December 10
# afy    Ver   2.00  Add global constant 'PREFIX_LIST'              December 11
# ------------------------------------------------------------------------------
# Copyright (C) NOAA Geophysical Fluid Dynamics Laboratory, 2000-2011
# Designed and written by V. Balaji, Amy Langenhorst and Aleksey Yakovlev
#

package FREMsg;

use strict;

# //////////////////////////////////////////////////////////////////////////////
# ////////////////////////////////////////////////////////// Global constants //
# //////////////////////////////////////////////////////////////////////////////

use constant FATAL   => 0;
use constant WARNING => 1;
use constant NOTE    => 2;
use constant INFO    => 3;

use constant PREFIX_LIST => ( '*FATAL*: ', 'WARNING: ', '<NOTE> : ', '<INFO> : ' );

# //////////////////////////////////////////////////////////////////////////////
# //////////////////////////////////////////////////////// Exported Functions //
# //////////////////////////////////////////////////////////////////////////////

sub out($$@)

    # ------ arguments: $verbosity $level @strings
    # ------ output @strings provided that the 0 <= $level <= $verbosity + 1
{
    my ( $v, $l ) = ( shift, shift );
    if ( 0 <= $l and $l <= $v + 1 ) {
        my @prefixList   = FREMsg::PREFIX_LIST;
        my $prefix       = ( $l <= $#prefixList ) ? $prefixList[$l] : $prefixList[$#prefixList];
        my $prefixFiller = ' ' x length($prefix);
        my $firstLine    = 1;
        foreach my $s (@_) {
            if ($firstLine) {
                print STDERR ( $prefix, $s, "\n" );
                $firstLine = 0;
            }
            else {
                print STDERR ( $prefixFiller, $s, "\n" );
            }
        }
    }
}

# //////////////////////////////////////////////////////////////////////////////
# //////////////////////////////////////////////////////////// Initialization //
# //////////////////////////////////////////////////////////////////////////////

return 1;
