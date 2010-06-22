#
# $Id: FREMsg.pm,v 18.0 2010/03/02 23:58:53 fms Exp $
# ------------------------------------------------------------------------------
# FMS/FRE Project: Messages Management Module
# ------------------------------------------------------------------------------
# afy    Ver   1.00  Initial version                                November 09
# ------------------------------------------------------------------------------
# Copyright (C) NOAA Geophysical Fluid Dynamics Laboratory, 2000-2009
# Designed and written by V. Balaji, Amy Langenhorst and Aleksey Yakovlev
#

package FREMsg;

use strict; 

# //////////////////////////////////////////////////////////////////////////////
# ////////////////////////////////////////////////////////// Global constants //
# //////////////////////////////////////////////////////////////////////////////

use constant OUT_PREFIX_LIST => ('*FATAL*: ', 'WARNING: ', '<NOTE> : ', '<INFO> : ');

# //////////////////////////////////////////////////////////////////////////////
# //////////////////////////////////////////////////////// Exported Functions //
# //////////////////////////////////////////////////////////////////////////////

sub out($$@)
# ------ arguments: $verbosity $level @strings
# ------ output @strings provided that the 0 <= $level <= $verbosity + 1
{
  my ($v, $l) = (shift, shift);
  if (0 <= $l and $l <= $v + 1)
  {
    my @prefixList = OUT_PREFIX_LIST;
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
