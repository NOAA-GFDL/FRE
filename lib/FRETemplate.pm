#
# $Id: FRETemplate.pm,v 18.0.2.11 2011/02/09 22:09:30 afy Exp $
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
# ------------------------------------------------------------------------------
# Copyright (C) NOAA Geophysical Fluid Dynamics Laboratory, 2009-2011
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

use constant PRAGMA_PREFIX => '#FRE';
use constant PRAGMA_FLAG => 'flag';
use constant PRAGMA_CONSTANT => 'const';
use constant PRAGMA_VARIABLE => 'var';
use constant PRAGMA_SCHEDULER_OPTIONS => 'scheduler-options';
use constant PRAGMA_SCHEDULER_MAKE_VERBOSE => 'scheduler-make-verbose';
use constant PRAGMA_VERSION_INFO => 'version-info';

# //////////////////////////////////////////////////////////////////////////////
# ///////////////////////////////////////////////////////////////// Utilities //
# //////////////////////////////////////////////////////////////////////////////

my $option = sub($$;$)
# ------ arguments: $fre $name $value
{
  my ($fre, $n, $v) = @_;
  my $optionString = $fre->property($n);
  $optionString =~ s/\$/$v/;
  return $optionString;
};

my $schedulerResources = sub($$$$$$)
# ------ arguments: $expt $jobType $ncores $time $partition $queue
{

  my ($z, $j, $n, $t, $p, $q) = @_;
  my $fre = $z->fre();
  
  if ($fre->property("FRE.scheduler.enabled"))
  {

    my $project = $fre->project();
    my $partition = $p || $fre->property("FRE.scheduler.$j.partition");
    my $queue = $q || $fre->property("FRE.scheduler.$j.queue");
    my $coresPerJobInc = $fre->property("FRE.scheduler.$j.coresPerJob.inc") || 1;
    my $coresPerJobMax = $fre->property("FRE.scheduler.$j.coresPerJob.max") || &POSIX::INT_MAX;
    my $mailMode = $fre->mailMode();

    my $ncores = ($n < $coresPerJobInc) ? $coresPerJobInc : (($coresPerJobMax < $n) ? $coresPerJobMax : $n);

    my %option =
    (
      ncores      => $option->($fre, 'FRE.scheduler.option.ncores', POSIX::ceil($ncores / $coresPerJobInc) * $coresPerJobInc),
      time        => $option->($fre, 'FRE.scheduler.option.time', $t),
      partition   => $option->($fre, 'FRE.scheduler.option.partition', $partition),
      queue       => $option->($fre, 'FRE.scheduler.option.queue', $queue),
      join        => $option->($fre, 'FRE.scheduler.option.join'),
      cpuset      => $option->($fre, 'FRE.scheduler.option.cpuset'),
      rerun       => $option->($fre, 'FRE.scheduler.option.rerun'),
      mail        => $option->($fre, 'FRE.scheduler.option.mail', $mailMode)
    );

    %option =
    (
      %option,
      project     => $option->($fre, 'FRE.scheduler.option.project', $project),
      projectAux  => $option->($fre, 'FRE.scheduler.option.generic', "FRE_PROJECT=$project")
    ) if $project;

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

  if ($fre->property("FRE.scheduler.enabled"))
  {
    my %option =
    (
      name    => $option->($fre, 'FRE.scheduler.option.name', $n),
      stdout  => $option->($fre, 'FRE.scheduler.option.stdout', $d),
      workDir => $option->($fre, 'FRE.scheduler.option.workDir', $d)
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

sub setSchedulerResources($$$$$$$)
# ------ arguments: $refToScript $expt $jobType $ncores $time $partition $queue
{

  my ($r, $z, $j, $n, $t, $p, $q) = @_;

  my $prefix = FRETemplate::PRAGMA_PREFIX;
  my $schedulerOptions = FRETemplate::PRAGMA_SCHEDULER_OPTIONS;
  my $placeholder = qr/^[ \t]*$prefix[ \t]+$schedulerOptions[ \t]*$/mo;

  my $schedulerPrefix = $z->fre()->property('FRE.scheduler.prefix');
  my $h = $schedulerResources->($z, $j, $n, $t, $p, $q);
  
  foreach my $key (sort keys %{$h})
  {
    my $value = $h->{$key}; 
    ${$r} =~ s/($placeholder)/$1\n$schedulerPrefix $value/ if $value; 
  }
  
}

sub schedulerResourcesAsString($$$$$$)
# ------ arguments: $expt $jobType $ncores $time $partition $queue
{

  my ($z, $j, $n, $t, $p, $q) = @_;

  my ($h, @result) = ($schedulerResources->($z, $j, $n, $t, $p, $q), ());

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

sub setSchedulerDualRuns($$)
# ------ arguments: $refToScript $exp
{

  my ($r, $z) = @_;

  my $prefix = FRETemplate::PRAGMA_PREFIX;
  my $schedulerOptions = FRETemplate::PRAGMA_SCHEDULER_OPTIONS;
  my $placeholder = qr/^[ \t]*$prefix[ \t]+$schedulerOptions[ \t]*$/mo;

  my $fre = $z->fre();
  my $prefix = $fre->property('FRE.scheduler.prefix');
  my $optionProjectDual = $option->($fre, 'FRE.scheduler.option.projectDual');

  ${$r} =~ s/($placeholder)/$1\n$prefix $optionProjectDual/ if $optionProjectDual; 
  
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

  ${$r} =~ s/$placeholder/$info/;

}

# //////////////////////////////////////////////////////////////////////////////
# //////////////////////////////////////////////////////////// Initialization //
# //////////////////////////////////////////////////////////////////////////////

return 1;
