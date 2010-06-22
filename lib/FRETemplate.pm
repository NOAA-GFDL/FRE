#
# $Id: FRETemplate.pm,v 18.0 2010/03/02 23:58:57 fms Exp $
# ------------------------------------------------------------------------------
# FMS/FRE Project: Template Management Module
# ------------------------------------------------------------------------------
# afy    Ver   1.00  Initial version                                September 09
# afy    Ver   2.00  Modify setSchedulerOptions (coresPerNode)      October 09
# afy    Ver   3.00  Modify setSchedulerOptions (option -o)         October 09
# afy    Ver   4.00  Modify setSchedulerOptions (keep placeholder)  November 09
# afy    Ver   4.01  Add setSchedulerDualRuns subroutine            November 09
# afy    Ver   5.00  Add setSchedulerMakeVerbose subroutine         January 10
# afy    Ver   6.01  Use new FREDefaults module                     January 10
# afy    Ver   6.02  Use new external property "FRE.site"           January 10
# afy    Ver   7.00  Use new FRE (externalProperty => property)     January 10
# ------------------------------------------------------------------------------
# Copyright (C) NOAA Geophysical Fluid Dynamics Laboratory, 2009-2010
# Designed and written by V. Balaji, Amy Langenhorst and Aleksey Yakovlev
#

package FRETemplate;

use strict; 

use POSIX();

use FRE();
use FREDefaults();

# //////////////////////////////////////////////////////////////////////////////
# ////////////////////////////////////////////////////////// Global Constants //
# //////////////////////////////////////////////////////////////////////////////

use constant SITE_GFDL => FREDefaults::SiteGFDL();
use constant SITE_DOE => FREDefaults::SiteDOE();

use constant PRAGMA_PREFIX => '#FRE';
use constant PRAGMA_SCHEDULER_OPTIONS => 'scheduler-options';
use constant PRAGMA_SCHEDULER_MAKE_VERBOSE => 'scheduler-make-verbose';
use constant PRAGMA_VERSION_INFO => 'version-info';

# //////////////////////////////////////////////////////////////////////////////
# //////////////////////////////////////////////////////// Exported Functions //
# //////////////////////////////////////////////////////////////////////////////

sub setSchedulerOptions($$$$$$%)
# ------ arguments: $script $expt $npes $simRunTime $segRunTime $stdoutDir %options
{

  my ($s, $z, $n, $t, $g, $d, %o) = @_;

  my $prefix = FRETemplate::PRAGMA_PREFIX;
  my $schedulerOptions = FRETemplate::PRAGMA_SCHEDULER_OPTIONS;
  my $placeholder = qr/^[ \t]*$prefix[ \t]+$schedulerOptions[ \t]*$/mo;

  my $fre = $z->fre();
  my $project = $fre->project();
  my $prefix = $fre->property('FRE.scheduler.prefix');
  my $queue = $fre->property('FRE.scheduler.queue');
  my $coresPerNode = $fre->property('FRE.machine.coresPerNode');
  my $site = $fre->property('FRE.site');
  
  my $n = POSIX::ceil($n / $coresPerNode) * $coresPerNode;

  if ($site eq FRETemplate::SITE_GFDL)
  {

    $s =~ s/($placeholder)/$1\n$prefix -r y/;
    $s =~ s/($placeholder)/$1\n$prefix -l cpuset/;
    $s =~ s/($placeholder)/$1\n$prefix -soft -l fre_info=runTimePerSegment\@$g -hard/ if $g;
    $s =~ s/($placeholder)/$1\n$prefix -o $d\//;
    $s =~ s/($placeholder)/$1\n$prefix -pe ic.alloc $n/;
    $s =~ s/($placeholder)/$1\n$prefix -l h_cpu=$t/;

    if ($project)
    {
      $s =~ s/($placeholder)/$1\n$prefix -P $project/;
      $s =~ s/($placeholder)/$1\n$prefix -v FRE_PROJECT=$project/;
    }

  }
  elsif ($site eq FRETemplate::SITE_DOE)
  {

    $s =~ s/($placeholder)/$1\n$prefix -q $queue/;
    $s =~ s/($placeholder)/$1\n$prefix -m abe/;
    $s =~ s/($placeholder)/$1\n$prefix -j oe/;
    $s =~ s/($placeholder)/$1\n$prefix -o $d\/\${PBS_JOBNAME}.\${PBS_JOBID}/;
    $s =~ s/($placeholder)/$1\n$prefix -l size=$n/;
    $s =~ s/($placeholder)/$1\n$prefix -l walltime=$t/;

    if ($project)
    {
      $s =~ s/($placeholder)/$1\n$prefix -A $project/;
      $s =~ s/($placeholder)/$1\n$prefix -v FRE_PROJECT=$project/;
    }

  }

  return $s;

}

