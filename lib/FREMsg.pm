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

=head1 NAME

FRE-FREMsg

=cut

package FREMsg;

use strict; 

# //////////////////////////////////////////////////////////////////////////////
# ////////////////////////////////////////////////////////// Global constants //
# //////////////////////////////////////////////////////////////////////////////

use constant FATAL => 0;
use constant WARNING => 1;
use constant NOTE => 2;
use constant INFO => 3;

use constant PREFIX_LIST => ('*FATAL*: ', 'WARNING: ', '<NOTE> : ', '<INFO> : ');

# //////////////////////////////////////////////////////////////////////////////
# //////////////////////////////////////////////////////// Exported Functions //
# //////////////////////////////////////////////////////////////////////////////

=head2 FREMSg::out($verbose, $level, @strings)

Output @strings provided that 0 <= $level <= $verbose +1

verbose: Verbosity setting requested by the user on the command line.
level: Verbosity level of the @strings to print.
strings: List of strings to print.

=head3 EXAMPLE

FREMsg::out(-v, FREMsg::NOTE, "You are using rtsVersion=$versionCurrent");

prints *FATAL* : You are using rtsVersion=$versionCurrent

=cut

sub out($$@)
# ------ arguments: $verbosity $level @strings
# ------ output @strings provided that the 0 <= $level <= $verbosity + 1
{
  my ($v, $l) = (shift, shift);
  if (0 <= $l and $l <= $v + 1)
  {
    my @prefixList = FREMsg::PREFIX_LIST;
    my $prefix = ($l <= $#prefixList) ? $prefixList[$l] : $prefixList[$#prefixList];
    my $prefixFiller = ' ' x length($prefix);
    my $firstLine = 1;
    foreach my $s (@_)
    {
      if ($firstLine)
      {
        print STDERR ($prefix, $s, "\n");
	$firstLine = 0;
      }
      else
      {
        print STDERR ($prefixFiller, $s, "\n");
      }
    }
  }
};

# //////////////////////////////////////////////////////////////////////////////
# //////////////////////////////////////////////////////////// Initialization //
# //////////////////////////////////////////////////////////////////////////////

return 1;
