#
# $Id: FREDefaults.pm,v 18.0.2.12 2010/11/07 23:05:38 afy Exp $
# ------------------------------------------------------------------------------
# FMS/FRE Project: System Defaults Module
# ------------------------------------------------------------------------------
# arl    Ver  18.00  Merged revision 1.1.2.4 onto trunk             March 10
# afy -------------- Branch 18.0.2 -------------------------------- June 10
# afy    Ver   1.00  Add status constants for fremake               June 10
# afy    Ver   2.00  Add status constants for frerun                June 10
# afy    Ver   3.00  Modify Site (use network domains)              July 10
# afy    Ver   3.01  Modify Platform (call Site explicitly)         July 10
# afy    Ver   3.02  Replace SiteGFDL => SiteIsGFDL                 July 10
# afy    Ver   3.03  Replace SiteDOE => SiteIsCCS                   July 10
# afy    Ver   4.00  Modify Site (fix splitting)                    August 10
# afy    Ver   5.00  Add SiteIsCMRS subroutine                      August 10
# afy    Ver   6.00  Modify Site (add CMRS branch)                  August 10
# afy    Ver   7.00  Replace SiteIsCCS => SiteIsNCCS                August 10
# afy    Ver   8.00  Add Partition subroutine                       September 10
# afy    Ver   8.01  Add PlatformStandardized subroutine            September 10
# afy    Ver   8.02  Modify Platform subroutine (add partition)     September 10
# afy    Ver   8.03  Add siteGet/partitionGet utilities             September 10
# afy    Ver   8.04  Add FREDefaults(Site|Partition) globals        September 10
# afy    Ver   8.05  Replace SiteIsCMRS => SiteIsNCRC               September 10
# afy    Ver   8.06  Replace SiteIsCCS => SiteIsNCCS                September 10
# afy    Ver   9.00  Disable partitions on NCRC                     September 10
# afy    Ver   9.00  Add constant DEFERRED_NAMES                    September 10
# afy    Ver   9.01  Add DeferredPropertyNames subroutine           September 10
# afy    Ver  10.00  Remove Partition subroutine                    September 10
# afy    Ver  10.01  Modify PlatformStandardized subroutine         September 10
# afy    Ver  10.02  Modify Platform subroutine                     September 10
# afy    Ver  11.00  Modify siteGet (add GFDLPP)                    October 10
# afy    Ver  11.01  Add SiteIsGFDLPP subroutine                    October 10
# afy    Ver  11.02  Modify PlatformStandardized (use 'default')    October 10
# afy    Ver  11.03  Modify Platform (use 'default')                October 10
# afy    Ver  12.00  Modify GLOBAL_NAMES (add 'stem')               November 10
# ------------------------------------------------------------------------------
# Copyright (C) NOAA Geophysical Fluid Dynamics Laboratory, 2009-2010
# Designed and written by V. Balaji, Amy Langenhorst and Aleksey Yakovlev
#

package FREDefaults;

use strict;

use Net::Domain();

# //////////////////////////////////////////////////////////////////////////////
# //////////////////////////////////////////////////// Global Return Statuses //
# //////////////////////////////////////////////////////////////////////////////

use constant STATUS_OK					=> 0;

use constant STATUS_COMMAND_GENERIC_PROBLEM		=> 10;
use constant STATUS_COMMAND_NO_EXPERIMENTS		=> 11;

use constant STATUS_FS_GENERIC_PROBLEM			=> 20;
use constant STATUS_FS_PERMISSION_PROBLEM		=> 21;
use constant STATUS_FS_PATH_NOT_EXISTS			=> 22;
use constant STATUS_FS_PATH_EXISTS			=> 23;

use constant STATUS_FRE_GENERIC_PROBLEM			=> 30;
use constant STATUS_FRE_PATH_UNEXPECTED			=> 31;

use constant STATUS_FRE_SOURCE_GENERIC_PROBLEM		=> 40;
use constant STATUS_FRE_SOURCE_NOT_EXISTS		=> 41;
use constant STATUS_FRE_SOURCE_PROBLEM			=> 42;
use constant STATUS_FRE_SOURCE_NO_MATCH			=> 43;

use constant STATUS_FRE_COMPILE_GENERIC_PROBLEM		=> 50;
use constant STATUS_FRE_COMPILE_NOT_EXISTS		=> 51;
use constant STATUS_FRE_COMPILE_PROBLEM			=> 52;
use constant STATUS_FRE_COMPILE_NO_MATCH		=> 53;

use constant STATUS_FRE_RUN_GENERIC_PROBLEM		=> 60;
use constant STATUS_FRE_RUN_NO_TEMPLATE			=> 61;
use constant STATUS_FRE_RUN_EXECUTION_PROBLEM		=> 62;

