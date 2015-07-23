#
# $Id: FREPlatforms.pm,v 1.1.2.7 2012/10/19 23:32:17 afy Exp $
# ------------------------------------------------------------------------------
# FMS/FRE Project: Platforms Management Module
# ------------------------------------------------------------------------------
# afy    Ver   1.00  Initial version                                March 11
# afy    Ver   2.00  Add global constant 'LETTER'                   October 11
# afy    Ver   2.01  Simplify 'parse'/'standardize'/'siteDir' subs  October 11
# afy    Ver   2.02  Add 'siteReplace' subroutine                   October 11
# afy    Ver   3.00  Remove global constant 'LETTER'                December 11
# afy    Ver   3.01  Add global constant 'CLUSTER_SEPARATOR'        December 11
# afy    Ver   3.02  Add global constant 'TAIL_SEPARATOR'           December 11
# afy    Ver   3.03  Add 'sitePattern' utility                      December 11
# afy    Ver   3.04  Modify 'platformParse' utility ($sitePattern)  December 11
# afy    Ver   3.05  Add 'siteLead/siteRoot/siteHead/siteDir'       December 11
# afy    Ver   3.06  Modify 'parse' (call $siteDir)                 December 11
# afy    Ver   3.07  Modify 'siteDir' (call $siteDir)               December 11
# afy    Ver   3.08  Modify 'siteReplace' (call $sitePattern)       December 11
# afy    Ver   3.09  Add 'equalsToCurrentSite*' subroutines         December 11
# afy    Ver   4.00  Remove global constant 'CLUSTER_SEPARATOR'     December 11
# afy    Ver   4.01  Add global constant 'SITE_LETTER'              December 11
# afy    Ver   4.02  Modify 'sitePattern' (more restrictive)        December 11
# afy    Ver   4.03  Add 'siteParse' (3 items to return)            December 11
# afy    Ver   4.04  Modify 'platformParse' (4 items to return)     December 11
# afy    Ver   4.05  Remove 'siteLead/siteRoot/siteHead' utilities  December 11
# afy    Ver   4.06  Modify 'siteDir' utility (expects siteRoot)    December 11
# afy    Ver   4.07  Modify all subs (new parsing utilities)        December 11
# afy    Ver   5.00  Add global constant 'PLATFORM_TAIL_LETTER'     December 11
# afy    Ver   5.01  Modify 'platformParse' (use ^)                 December 11
# afy    Ver   5.02  Modify 'siteReplace' (add source site)         December 11
# afy    Ver   6.00  Modify global constant 'PLATFORM_TAIL_LETTER'  January 12
# afy    Ver   6.01  Modify 'platformParse' (limitation on tail)    January 12
# afy    Ver   6.02  Add global variables FREPlatformsSite*         January 12
# afy    Ver   6.03  Rename 'equals*SiteRoot' => 'siteIsLocal'      January 12
# afy    Ver   6.04  Rename 'equals*SiteHead' => 'siteHasCommon*'   January 12
# afy    Ver   6.05  Remove 'standardize' subroutine                January 12
# afy    Ver   6.06  Remove 'site' subroutine                       January 12
# afy    Ver   6.07  Modify 'parse' (return site and tail only)     January 12
# afy    Ver   6.08  Modify 'siteDir' (argument is site now)        January 12
# afy    Ver   6.09  Add 'parseAll' subroutine                      January 12
# afy    Ver   7.00  Modify 'siteReplace' (no 'ncrc' special case)  October 12
# ------------------------------------------------------------------------------
# Copyright (C) NOAA Geophysical Fluid Dynamics Laboratory, 2000-2012
# Designed and written by V. Balaji, Amy Langenhorst and Aleksey Yakovlev
#

# ------------------------------------------------------------------------------
# ------ Platform	= Site "." Tail
# ------ Site		= SiteRoot [ SiteExtension ]
# ------ SiteRoot	= SiteHead [ "-" SiteTail ]
# ------ SiteHead	= Letter { Letter }
# ------ SiteTail	= Letter { Letter } 
# ------ SiteExtension	= Digit { Digit }
# ------ Tail		= Letter { Letter | "-" }
# ------------------------------------------------------------------------------

package FREPlatforms;

use strict; 

use FREDefaults();
use FREUtil();

# //////////////////////////////////////////////////////////////////////////////
# ////////////////////////////////////////////////////////// Global Constants //
# //////////////////////////////////////////////////////////////////////////////

use constant SITE_LETTER => qr/[a-z]/o;
use constant PLATFORM_TAIL_LETTER => qr/\w/o;
use constant SITE_TAIL_SEPARATOR => '-';

