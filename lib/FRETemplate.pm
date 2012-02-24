#
# $Id: FRETemplate.pm,v 18.0.2.18.2.2 2013/01/05 00:27:34 afy Exp $
# ------------------------------------------------------------------------------
# FMS/FRE Project: Template Management Module
# ------------------------------------------------------------------------------
# arl    Ver  18.00  Merged revision 1.1.2.7 onto trunk             March 10
# afy -------------- Branch 18.0.2 -------------------------------- July 10
# afy    Ver   1.00  Modify setSchedulerOptions (properties)        July 10
# afy    Ver   1.01  Modify setSchedulerDualRuns (properties)       July 10
# afy    Ver   1.02  Modify setSchedulerMakeVerbose (properties)    July 10
# afy    Ver   2.00  Add setFlag subroutine                         August 10
# afy    Ver   2.01  Add setVariable subroutine                     August 10
# afy    Ver   2.02  Add setList subroutine                         August 10
# afy    Ver   3.00  Modify setSchedulerOptions (partition)         September 10
# afy    Ver   3.01  Modify setSchedulerDualRuns (refToScript)      September 10
# afy    Ver   3.02  Modify setSchedulerMakeVerbose (refToScript)   September 10
# afy    Ver   3.03  Modify setVersionInfo (refToScript)            September 10
# afy    Ver   4.00  Split setSchedulerOptions into two parts       September 10
# afy    Ver   5.00  Modify setSchedulerResources (fix ncores)      September 10
# afy    Ver   5.01  Modify setSchedulerResources (queue)           September 10
# afy    Ver   6.00  Add scheduler(Resources|Names) utilities       September 10
# afy    Ver   6.01  Add scheduler(Resources|Nsames)AsString subs   September 10
# afy    Ver   6.02  Modify setScheduler(Resources|Names) subs      September 10
# afy    Ver   7.00  Modify schedulerResources (add parameter)      September 10
# afy    Ver   7.01  Modify setSchedulerResources (use new ^)       September 10
# afy    Ver   7.02  Modify schedulerResourcesAsString (use new ^)  September 10
# afy    Ver   8.00  Modify schedulerResources (add mail mode)      December 10
# afy    Ver   9.00  Modify schedulerNames (add workDir)            December 10
# afy    Ver  10.00  Modify schedulerResources (add check)          January 11
# afy    Ver  10.01  Modify schedulerNames (add check)              January 11
# afy    Ver  11.00  Modify schedulerResources (segTime/queue)      February 11
# afy    Ver  11.01  Modify setSchedulerResources (use new ^)       February 11
# afy    Ver  11.02  Modify schedulerResourcesAsString (use new ^)  February 11
# afy    Ver  12.00  Modify schedulerResources (generic ones)       February 11
# afy    Ver  12.01  Modify option (return emptyness if !$v)        February 11
# afy    Ver  13.00  Modify schedulerNames (name length limit)      February 11
# afy    Ver  14.00  Use new FRE (propertyParameterized)            March 11
# afy    Ver  14.01  Add setAlias subroutine                        March 11
# afy    Ver  15.00  Modify schedulerNames (stdoutUmask)            May 11
# afy    Ver  16.00  Modify schedulerResources (no FRE_PROJECT)     June 11
# afy    Ver  17.00  Modify schedulerResources (remove project)     January 12
# afy    Ver  17.01  Modify schedulerNames (dualFlag, add project)  January 12
# afy    Ver  17.02  Modify schedulerNames (add envVars)            January 12
# afy    Ver  17.03  Modify setSchedulerNames (add argument)        January 12
# afy    Ver  17.04  Modify schedulerNamesAsString (add argument)   January 12
# afy    Ver  17.05  Remove setSchedulerDualRuns subroutine         January 12
# afy    Ver  18.00  Modify schedulerResources (add shell)          February 12
# afy    Ver  18.01  Modify schedulerNames (add priority)           February 12
# afy -------------- Branch 18.0.2.18.2 --------------------------- December 12
# afy    Ver   1.00  Add '*Account*' subs                           December 12
# afy    Ver   1.01  Modify '*Resources*' subs (add dualFlag)       December 12
# afy    Ver   1.02  Modify '*Names' subs (remove dualFlag)         December 12
# afy    Ver   2.00  Modify 'schedulerResources' (job.size)         January 13
# ------------------------------------------------------------------------------
# Copyright (C) NOAA Geophysical Fluid Dynamics Laboratory, 2009-2013
# Designed and written by V. Balaji, Amy Langenhorst and Aleksey Yakovlev
#

package FRETemplate;

use strict; 

use POSIX();

use FRE();

# //////////////////////////////////////////////////////////////////////////////
# ////////////////////////////////////////////////////////// Global Constants //
# //////////////////////////////////////////////////////////////////////////////