# //////////////////////////////////////////////////////////////////////////////
# ////////////////////////////////////////////////////////// Global Constants //
# //////////////////////////////////////////////////////////////////////////////

use constant DOMAIN_GFDL	=> 'gfdl.noaa.gov';
use constant DOMAIN_GFDLPP	=> 'princeton.rdhpcs.noaa.gov'; 
use constant DOMAIN_NCRC	=> 'ncrc.gov'; 
use constant DOMAIN_NCCS	=> 'ccs.ornl.gov';

use constant SITE_GFDL		=> 'hpcs';
use constant SITE_GFDLPP	=> 'gfdl';
use constant SITE_NCRC		=> 'ncrc';
use constant SITE_NCCS		=> 'doe';
use constant SITE_UNKNOWN	=> 'unknown';

use constant XMLFILE_DEFAULT	=> 'rts.xml';
use constant PLATFORM_DEFAULT	=> 'default';
use constant TARGET_DEFAULT 	=> 'prod';

use constant GLOBAL_NAMES	=> 'site,siteDir,suite,platform,target,name,root,stem';
use constant EXPERIMENT_DIRS	=> 'root,src,exec,scripts,stdout,work,ptmp,archive,postProcess,analysis';
use constant DEFERRED_NAMES	=> 'name';

# //////////////////////////////////////////////////////////////////////////////
# ///////////////////////////////////////////////////////////////// Utilities //
# //////////////////////////////////////////////////////////////////////////////

my $siteGet = sub()
# ------ arguments: none
{
  my $domain = Net::Domain::hostdomain();
  if ($domain eq FREDefaults::DOMAIN_GFDL)
  {
    return FREDefaults::SITE_GFDL;
  }
  elsif ($domain eq FREDefaults::DOMAIN_GFDLPP)
  {
    return FREDefaults::SITE_GFDLPP;
  }
  elsif ($domain eq FREDefaults::DOMAIN_NCRC)
  {
    return FREDefaults::SITE_NCRC;
  }
  elsif ($domain eq FREDefaults::DOMAIN_NCCS)
  {
    return FREDefaults::SITE_NCCS;
  }
  elsif ($domain)
  {
    return (split(/\./, $domain))[0];
  }
  else
  {
    return FREDefaults::SITE_UNKNOWN; 
  }
};

# //////////////////////////////////////////////////////////////////////////////
# ////////////////////////////////////////////////////////// Global Variables //
# //////////////////////////////////////////////////////////////////////////////

my $FREDefaultsSite = $siteGet->();

# //////////////////////////////////////////////////////////////////////////////
# //////////////////////////////////////////////////////// Exported Functions //
# //////////////////////////////////////////////////////////////////////////////

sub Site()
# ------ arguments: none
{
  return $FREDefaultsSite;
}

sub SiteIsGFDL()
# ------ arguments: none
{
  return ($FREDefaultsSite eq FREDefaults::SITE_GFDL);
}

sub SiteIsGFDLPP()
# ------ arguments: none
{
  return ($FREDefaultsSite eq FREDefaults::SITE_GFDLPP);
}

sub SiteIsNCRC()
# ------ arguments: none
{
  return ($FREDefaultsSite eq FREDefaults::SITE_NCRC);
}

sub SiteIsNCCS()
# ------ arguments: none
{
  return ($FREDefaultsSite eq FREDefaults::SITE_NCCS);
}

sub XMLFile()
# ------ arguments: none
{
  return FREDefaults::XMLFILE_DEFAULT;
}

sub PlatformStandardized($)
# ------ arguments: $platform
{
  my $p = shift;
  if ($p =~ m/^(?:(\w+)\.)?(\w*)$/o)
  {
    my $site = (defined($1)) ? $1 : $FREDefaultsSite;
    my $tail = ($2) ? $2 : FREDefaults::PLATFORM_DEFAULT;
    return $site . '.' . $tail;
  }
  else
  {
    return '';
  }
}

sub Platform()
# ------ arguments: none
{
  return $FREDefaultsSite . '.' . FREDefaults::PLATFORM_DEFAULT;
}

sub Target()
# ------ arguments: none
{
  return FREDefaults::TARGET_DEFAULT;
}

sub ExperimentDirs()
# ------ arguments: none
{
  return split(',', FREDefaults::EXPERIMENT_DIRS);
}

sub ReservedPropertyNames()
# ------ arguments: none
{
  return (split(',', FREDefaults::GLOBAL_NAMES), map($_ . 'Dir', FREDefaults::ExperimentDirs()));
}

sub DeferredPropertyNames()
# ------ arguments: none
{
  return split(',', FREDefaults::DEFERRED_NAMES);
}

# //////////////////////////////////////////////////////////////////////////////
# //////////////////////////////////////////////////////////// Initialization //
# //////////////////////////////////////////////////////////////////////////////

return 1;