# //////////////////////////////////////////////////////////////////////////////
# ///////////////////////////////////////////////////////////////// Utilities //
# //////////////////////////////////////////////////////////////////////////////

my $sitePattern = sub()
# ------ arguments: none
{
  my ($e, $x) = (FREPlatforms::SITE_LETTER, FREPlatforms::SITE_TAIL_SEPARATOR);
  return qr/(($e+)(?:$x$e+)?)\d*/o;
};

my $siteParse = sub($)
# ------ arguments: $site
{
  my ($s, $t) = (shift || FREDefaults::Site(), $sitePattern->());
  return ($s =~ m/^($t)$/o) ? ($1, $2, $3) : ();
};

my $platformParse = sub($)
# ------ arguments: $platform
{
  my ($p, $t, $z) = (shift || FREDefaults::Platform(), $sitePattern->(), FREPlatforms::PLATFORM_TAIL_LETTER); 
  $p = FREDefaults::Site() . '.' . $p if index($p, '.') < 0;
  return ($p =~ m/^($t)\.($z(?:$z|-)*)$/o) ? ($1, $2, $3, $4) : ();
};

my $siteDir = sub($)
# ------ arguments: $siteRoot
{
  return FREUtil::home() . '/site/' . shift;
};

# //////////////////////////////////////////////////////////////////////////////
# ////////////////////////////////////////////////////////// Global Variables //
# //////////////////////////////////////////////////////////////////////////////

my ($FREPlatformsSite, $FREPlatformsSiteRoot, $FREPlatformsSiteHead) = $siteParse->();

# //////////////////////////////////////////////////////////////////////////////
# //////////////////////////////////////////////////////// Exported Functions //
# //////////////////////////////////////////////////////////////////////////////

sub parse($)
# ------ arguments: $platform
{
  my ($site, $siteRoot, $siteHead, $tail) = $platformParse->(shift);
  return (defined($site)) ? ($site, $tail) : ();
}

sub parseAll($)
# ------ arguments: $platform
{
  my ($site, $siteRoot, $siteHead, $tail) = $platformParse->(shift);
  return (defined($site)) ? ($site, $siteRoot, $siteHead, $tail) : ();
}

sub siteDir($)
# ------ arguments: $site
{
  my ($site, $siteRoot, $siteHead) = $siteParse->(shift);
  return (defined($site)) ? $siteDir->($siteRoot) : '';
}

sub siteReplace($$)
# ------ arguments: $platform $newSite
{
  my ($site, $siteRoot, $siteHead, $tail, $newSite, $newSiteRoot, $newSiteHead) = ($platformParse->(shift), $siteParse->(shift));
  if (defined($site) && defined($newSite))
  {
    return "$newSite.$site-$tail";
  }
  else
  {
    return '';
  }
}

sub siteIsLocal($)
# ------ arguments: $site
# ------ return 1 if the $site and the current site have common "site" directory 
{
  my $s = shift;
  if ($s eq $FREPlatformsSite || $s eq $FREPlatformsSiteRoot)
  {
    return 1;
  }
  else
  {
    return 0;
  }
}

sub siteHasLocalStorage($)
# ------ arguments: $site
# ------ return 1 if the $site and the current site have a common file system
{
  my $s = shift;
  if ($s eq $FREPlatformsSite || $s eq $FREPlatformsSiteRoot)
  {
    return 1;
  }
  elsif (my ($site, $siteRoot, $siteHead) = $siteParse->($s))
  {
    return ($siteHead eq $FREPlatformsSiteHead);
  }
  else
  {
    return 0;
  }
}

sub getPlatformSpecificNiNaCLoadCommands()
# ------ arguments: none
# ------ return string of csh commands to load NiNaC
{
  my $ninac_cmds = '';
  $ninac_cmds .= "# ---------------- Load NiNaC if NiNaC_LVL is set and greater than zero\n\n";
  $ninac_cmds .= "if ( \$?NiNaC_LVL ) then\n";
  $ninac_cmds .= "  if ( \$NiNaC_LVL > 0 ) then\n\n";
  $ninac_cmds .= "    # Append directory where NiNaC environment module resides to the module search path\n";
  $ninac_cmds .= "    module use -a $ENV{'NiNaC_PATH'}\n\n";
  $ninac_cmds .= "    # Load NiNaC environment module\n";
  $ninac_cmds .= "    module load NiNaC\n\n";
  $ninac_cmds .= "  endif\n";
  $ninac_cmds .= "endif\n";
  return $ninac_cmds;
}

# //////////////////////////////////////////////////////////////////////////////
# //////////////////////////////////////////////////////////// Initialization //
# //////////////////////////////////////////////////////////////////////////////

return 1;