use constant PRAGMA_PREFIX => '#FRE';
use constant PRAGMA_FLAG => 'flag';
use constant PRAGMA_CONSTANT => 'const';
use constant PRAGMA_VARIABLE => 'var';
use constant PRAGMA_ALIAS => 'alias';
use constant PRAGMA_SCHEDULER_OPTIONS => 'scheduler-options';
use constant PRAGMA_SCHEDULER_MAKE_VERBOSE => 'scheduler-make-verbose';
use constant PRAGMA_VERSION_INFO => 'version-info';

# //////////////////////////////////////////////////////////////////////////////
# ///////////////////////////////////////////////////////////////// Utilities //
# //////////////////////////////////////////////////////////////////////////////

my $schedulerAccount = sub($$)
# ------ arguments: $expt $windfallFlag
{

  my ($z, $f) = @_;
  my $fre = $z->fre();

  if ($fre->property('FRE.scheduler.enabled'))
  {

    my $project = (($f) ? $fre->property('FRE.scheduler.windfall.project.set') : $fre->property('FRE.scheduler.windfall.project.unset')) || $fre->project();
    my $qos = ($f) ? $fre->property('FRE.scheduler.windfall.qos.set') : $fre->property('FRE.scheduler.windfall.qos.unset');

    my %option =
    (
      project     => $fre->propertyParameterized('FRE.scheduler.option.project', $project),
      qos         => $fre->propertyParameterized('FRE.scheduler.option.qos', $qos)
    );

    return \%option;
  
  }
  else
  {

    return undef;

  }

};

my $schedulerResources = sub($$$$$$$)
# ------ arguments: $expt $jobType $ncores $time $partition $queue $dualFlag
{

  my ($z, $j, $n, $t, $p, $q, $f) = @_;
  my $fre = $z->fre();

  if ($fre->property('FRE.scheduler.enabled'))
  {

    my $partition = $p || $fre->property("FRE.scheduler.$j.partition");
    my $queue = (($f) ? $fre->property('FRE.scheduler.dual.queue') : undef) || $q || $fre->property("FRE.scheduler.$j.queue");
    my $priority = ($f) ? $fre->property('FRE.scheduler.dual.priority') : undef;
    my $qos = ($f) ? $fre->property('FRE.scheduler.dual.qos') : undef;
    my $mailMode = $fre->mailMode();

    my %option =
    (
      time        => $fre->propertyParameterized('FRE.scheduler.option.time', $t),
      partition   => $fre->propertyParameterized('FRE.scheduler.option.partition', $partition),
      queue       => $fre->propertyParameterized('FRE.scheduler.option.queue', $queue),
      priority    => $fre->propertyParameterized('FRE.scheduler.option.priority', $priority),
      qos         => $fre->propertyParameterized('FRE.scheduler.option.qos', $qos),
      join        => $fre->propertyParameterized('FRE.scheduler.option.join'),
      stdoutUmask => $fre->propertyParameterized('FRE.scheduler.option.stdoutUmask', '026'),
      cpuset      => $fre->propertyParameterized('FRE.scheduler.option.cpuset'),
      rerun       => $fre->propertyParameterized('FRE.scheduler.option.rerun'),
      mail        => $fre->propertyParameterized('FRE.scheduler.option.mail', $mailMode),
      envVars     => $fre->propertyParameterized('FRE.scheduler.option.envVars'),
      shell       => $fre->propertyParameterized('FRE.scheduler.option.shell')
    );

    if ($n)
    {
      my $coresPerJobInc = $fre->property("FRE.scheduler.$j.coresPerJob.inc") || 1;
      my $coresPerJobMax = $fre->property("FRE.scheduler.$j.coresPerJob.max") || &POSIX::INT_MAX;
      my $ncores = ($n < $coresPerJobInc) ? $coresPerJobInc : (($coresPerJobMax < $n) ? $coresPerJobMax : $n);
      $option{size} = $fre->propertyParameterized("FRE.scheduler.option.$j.size", POSIX::ceil($ncores / $coresPerJobInc) * $coresPerJobInc),
    }
    
    return \%option;

  }
  else
  {

    return undef;

  }

};

my $schedulerNames = sub($$$)
# ------ arguments: $expt $scriptName $stdoutDir
{

  my ($z, $n, $d) = @_;
  my $fre = $z->fre();

  if ($fre->property('FRE.scheduler.enabled'))
  {

    my $nameLen = $fre->property('FRE.scheduler.option.name.len');
    $n = substr($n, 0, $nameLen) if $nameLen > 0;

    my %option =
    (
      name        => $fre->propertyParameterized('FRE.scheduler.option.name', $n),
      stdout      => $fre->propertyParameterized('FRE.scheduler.option.stdout', $d),
      workDir     => $fre->propertyParameterized('FRE.scheduler.option.workDir', $d)
    );

    return \%option; 

  }
  else
  {

    return undef;

  }

};

