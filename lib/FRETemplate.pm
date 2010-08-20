#
# $Id: FRETemplate.pm,v 18.0.2.2 2010/08/19 17:34:43 afy Exp $
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
  
  my %option =
  (
    npes	=> $option->($fre, 'FRE.scheduler.option.npes', POSIX::ceil($n / $coresPerNode) * $coresPerNode),
    time	=> $option->($fre, 'FRE.scheduler.option.time', $t),
    segmentTime	=> $option->($fre, 'FRE.scheduler.option.segmentTime', $g),
    queue	=> $option->($fre, 'FRE.scheduler.option.queue', $queue),
    stdout	=> $option->($fre, 'FRE.scheduler.option.stdout', $d),
    join	=> $option->($fre, 'FRE.scheduler.option.join'),
    cpuset	=> $option->($fre, 'FRE.scheduler.option.cpuset'),
    rerun	=> $option->($fre, 'FRE.scheduler.option.rerun'),
    mail	=> $option->($fre, 'FRE.scheduler.option.mail')
  );
  
  %option =
  (
    %option,
    project	=> $option->($fre, 'FRE.scheduler.option.project', $project),
    projectAux	=> $option->($fre, 'FRE.scheduler.option.generic', "FRE_PROJECT=$project")
  ) if $project;
  
  foreach my $key (sort keys %option)
  {
    my $value = $option{$key}; 
    $s =~ s/($placeholder)/$1\n$prefix $value/ if $value; 
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
  my $optionProjectDual = $option->($fre, 'FRE.scheduler.option.projectDual');

  $s =~ s/($placeholder)/$1\n$prefix $optionProjectDual/ if $optionProjectDual; 
  
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