sub setSchedulerDualRuns($$)
# ------ arguments: $script $exp
{

  my ($s, $z) = @_;

  my $prefix = FRETemplate::PRAGMA_PREFIX;
  my $schedulerOptions = FRETemplate::PRAGMA_SCHEDULER_OPTIONS;
  my $placeholder = qr/^[ \t]*$prefix[ \t]+$schedulerOptions[ \t]*$/mo;

  my $fre = $z->fre();
  my $prefix = $fre->property('FRE.scheduler.prefix');
  my $site = $fre->property('FRE.site');
  
  if ($site eq FRETemplate::SITE_GFDL)
  {
    $s =~ s/($placeholder)/$1\n$prefix -A repro/;
    $s =~ s/($placeholder)/$1\n$prefix -v nodual/;
  }
  elsif ($site eq FRETemplate::SITE_DOE)
  {
    # ------ ???
  }

  return $s;

}

sub setSchedulerMakeVerbose($$)
# ------ arguments: $script $exp
{

  my ($s, $z) = @_;

  my $prefix = FRETemplate::PRAGMA_PREFIX;
  my $schedulerOptions = FRETemplate::PRAGMA_SCHEDULER_MAKE_VERBOSE;
  my $placeholder = qr/^[ \t]*$prefix[ \t]+$schedulerOptions[ \t]*$/mo;

  my $fre = $z->fre();
  my $site = $fre->property('FRE.site');
  my $makeVerbose = '';
  
  if ($site eq FRETemplate::SITE_GFDL)
  {
    $makeVerbose .= 'if ( $?ENVIRONMENT ) then' . "\n";
    $makeVerbose .= '  if ( $ENVIRONMENT == "BATCH" ) then' . "\n";
    $makeVerbose .= '    set aliasMake = `alias make`' . "\n";
    $makeVerbose .= '    if ( $aliasMake != "" ) then' . "\n";
    $makeVerbose .= '      alias make $aliasMake VERBOSE=on' . "\n";
    $makeVerbose .= '    else' . "\n";
    $makeVerbose .= '      alias make make VERBOSE=on' . "\n";
    $makeVerbose .= '    endif' . "\n";
    $makeVerbose .= '    unset aliasMake' . "\n";
    $makeVerbose .= '  endif' . "\n";
    $makeVerbose .= 'endif' . "\n";
  }
  elsif ($site eq FRETemplate::SITE_DOE)
  {
    $makeVerbose .= 'if ( $?PBS_ENVIRONMENT ) then' . "\n";
    $makeVerbose .= '  if ( $PBS_ENVIRONMENT == "PBS_BATCH" ) then' . "\n";
    $makeVerbose .= '    set aliasMake = `alias make`' . "\n";
    $makeVerbose .= '    if ( $aliasMake != "" ) then' . "\n";
    $makeVerbose .= '      alias make $aliasMake VERBOSE=on' . "\n";
    $makeVerbose .= '    else' . "\n";
    $makeVerbose .= '      alias make make VERBOSE=on' . "\n";
    $makeVerbose .= '    endif' . "\n";
    $makeVerbose .= '    unset aliasMake' . "\n";
    $makeVerbose .= '  endif' . "\n";
    $makeVerbose .= 'endif' . "\n";
  }

  $s =~ s/$placeholder/$makeVerbose/;

  return $s;

}

sub setVersionInfo($$$%)
# ------ arguments: $script $expt $caller %options
{

  my ($s, $z, $c, %o) = @_;

  my $prefix = FRETemplate::PRAGMA_PREFIX;
  my $versionInfo = FRETemplate::PRAGMA_VERSION_INFO;
  my $placeholder = qr/^[ \t]*$prefix[ \t]+$versionInfo[ \t]*$/mo;

  my $configFileAbsPathName = $z->fre()->configFileAbsPathName();
  
  $/ = "";
  chomp(my $createDate = qx(date +%Y-%m-%dT%H:%M:%S));
  
  my $info = "# The script created at $createDate via:\n# $c";
  foreach my $key (sort(keys(%o)))
  {
    my $value = ($key eq 'xmlfile') ? $configFileAbsPathName : $o{$key};
    if ($value eq '1')
    {
      $info .= ' --' . $key;
    }
    elsif ($value ne '0')
    {
      $info .= ' --' . $key . '=' . $value;
    }
  }

  $s =~ s/$placeholder/$info/;

  return $s;

}

# //////////////////////////////////////////////////////////////////////////////
# //////////////////////////////////////////////////////////// Initialization //
# //////////////////////////////////////////////////////////////////////////////

return 1;