# //////////////////////////////////////////////////////////////////////////////
# //////////////////////////////////////////////////////// Exported Functions //
# //////////////////////////////////////////////////////////////////////////////

sub setAlias($$$)
# ------ arguments: $refToScript $name $value
{
  my ($r, $n, $v) = @_;
  my $prefix = FRETemplate::PRAGMA_PREFIX;
  my $alias = FRETemplate::PRAGMA_ALIAS;
  my ($placeholderPrefix, $placeholderSuffix) = (qr/^([ \t]*)$prefix[ \t]+$alias[ \t]*\([ \t]*/mo, qr/[ \t]*\)[ \t]*$/mo);
  ${$r} =~ s/$placeholderPrefix$n$placeholderSuffix/$1alias $n $v/;
}

sub setFlag($$$)
# ------ arguments: $refToScript $name $value
{
  my ($r, $n, $v) = @_;
  my $prefix = FRETemplate::PRAGMA_PREFIX;
  my $flag = FRETemplate::PRAGMA_FLAG;
  my ($placeholderPrefix, $placeholderSuffix) = (qr/^([ \t]*)$prefix[ \t]+$flag[ \t]*\([ \t]*/mo, qr/[ \t]*\)[ \t]*$/mo);
  ${$r} =~ s/$placeholderPrefix$n$placeholderSuffix/$1set -r $n$v/;
}

sub setVariable($$$)
# ------ arguments: $refToScript $name $value
{
  my ($r, $n, $v) = @_;
  my $prefix = FRETemplate::PRAGMA_PREFIX;
  my ($constant, $variable) = (FRETemplate::PRAGMA_CONSTANT, FRETemplate::PRAGMA_VARIABLE);
  my ($placeholderPrefix, $placeholderSuffix) = (qr/^([ \t]*)$prefix[ \t]+($constant|$variable)[ \t]*\([ \t]*/mo, qr/[ \t]*\)[ \t]*$/mo);
  if (${$r} =~ m/$placeholderPrefix$n$placeholderSuffix/)
  {
    my $cmd = ($2 eq $constant) ? 'set -r' : 'set';
    substr(${$r}, $-[0], $+[0] - $-[0]) = "$1$cmd $n = $v";
  }
}

sub setList($$@)
# ------ arguments: $refToScript $name @value
{
  my ($r, $n, @v) = @_;
  my $prefix = FRETemplate::PRAGMA_PREFIX;
  my ($constant, $variable) = (FRETemplate::PRAGMA_CONSTANT, FRETemplate::PRAGMA_VARIABLE);
  my ($placeholderPrefix, $placeholderSuffix) = (qr/^([ \t]*)$prefix[ \t]+($constant|$variable)[ \t]*\([ \t]*/mo, qr/[ \t]*\)[ \t]*$/mo);
  if (${$r} =~ m/$placeholderPrefix$n$placeholderSuffix/)
  {
    my $list = join ' ', @v;
    my $cmd = ($2 eq $constant) ? 'set -r' : 'set';
    substr(${$r}, $-[0], $+[0] - $-[0]) = "$1$cmd $n = ( $list )";
  }
}

sub setSchedulerAccount($$$)
# ------ arguments: $refToScript $expt $windfallFlag
{

  my ($r, $z, $f) = @_;

  my $prefix = FRETemplate::PRAGMA_PREFIX;
  my $schedulerOptions = FRETemplate::PRAGMA_SCHEDULER_OPTIONS;
  my $placeholder = qr/^[ \t]*$prefix[ \t]+$schedulerOptions[ \t]*$/mo;

  my $schedulerPrefix = $z->fre()->property('FRE.scheduler.prefix');
  my $h = $schedulerAccount->($z, $f);

  foreach my $key (sort keys %{$h})
  {
    my $value = $h->{$key}; 
    ${$r} =~ s/($placeholder)/$1\n$schedulerPrefix $value/ if $value; 
  }

}

sub schedulerAccountAsString($$)
# ------ arguments: $expt $windfallFlag
{

  my ($z, $f) = @_;

  my ($h, @result) = ($schedulerAccount->($z, $f), ());

  foreach my $key (sort keys %{$h})
  {
    my $value = $h->{$key}; 
    push @result, $value if $value; 
  }

  return join ' ', @result; 

}

