#
# $Id: FREDefaults.pm,v 18.0.2.1 2010/06/18 20:45:45 afy Exp $
# ------------------------------------------------------------------------------
# FMS/FRE Project: System Defaults Module
# ------------------------------------------------------------------------------
# arl    Ver  18.00  Merged revision 1.1.2.4 onto trunk             March 10
# afy -------------- Branch 18.0.2 -------------------------------- June 10
# afy    Ver   1.00  Add status constants                           June 10
# ------------------------------------------------------------------------------
# Copyright (C) NOAA Geophysical Fluid Dynamics Laboratory, 2009-2010
# Designed and written by V. Balaji, Amy Langenhorst and Aleksey Yakovlev
#

package FREDefaults;

use strict; 

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

# //////////////////////////////////////////////////////////////////////////////
# ////////////////////////////////////////////////////////// Global Constants //
# //////////////////////////////////////////////////////////////////////////////

use constant GFDL_PLATFORM_BIN	=> '/home/gfdl/bin/gfdl_platform';
use constant SITE_GFDL		=> 'hpcs';
use constant SITE_DOE		=> 'doe';
use constant SITE		=> (-x FREDefaults::GFDL_PLATFORM_BIN) ? FREDefaults::SITE_GFDL : FREDefaults::SITE_DOE;

use constant XMLFILE_DEFAULT	=> 'rts.xml';
use constant PLATFORM_DEFAULT	=> FREDefaults::SITE . '.' . FREDefaults::SITE;
use constant TARGET_DEFAULT 	=> 'prod';

use constant GLOBAL_NAMES	=> 'site,siteDir,suite,platform,target,name,root';
use constant EXPERIMENT_DIRS	=> 'root,src,exec,scripts,stdout,work,ptmp,archive,postProcess,analysis';

# //////////////////////////////////////////////////////////////////////////////
# //////////////////////////////////////////////////////// Exported Functions //
# //////////////////////////////////////////////////////////////////////////////

sub Site()
# ------ arguments: none
{
  return FREDefaults::SITE;
}

sub SiteGFDL()
# ------ arguments: none
{
  return FREDefaults::SITE_GFDL;
}

sub SiteDOE()
# ------ arguments: none
{
  return FREDefaults::SITE_DOE;
}

sub XMLFile()
# ------ arguments: none
{
  return FREDefaults::XMLFILE_DEFAULT;
}

sub Platform()
# ------ arguments: none
{
  return FREDefaults::PLATFORM_DEFAULT;
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
  return
  (
    split(',', FREDefaults::GLOBAL_NAMES),
    map($_ . 'Dir', FREDefaults::ExperimentDirs())
  );
}

# //////////////////////////////////////////////////////////////////////////////
# //////////////////////////////////////////////////////////// Initialization //
# //////////////////////////////////////////////////////////////////////////////

return 1;
