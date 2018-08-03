#
# $Id: FREDefaults.pm,v 18.0.2.21 2012/02/21 19:10:07 afy Exp $
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
# afy    Ver  13.00  Modify siteGet (add NASA)                      December 10
# afy    Ver  13.01  Add SiteIsNASA subroutine                      December 10
# afy    Ver  14.00  Replace site 'hpcs' => 'gfdl-ws'               January 11
# afy    Ver  14.01  Replace SiteIsGFDL => SiteIsGFDLWS             January 11
# afy    Ver  14.02  Replace SiteIsGFDLPP => SiteIsGFDL             January 11
# afy    Ver  14.03  Modify PlatformStandardized (dash in names)    January 11
# afy    Ver  15.00  Add DOMAINS_TO_SITES_MAPPING constant          March 11
# afy    Ver  15.01  Modify siteGet utility (use ^)                 March 11
# afy    Ver  15.02  Add Sites subroutine                           March 11
# afy    Ver  15.03  Remove all the SiteIs* subroutines             March 11
# afy    Ver  15.04  Remove PlatformStandardized subroutine         March 11
# afy    Ver  16.00  Modify EXPERIMENT_DIRS (add state)             May 11
# afy    Ver  17.00  Modify EXPERIMENT_DIRS (add stmp)              July 11
# afy    Ver  17.01  Simplify the 'siteGet' utility                 July 11
# afy    Ver  18.00  Remove the DOMAINS_TO_SITES_MAPPING constant   September 11
# afy    Ver  18.01  Add SITE_CURRENT/SITES_ALL constants           September 11
# afy    Ver  18.02  Remove the 'siteGet' utility                   September 11
# afy    Ver  18.03  Simplify Site/Sites/Platform subroutines       September 11
# afy    Ver  18.04  Use initialization code to check envvars       September 11
# afy    Ver  18.05  Don't use the Net::Domain module               September 11
# afy    Ver  19.00  Add status 'STATUS_XML_NOT_VALID'              October 11
# afy    Ver  20.00  Add status 'STATUS_DATA_NOT_EXISTS'            January 12
# afy    Ver  20.01  Add status 'STATUS_DATA_NO_MATCH'              January 12
# afy    Ver  21.00  Modify EXPERIMENT_DIRS (add stdoutTmp)         February 12
# ------------------------------------------------------------------------------
# Copyright (C) NOAA Geophysical Fluid Dynamics Laboratory, 2009-2012
# Designed and written by V. Balaji, Amy Langenhorst and Aleksey Yakovlev
#

package FREDefaults;

use strict;

use FREMsg();

# //////////////////////////////////////////////////////////////////////////////
# //////////////////////////////////////////////////// Global Return Statuses //
# //////////////////////////////////////////////////////////////////////////////

use constant STATUS_OK            => 0;
use constant STATUS_XML_NOT_VALID => 1;

use constant STATUS_COMMAND_GENERIC_PROBLEM  => 10;
use constant STATUS_COMMAND_NO_EXPERIMENTS   => 11;
use constant STATUS_COMMAND_PLATFORM_PROBLEM => 12;

use constant STATUS_FS_GENERIC_PROBLEM    => 20;
use constant STATUS_FS_PERMISSION_PROBLEM => 21;
use constant STATUS_FS_PATH_NOT_EXISTS    => 22;
use constant STATUS_FS_PATH_EXISTS        => 23;

use constant STATUS_FRE_GENERIC_PROBLEM => 30;
use constant STATUS_FRE_PATH_UNEXPECTED => 31;

use constant STATUS_FRE_SOURCE_GENERIC_PROBLEM => 40;
use constant STATUS_FRE_SOURCE_NOT_EXISTS      => 41;
use constant STATUS_FRE_SOURCE_PROBLEM         => 42;
use constant STATUS_FRE_SOURCE_NO_MATCH        => 43;

use constant STATUS_FRE_COMPILE_GENERIC_PROBLEM => 50;
use constant STATUS_FRE_COMPILE_NOT_EXISTS      => 51;
use constant STATUS_FRE_COMPILE_PROBLEM         => 52;
use constant STATUS_FRE_COMPILE_NO_MATCH        => 53;

use constant STATUS_FRE_RUN_GENERIC_PROBLEM   => 60;
use constant STATUS_FRE_RUN_NO_TEMPLATE       => 61;
use constant STATUS_FRE_RUN_EXECUTION_PROBLEM => 62;

use constant STATUS_DATA_NOT_EXISTS => 70;
use constant STATUS_DATA_NO_MATCH   => 71;

# //////////////////////////////////////////////////////////////////////////////
# ////////////////////////////////////////////////////////// Global Constants //
# //////////////////////////////////////////////////////////////////////////////

use constant SITE_CURRENT => $ENV{FRE_SYSTEM_SITE};
use constant SITES_ALL => split( /:/, $ENV{FRE_SYSTEM_SITES} );

use constant XMLFILE_DEFAULT => 'rts.xml';
use constant TARGET_DEFAULT  => 'prod';

use constant GLOBAL_NAMES => 'site,siteDir,suite,platform,target,name,root,stem';
use constant EXPERIMENT_DIRS =>
    'root,src,exec,scripts,stdout,stdoutTmp,state,work,ptmp,stmp,archive,postProcess,analysis,include';
use constant DEFERRED_NAMES => 'name';

# //////////////////////////////////////////////////////////////////////////////
# //////////////////////////////////////////////////////// Exported Functions //
# //////////////////////////////////////////////////////////////////////////////

sub Site()

    # ------ arguments: none
{
    return FREDefaults::SITE_CURRENT;
}

sub Sites()

    # ------ arguments: none
{
    return FREDefaults::SITES_ALL;
}

sub XMLFile()

    # ------ arguments: none
{
    return FREDefaults::XMLFILE_DEFAULT;
}

sub Target()

    # ------ arguments: none
{
    return FREDefaults::TARGET_DEFAULT;
}

sub ExperimentDirs()

    # ------ arguments: none
{
    return split( ',', FREDefaults::EXPERIMENT_DIRS );
}

sub ReservedPropertyNames()

    # ------ arguments: none
{
    return (
        split( ',', FREDefaults::GLOBAL_NAMES ),
        map( $_ . 'Dir', FREDefaults::ExperimentDirs() )
    );
}

sub DeferredPropertyNames()

    # ------ arguments: none
{
    return split( ',', FREDefaults::DEFERRED_NAMES );
}

# //////////////////////////////////////////////////////////////////////////////
# //////////////////////////////////////////////////////////// Initialization //
# //////////////////////////////////////////////////////////////////////////////

{
    my ( $site, @sites ) = ( FREDefaults::Site(), FREDefaults::Sites() );
    if ( $site and scalar( grep( $_ eq $site, @sites ) ) > 0 ) {
        return 1;
    }
    else {
        FREMsg::out( FREMsg::FATAL, 0, "FRE environment variables aren't set correctly" );
        exit STATUS_FRE_GENERIC_PROBLEM;
    }
}