sub setSchedulerResources($$$$$$$$)
# ------ arguments: $refToScript $expt $jobType $ncores $time $partition $queue $dualFlag
{

  my ($r, $z, $j, $n, $t, $p, $q, $f) = @_;

  my $prefix = FRETemplate::PRAGMA_PREFIX;
  my $schedulerOptions = FRETemplate::PRAGMA_SCHEDULER_OPTIONS;
  my $placeholder = qr/^[ \t]*$prefix[ \t]+$schedulerOptions[ \t]*$/mo;

  my $schedulerPrefix = $z->fre()->property('FRE.scheduler.prefix');
  my $h = $schedulerResources->($z, $j, $n, $t, $p, $q, $f);
  
  foreach my $key (sort keys %{$h})
  {
    my $value = $h->{$key}; 
    ${$r} =~ s/($placeholder)/$1\n$schedulerPrefix $value/ if $value; 
  }
  
}

sub schedulerResourcesAsString($$$$$$$)
# ------ arguments: $expt $jobType $ncores $time $partition $queue $dualFlag
{

  my ($z, $j, $n, $t, $p, $q, $f) = @_;

  my ($h, @result) = ($schedulerResources->($z, $j, $n, $t, $p, $q, $f), ());

  foreach my $key (sort keys %{$h})
  {
    my $value = $h->{$key}; 
    push @result, $value if $value; 
  }

  return join ' ', @result; 
  
}

sub setSchedulerNames($$$$)
# ------ arguments: $refToScript $expt $scriptName $stdoutDir
{

  my ($r, $z, $n, $d) = @_;

  my $prefix = FRETemplate::PRAGMA_PREFIX;
  my $schedulerOptions = FRETemplate::PRAGMA_SCHEDULER_OPTIONS;
  my $placeholder = qr/^[ \t]*$prefix[ \t]+$schedulerOptions[ \t]*$/mo;

  my $schedulerPrefix = $z->fre()->property('FRE.scheduler.prefix');
  my $h = $schedulerNames->($z, $n, $d);
  
  foreach my $key (sort keys %{$h})
  {
    my $value = $h->{$key}; 
    ${$r} =~ s/($placeholder)/$1\n$schedulerPrefix $value/ if $value; 
  }
  
}

sub schedulerNamesAsString($$$)
# ------ arguments: $expt $scriptName $stdoutDir
{

  my ($z, $n, $d) = @_;

  my ($h, @result) = ($schedulerNames->($z, $n, $d), ());
  
  foreach my $key (sort keys %{$h})
  {
    my $value = $h->{$key}; 
    push @result, $value if $value; 
  }

  return join ' ', @result; 

}

sub setSchedulerMakeVerbose($$)
# ------ arguments: $reToScript $exp
{

  my ($r, $z) = @_;

  my $prefix = FRETemplate::PRAGMA_PREFIX;
  my $schedulerOptions = FRETemplate::PRAGMA_SCHEDULER_MAKE_VERBOSE;
  my $placeholder = qr/^[ \t]*$prefix[ \t]+$schedulerOptions[ \t]*$/mo;

  my $fre = $z->fre();
  my $variableEnv = $fre->property('FRE.scheduler.variable.environment');
  my $variableEnvValueBatch = $fre->property('FRE.scheduler.variable.environment.value.batch');
  my $makeVerbose = '';
  
  $makeVerbose .= 'if ( $?' . $variableEnv . ' ) then' . "\n";
  $makeVerbose .= '  if ( $' . $variableEnv . ' == "' . $variableEnvValueBatch . '" ) then' . "\n";
  $makeVerbose .= '    set aliasMake = `alias make`' . "\n";
  $makeVerbose .= '    if ( $aliasMake != "" ) then' . "\n";
  $makeVerbose .= '      alias make $aliasMake VERBOSE=on' . "\n";
  $makeVerbose .= '    else' . "\n";
  $makeVerbose .= '      alias make make VERBOSE=on' . "\n";
  $makeVerbose .= '    endif' . "\n";
  $makeVerbose .= '    unset aliasMake' . "\n";
  $makeVerbose .= '  endif' . "\n";
  $makeVerbose .= 'endif' . "\n";

  ${$r} =~ s/$placeholder/$makeVerbose/;

}

sub setVersionInfo($$$%)
# ------ arguments: $refToScript $expt $caller %options
{

  my ($r, $z, $c, %o) = @_;

  my $prefix = FRETemplate::PRAGMA_PREFIX;
  my $versionInfo = FRETemplate::PRAGMA_VERSION_INFO;
  my $placeholder = qr/^[ \t]*$prefix[ \t]+$versionInfo[ \t]*$/mo;

  my $configFileAbsPathName = $z->fre()->configFileAbsPathName();
  
  $/ = "";
  chomp(my $createDate = qx(date +%Y-%m-%dT%H:%M:%S));
  
  my $info = "# The script created at $createDate via:\n# $c";
  foreach my $key (sort keys %o)
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

  ${$r} =~ s/$placeholder/$info/;

}

# //////////////////////////////////////////////////////////////////////////////
# //////////////////////////////////////////////////////////// Initialization //
# //////////////////////////////////////////////////////////////////////////////

return 1;
