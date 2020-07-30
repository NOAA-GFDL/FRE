#
# $Id: FRETemplate.pm,v 18.0.2.28.2.2.4.1 2014/09/18 15:16:12 sdu Exp $
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
# afy    Ver  19.00  Add 'schedulerSize' utility                    April 12
# afy    Ver  19.01  Modify 'schedulerResources' utility            April 12
# afy    Ver  19.02  Add 'setSchedulerSize' subroutine              April 12
# afy    Ver  19.03  Add 'schedulerSizeAsString' utility            April 12
# afy    Ver  19.03  Add 'schedulerSizeAsString' subroutine         April 12
# afy    Ver  20.00  Modify 'schedulerNames' (dual settings)        April 12
# afy    Ver  20.01  Modify 'schedulerSize' (better placement)      April 12
# afy    Ver  21.00  Modify 'schedulerSize' (rename property)       May 12
# afy    Ver  21.01  Modify 'schedulerResources' (rename property)  May 12
# afy    Ver  22.00  Modify 'schedulerSize' (add concurrency flag)  June 12
# afy    Ver  23.00  Add 'FRETemplatePragmaCsh' global variable     July 12
# afy    Ver  23.01  Add 'setInputDatasets' subroutine              July 12
# afy    Ver  23.02  Add 'setTable' subroutine                      July 12
# afy    Ver  23.03  Add 'setNamelists' subroutine                  July 12
# afy    Ver  23.04  Add 'setShellCommands' subroutine              July 12
# afy    Ver  23.05  Standardize the 'fre' argument usage           July 12
# afy    Ver  24.00  Modify 'setNamelists' (expanded/unexpanded)    July 12
# afy    Ver  25.00  Add '*Account*' subs                           December 12
# afy    Ver  25.01  Modify '*Resources*' subs (add dualFlag)       December 12
# afy    Ver  25.02  Modify '*Names' subs (remove dualFlag)         December 12
# afy    Ver  25.00  Fix 'schedulerResources' utility               December 12
# afy    Ver  26.00  Modify 'schedulerSize' (generics)              February 13
# afy    Ver  26.01  Modify 'setSchedulerSize' (generics)           February 13
# afy    Ver  26.02  Modify 'schedulerSizeAsString' (generics)      February 13
# afy    Ver  26.03  Add 'setRunCommandSize' subroutine             February 13
# afy    Ver  27.00  Modify 'setRunCommandSize' (fix w/o coupler)   March 13
# afy    Ver  28.00  Replace 'setRunCommandSize' => 'setRunCommand' April 13
# ------------------------------------------------------------------------------
# Copyright (C) NOAA Geophysical Fluid Dynamics Laboratory, 2009-2013
# Designed and written by V. Balaji, Amy Langenhorst and Aleksey Yakovlev
#

package FRETemplate;

use strict;

use List::Util();
use POSIX();

use FRE();
use FREMsg();
use FRENamelists();
use FREUtil();

# //////////////////////////////////////////////////////////////////////////////
# ////////////////////////////////////////////////////////// Global Constants //
# //////////////////////////////////////////////////////////////////////////////

use constant PRAGMA_PREFIX                 => '#FRE';
use constant PRAGMA_FLAG                   => 'flag';
use constant PRAGMA_CONSTANT               => 'const';
use constant PRAGMA_VARIABLE               => 'var';
use constant PRAGMA_ALIAS                  => 'alias';
use constant PRAGMA_SCHEDULER_OPTIONS      => 'scheduler-options';
use constant PRAGMA_SCHEDULER_MAKE_VERBOSE => 'scheduler-make-verbose';
use constant PRAGMA_VERSION_INFO           => 'version-info';
use constant PRAGMA_RUN_COMMAND_SIZE       => 'run-command-size';
use constant PRAGMA_DATAFILES              => 'dataFiles';
use constant PRAGMA_FMSDATASETS            => 'fmsDataSets';
use constant PRAGMA_GENERIC_TABLE          => 'table';
use constant PRAGMA_NAMELISTS_EXPANDED     => 'namelists-expanded';
use constant PRAGMA_NAMELISTS_UNEXPANDED   => 'namelists';

# //////////////////////////////////////////////////////////////////////////////
# ////////////////////////////////////////////////////////// Global Variables //
# //////////////////////////////////////////////////////////////////////////////

my %FRETemplatePragmaCsh = (
    'platformCsh'                => 'setup-platform-csh',
    'NiNaCplatformCsh'           => 'ninac-platform-csh',
    'expRuntimeCsh'              => 'experiment-runtime-csh',
    'expInputCshInit'            => 'experiment-input-csh-init',
    'expInputCshAlwaysOrNotInit' => 'experiment-input-csh-always-or-postinit',
    'expPostProcessCsh'          => 'experiment-postprocess-csh'
);

# //////////////////////////////////////////////////////////////////////////////
# ///////////////////////////////////////////////////////////////// Utilities //
# //////////////////////////////////////////////////////////////////////////////

my $schedulerSize = sub($$$$$$$)

    # ------ arguments: $fre $jobType $couplerFlag $npes $refNPes $refNTds $refNTdsRes
{

    my ( $fre, $j, $cf, $np, $rp, $rt, $rtr ) = @_;
    my $coresPerJobInc = $fre->property("FRE.scheduler.$j.coresPerJob.inc") || 1;
    my $coresPerJobMax = $fre->property("FRE.scheduler.$j.coresPerJob.max") || &POSIX::INT_MAX;

    my $coresDistributed = sub($$)

        # ------ arguments: $np $nt
    {
        my ( $np, $nt ) = @_;
        if ( $np > 0 ) {

            # $procsM :: How may MPI processes we can have per node when using $nt threads
            # $nodesM :: Number of fully utilized nodes
            my $procsM = POSIX::floor( $coresPerJobInc / $nt );
            my $nodesM = POSIX::floor( $np / $procsM );
            $fre->out( FREMsg::WARNING,
                "It's not optimal to place '$nt' OpenMP threads on a node with '$coresPerJobInc' cores"
            ) if $coresPerJobInc % $nt;

            # When $procsM is not a perfect divisor of $np, then the extra
            # processors on the extra node need to be handled properly.
            if ( $np % $procsM ) {

                # One node will not be fully utilized.
                # It has the extra processors.
                if ( $nodesM > 0 ) {
                    return ( $nodesM, $procsM, 1, $np - $nodesM * $procsM );
                }
                else {
                    return ( 1, $np );
                }
            }
            else {

                # All nodes are fully utilized.
                return ( $nodesM, $procsM );
            }
        } ## end if ( $np > 0 )
        else {
            return ();
        }
    };

    my $coresDistributedList = sub($$)

        # ------ arguments: $rp $rt
    {
        my ( $rp, $rt ) = @_;
        my @result = ();
        for ( my $inx = 0; $inx < scalar( @{$rp} ); $inx++ ) {
            push @result, $coresDistributed->( $rp->[$inx], $rt->[$inx] );
        }
        return @result;
    };

    my $coresAggregated = sub($$)

        # ------ arguments: $nMPIcores $nthreads
    {
        my ( $np, $nt ) = @_;

        if ( $np > 0 ) {
            # $procsM :: How may MPI processes we can have per node when using $nt threads
            # $nodesM :: How many nodes are needed for all MPI processes
            my $procsM = POSIX::floor( $coresPerJobInc / $nt );
            my $nodesM = POSIX::ceil( $np / $procsM );

            if ( $fre->property("FRE.scheduler.option.reqNodes") ) {

                # Return the number of nodes if using nodes for the size instead of number of cores
                return $nodesM;
            }

            # $totProcs :: Total number of processors needed for reservation
            my $totProcs = $nodesM * $coresPerJobInc;

            # I'm not sure why this check is here.  This should probably be a FATAL
            # instead of resetting to the coresPerJobMax, but this was in the original
            # FRETemplate.pm before putting in this fix.
            $totProcs = $coresPerJobMax if $totProcs > $coresPerJobMax;

            return $totProcs;
        } ## end if ( $np > 0 )
        else {
            return 0;
        }
    };

    my $coresAggregatedList = sub($$)

        # ------ arguments: $rp $rt
    {
        my ( $rp, $rt ) = @_;
        my $size = 0;
        for ( my $inx = 0; $inx < scalar( @{$rp} ); $inx++ ) {
            $size += $coresAggregated->( $rp->[$inx], $rt->[$inx] );
        }
        return $size;
    };

    if ( $fre->property('FRE.scheduler.enabled') ) {
        my %option = ();
        if ( $fre->property("FRE.scheduler.option.size.$j.distributed") ) {
            my @nodeSpec
                = ($cf) ? $coresDistributedList->( $rp, $rtr ) : $coresDistributed->( $np, 1 );
            my $nodeSpecSize = scalar(@nodeSpec);
            $option{size}
                = $fre->propertyParameterized( "FRE.scheduler.option.size.$j.$nodeSpecSize",
                @nodeSpec );
        }
        else {
            my $size = ($cf) ? $coresAggregatedList->( $rp, $rtr ) : $coresAggregated->( $np, 1 );
            $option{size} = $fre->propertyParameterized( "FRE.scheduler.option.size.$j", $size );
        }
        return \%option;
    }
    else {
        return undef;
    }

};

my $schedulerAccount = sub($)

    # ------ arguments: $fre
{

    my ( $fre ) = @_;

    if ( $fre->property('FRE.scheduler.enabled') ) {

        my $project = $fre->project();

        my %option = (
            project => $fre->propertyParameterized( 'FRE.scheduler.option.project', $project ),
        );

        return \%option;

    } ## end if ( $fre->property('FRE.scheduler.enabled'...))
    else {

        return undef;

    }

};

my $schedulerResources = sub($$$$$$$)

    # ------ arguments: $fre $jobType $ncores $time $cluster $qos $dualFlag
{

    my ( $fre, $j, $n, $t, $c, $q, $f ) = @_;

    if ( $fre->property('FRE.scheduler.enabled') ) {

        my $cluster =   $c || $fre->property("FRE.scheduler.$j.cluster");
        my $partition =       $fre->property("FRE.scheduler.$j.partition");
        my $dual     = ($f) ? $fre->property('FRE.scheduler.dual.option') : undef;
        my $mailMode = $fre->mailMode();
        my $qos      = $f ? $fre->property('FRE.scheduler.dual.qos') : $q;

        my %option = (
            time => $fre->propertyParameterized( 'FRE.scheduler.option.time', $t ),
            cluster => $fre->propertyParameterized( 'FRE.scheduler.option.cluster', $cluster ),
            partition => $fre->propertyParameterized( 'FRE.scheduler.option.partition', $partition ),
            qos      => $fre->propertyParameterized( 'FRE.scheduler.option.qos', $qos ),
            mail    => $fre->propertyParameterized( 'FRE.scheduler.option.mail', $mailMode ),
            dual    => $dual,
            envVars => $fre->propertyParameterized('FRE.scheduler.option.envVars'),
            mailList => $fre->propertyParameterized('FRE.scheduler.option.mailList', $fre->{mailList}),
        );

        if ($n) {
            my $coresPerJobInc = $fre->property("FRE.scheduler.$j.coresPerJob.inc") || 1;
            my $coresPerJobMax = $fre->property("FRE.scheduler.$j.coresPerJob.max")
                || &POSIX::INT_MAX;
            my $ncores
                = ( $n < $coresPerJobInc )
                ? $coresPerJobInc
                : ( ( $coresPerJobMax < $n ) ? $coresPerJobMax : $n );
            $option{size} = $fre->propertyParameterized( "FRE.scheduler.option.size.$j",
                POSIX::ceil( $ncores / $coresPerJobInc ) * $coresPerJobInc ),
                ;
        }

        return \%option;

    } ## end if ( $fre->property('FRE.scheduler.enabled'...))
    else {

        return undef;

    }

};

my $schedulerNames = sub($$$)

    # ------ arguments: $fre $scriptName $stdoutDir
{

    my ( $fre, $n, $d ) = @_;

    if ( $fre->property('FRE.scheduler.enabled') ) {

        my $nameLen = $fre->property('FRE.scheduler.option.name.len');
        $n = substr( $n, 0, $nameLen ) if $nameLen > 0;

        my %option = (
            name    => $fre->propertyParameterized( 'FRE.scheduler.option.name',    $n ),
            stdout  => $fre->propertyParameterized( 'FRE.scheduler.option.stdout',  $d ),
            workDir => $fre->propertyParameterized( 'FRE.scheduler.option.workDir', $d ),
            freVersion => $fre->propertyParameterized( 'FRE.scheduler.option.freVersion', $fre->{freVersion} )
        );

        return \%option;

    }
    else {

        return undef;

    }

};

my $prepareInputFile = sub($$$)

    # ------ arguments: $fre $source $target
{

    my ( $fre, $s, $t ) = @_;

    if ( File::Spec->file_name_is_absolute($s) ) {

        if ( !File::Spec->file_name_is_absolute($t) ) {

            my $csh = '';

            my $sName = substr( $s, 1 );
            my $sArchiveFlag = FREUtil::fileIsArchive($s);
            $sName = FREUtil::fileArchiveExtensionStrip($sName) if $sArchiveFlag;

            my ( $tFileName, $tDirName ) = File::Basename::fileparse($t);
            my $tDirectoryFlag = ( $tDirName ne './' );

            if ( $sArchiveFlag and $tDirectoryFlag and !$tFileName ) {
                $csh .= '  hsmget ' . $sName . '/\* && \\' . "\n";
                $csh
                    .= '  if (! -d $workDir/'
                    . $tDirName
                    . ') mkdir -p $workDir/'
                    . $tDirName
                    . ' && \\' . "\n";
                $csh
                    .= '  ls $hsmDir/'
                    . $sName
                    . '/* | xargs ln -f -t $workDir/'
                    . $tDirName . "\n";
            }
            elsif ( $sArchiveFlag and $tFileName ) {
                $fre->out( FREMsg::FATAL,
                    "The source archive '$s' can't be linked to the non-directory target '$t'" );
                return undef;
            }
            elsif ( !$sArchiveFlag and ( $tDirectoryFlag or $tFileName ) ) {
                $csh .= '  hsmget ' . $sName . ' && \\' . "\n";
                $csh
                    .= '  if (! -d $workDir/'
                    . $tDirName
                    . ') mkdir -p $workDir/'
                    . $tDirName
                    . ' && \\' . "\n"
                    if $tDirectoryFlag;
                $csh
                    .= '  ln -f $hsmDir/'
                    . $sName
                    . ' $workDir/'
                    . $tDirName
                    . ( ($tFileName) ? $tFileName : '.' ) . "\n";
            }
            else {
                $fre->out( FREMsg::FATAL, "The target pathname is empty" );
                return undef;
            }

            if ($csh) {
                $csh .= '  if ( $status != 0 ) then' . "\n";
                $csh .= '    set dataFilesNotOK = ( $dataFilesNotOK ' . $s . ' )' . "\n";
                $csh .= '  endif' . "\n";
            }

            return $csh;

        } ## end if ( !File::Spec->file_name_is_absolute...)
        else {
            $fre->out( FREMsg::FATAL, "The target pathname '$t' isn't relative" );
            return undef;
        }
    } ## end if ( File::Spec->file_name_is_absolute...)
    else {
        $fre->out( FREMsg::FATAL, "The source pathname '$s' isn't absolute" );
        return undef;
    }

};

my $checkNamelists = sub($$)

    # ------ arguments: $fre $nameListsHandle
{
    my ( $fre, $h ) = @_;
    my $targetListRepro = FRETargets::containsRepro( $fre->target() );
    if ( $h->namelistExists('xgrid_nml') ) {
        my $nmlRepro = $h->namelistBooleanGet( 'xgrid_nml', 'make_exchange_reproduce' );
        if ( $nmlRepro and !$targetListRepro ) {
            $fre->out( FREMsg::WARNING,
                "The 'make_exchange_reproduce' is .TRUE. in the 'xgrid_nml' namelist, which contradicts with absence of 'repro' in your targets"
            );
        }
        elsif ( !$nmlRepro and $targetListRepro ) {
            $fre->out( FREMsg::WARNING,
                "The 'make_exchange_reproduce' is absent or isn't .TRUE. in the 'xgrid_nml' namelist, which contradicts with 'repro' in your targets"
            );
        }
    }
    elsif ($targetListRepro) {
        $fre->out( FREMsg::WARNING,
            "The 'xgrid_nml' namelist isn't found, which contradicts with 'repro' in your targets"
        );
    }
};

# //////////////////////////////////////////////////////////////////////////////
# //////////////////////////////////////////////////////// Exported Functions //
# //////////////////////////////////////////////////////////////////////////////

sub setAlias($$$$)

    # ------ arguments: $fre $refToScript $name $value
{
    my ( $fre, $r, $n, $v ) = @_;
    my $prefix = FRETemplate::PRAGMA_PREFIX;
    my $alias  = FRETemplate::PRAGMA_ALIAS;
    my ( $placeholderPrefix, $placeholderSuffix )
        = ( qr/^([ \t]*)$prefix[ \t]+$alias[ \t]*\([ \t]*/mo, qr/[ \t]*\)[ \t]*$/mo );
    ${$r} =~ s/$placeholderPrefix$n$placeholderSuffix/$1alias $n $v/;
}

sub setFlag($$$$)

    # ------ arguments: $fre $refToScript $name $value
{
    my ( $fre, $r, $n, $v ) = @_;
    my $prefix = FRETemplate::PRAGMA_PREFIX;
    my $flag   = FRETemplate::PRAGMA_FLAG;
    my ( $placeholderPrefix, $placeholderSuffix )
        = ( qr/^([ \t]*)$prefix[ \t]+$flag[ \t]*\([ \t]*/mo, qr/[ \t]*\)[ \t]*$/mo );
    ${$r} =~ s/$placeholderPrefix$n$placeholderSuffix/$1set -r $n$v/;
}

sub setVariable($$$$)

    # ------ arguments: $fre $refToScript $name $value
{
    my ( $fre, $r, $n, $v ) = @_;
    my $prefix = FRETemplate::PRAGMA_PREFIX;
    my ( $constant, $variable ) = ( FRETemplate::PRAGMA_CONSTANT, FRETemplate::PRAGMA_VARIABLE );
    my ( $placeholderPrefix, $placeholderSuffix )
        = ( qr/^([ \t]*)$prefix[ \t]+($constant|$variable)[ \t]*\([ \t]*/mo,
        qr/[ \t]*\)[ \t]*$/mo );
    if ( ${$r} =~ m/$placeholderPrefix$n$placeholderSuffix/ ) {
        my $cmd = ( $2 eq $constant ) ? 'set -r' : 'set';
        substr( ${$r}, $-[0], $+[0] - $-[0] ) = "$1$cmd $n = $v";
    }
}

sub setList($$$@)

    # ------ arguments: $fre $refToScript $name @value
{
    my ( $fre, $r, $n, @v ) = @_;
    my $prefix = FRETemplate::PRAGMA_PREFIX;
    my ( $constant, $variable ) = ( FRETemplate::PRAGMA_CONSTANT, FRETemplate::PRAGMA_VARIABLE );
    my ( $placeholderPrefix, $placeholderSuffix )
        = ( qr/^([ \t]*)$prefix[ \t]+($constant|$variable)[ \t]*\([ \t]*/mo,
        qr/[ \t]*\)[ \t]*$/mo );
    if ( ${$r} =~ m/$placeholderPrefix$n$placeholderSuffix/ ) {
        my $list = join ' ', @v;
        my $cmd = ( $2 eq $constant ) ? 'set -r' : 'set';
        substr( ${$r}, $-[0], $+[0] - $-[0] ) = "$1$cmd $n = ( $list )";
    }
}

sub setSchedulerSize($$$$$$$$)

    # ------ arguments: $fre $refToScript $jobType $couplerFlag $npes $refNPes $refNTds refNTdsRes
{

    my ( $fre, $r, $j, $cf, $np, $rp, $rt, $rtr ) = @_;

    my $prefix           = FRETemplate::PRAGMA_PREFIX;
    my $schedulerOptions = FRETemplate::PRAGMA_SCHEDULER_OPTIONS;
    my $placeholder      = qr/^[ \t]*$prefix[ \t]+$schedulerOptions[ \t]*$/mo;

    my $schedulerPrefix = $fre->property('FRE.scheduler.prefix');
    my $h = $schedulerSize->( $fre, $j, $cf, $np, $rp, $rt, $rtr );

    foreach my $key ( sort keys %{$h} ) {
        my $value = $h->{$key};
        ${$r} =~ s/($placeholder)/$1\n$schedulerPrefix $value/ if $value;
    }

}

sub schedulerSizeAsString($$$$$$$)

    # ------ arguments: $fre $jobType $couplerFlag $npes $refNPes $refNTds $refNTdsRes
{

    my ( $fre, $j, $cf, $np, $rp, $rt, $rtr ) = @_;
    my ( $h, @result ) = ( $schedulerSize->( $fre, $j, $cf, $np, $rp, $rt, $rtr ), () );

    foreach my $key ( sort keys %{$h} ) {
        my $value = $h->{$key};
        push @result, $value if $value;
    }

    return join ' ', @result;

}

sub setSchedulerAccount($$)

    # ------ arguments: $fre $refToScript
{

    my ( $fre, $r ) = @_;

    my $prefix           = FRETemplate::PRAGMA_PREFIX;
    my $schedulerOptions = FRETemplate::PRAGMA_SCHEDULER_OPTIONS;
    my $placeholder      = qr/^[ \t]*$prefix[ \t]+$schedulerOptions[ \t]*$/mo;

    my $schedulerPrefix = $fre->property('FRE.scheduler.prefix');
    my $h = $schedulerAccount->( $fre );

    foreach my $key ( sort keys %{$h} ) {
        my $value = $h->{$key};
        ${$r} =~ s/($placeholder)/$1\n$schedulerPrefix $value/ if $value;
    }

}

sub schedulerAccountAsString($$)

    # ------ arguments: $fre $windfallFlag
{

    my ( $fre, $f ) = @_;

    my ( $h, @result ) = ( $schedulerAccount->( $fre, $f ), () );

    foreach my $key ( sort keys %{$h} ) {
        my $value = $h->{$key};
        push @result, $value if $value;
    }

    return join ' ', @result;

}

sub setSchedulerResources($$$$$$$$)

    # ------ arguments: $fre $refToScript $jobType $ncores $time $cluster $qos $dualFlag
{

    my ( $fre, $r, $j, $n, $t, $c, $q, $f ) = @_;

    my $prefix           = FRETemplate::PRAGMA_PREFIX;
    my $schedulerOptions = FRETemplate::PRAGMA_SCHEDULER_OPTIONS;
    my $placeholder      = qr/^[ \t]*$prefix[ \t]+$schedulerOptions[ \t]*$/mo;

    my $schedulerPrefix = $fre->property('FRE.scheduler.prefix');
    my $h = $schedulerResources->( $fre, $j, $n, $t, $c, $q, $f );

    foreach my $key ( sort keys %{$h} ) {
        my $value = $h->{$key};
        ${$r} =~ s/($placeholder)/$1\n$schedulerPrefix $value/ if $value;
    }

}

sub schedulerResourcesAsString($$$$$$$)

    # ------ arguments: $fre $jobType $ncores $time $cluster $qos $dualFlag
{

    my ( $fre, $j, $n, $t, $c, $q, $f ) = @_;

    my ( $h, @result ) = ( $schedulerResources->( $fre, $j, $n, $t, $c, $q, $f ), () );

    foreach my $key ( sort keys %{$h} ) {
        my $value = $h->{$key};
        push @result, $value if $value;
    }

    return join ' ', @result;

}

sub setSchedulerNames($$$$)

    # ------ arguments: $fre $refToScript $scriptName $stdoutDir
{

    my ( $fre, $r, $n, $d ) = @_;

    my $prefix           = FRETemplate::PRAGMA_PREFIX;
    my $schedulerOptions = FRETemplate::PRAGMA_SCHEDULER_OPTIONS;
    my $placeholder      = qr/^[ \t]*$prefix[ \t]+$schedulerOptions[ \t]*$/mo;

    my $schedulerPrefix = $fre->property('FRE.scheduler.prefix');
    my $h = $schedulerNames->( $fre, $n, $d );

    foreach my $key ( sort keys %{$h} ) {
        my $value = $h->{$key};
        ${$r} =~ s/($placeholder)/$1\n$schedulerPrefix $value/ if $value;
    }

}

sub schedulerNamesAsString($$$)

    # ------ arguments: $fre $scriptName $stdoutDir
{

    my ( $fre, $n, $d ) = @_;

    my ( $h, @result ) = ( $schedulerNames->( $fre, $n, $d ), () );

    foreach my $key ( sort keys %{$h} ) {
        my $value = $h->{$key};
        push @result, $value if $value;
    }

    return join ' ', @result;

}

sub setSchedulerMakeVerbose($$)

    # ------ arguments: $fre $refToScript
{

    my ( $fre, $r ) = @_;

    my $prefix           = FRETemplate::PRAGMA_PREFIX;
    my $schedulerOptions = FRETemplate::PRAGMA_SCHEDULER_MAKE_VERBOSE;
    my $placeholder      = qr/^[ \t]*$prefix[ \t]+$schedulerOptions[ \t]*$/mo;

    my $variableEnv           = $fre->property('FRE.scheduler.variable.environment');
    my $variableEnvValueBatch = $fre->property('FRE.scheduler.variable.environment.value.batch');
    my $makeVerbose           = '';

    $makeVerbose .= 'if ( $?' . $variableEnv . ' ) then' . "\n";
    $makeVerbose
        .= '  if ( $' . $variableEnv . ' == "' . $variableEnvValueBatch . '" ) then' . "\n";
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

} ## end sub setSchedulerMakeVerbose($$)

sub setVersionInfo($$$$%)

    # ------ arguments: $fre $refToScript $caller $expName %options
{

    my ( $fre, $r, $c, $n, %o ) = @_;

    my $prefix      = FRETemplate::PRAGMA_PREFIX;
    my $versionInfo = FRETemplate::PRAGMA_VERSION_INFO;
    my $placeholder = qr/^[ \t]*$prefix[ \t]+$versionInfo[ \t]*$/mo;

    my $configFileAbsPathName = $fre->configFileAbsPathName();

    $/ = "";
    chomp( my $createDate = qx(date +%Y-%m-%dT%H:%M:%S) );

    my $info = "# The script created at $createDate via:\n# $c";
    foreach my $key ( sort keys %o ) {
        my $value = ( $key eq 'xmlfile' ) ? $configFileAbsPathName : $o{$key};
        if ( $key eq 'ncores' ) {
            $info .= ' --' . $key . '=' . $value;
        }
        elsif ( $value eq '1' ) {
            $info .= ' --' . $key;
        }
        elsif ( $value ne '0' ) {
            $info .= ' --' . $key . '=' . $value;
        }
    }

    $info .= ' ' . $n;

    ${$r} =~ s/$placeholder/$info/;

} ## end sub setVersionInfo($$$$%)

sub setRunCommand($$$)

    # ------ arguments: $fre $refToScript $mpiInfo
{

    my ( $fre, $r, $mpiInfo ) = @_;
    my ( $cf, $np, $rp, $rt, $layout, $io_layout, $mask_table, $ranks_per_ens, $rt_res )
        = @{$mpiInfo}
        { qw( coupler npes npesList ntdsList layoutList ioLayoutList maskTableList ranksPerEnsList ntdsResList )
        };

    my $prefix         = FRETemplate::PRAGMA_PREFIX;
    my $runCommandSize = FRETemplate::PRAGMA_RUN_COMMAND_SIZE;
    my $placeholder    = qr/^[ \t]*$prefix[ \t]+$runCommandSize[ \t]*$/mo;

    # use a different launcher if there's more than one component with ranks
    my $runCommandLauncher = (grep({ $_ } @$rp) > 1)
                           ? $fre->property('FRE.mpi.runCommand.launcher.multi')
                           : $fre->property('FRE.mpi.runCommand.launcher.single');
    my @components = split( ';', $fre->property('FRE.mpi.component.names') );
    my ( $runCommand, $runSizeInfo ) = ( $runCommandLauncher, "  set -r npes = $np\n" );

    foreach my $inx ( 0 .. $#components ) {
        my $component = $components[$inx];
        $runSizeInfo .= "  set -r ${component}_ranks = $ranks_per_ens->[$inx]\n";
        $runSizeInfo .= "  set -r tot_${component}_ranks = $rp->[$inx]\n";
        $runSizeInfo .= "  set -r ${component}_threads = $rt->[$inx]\n";
        $runSizeInfo .= "  set -r ${component}_layout = $layout->[$inx]\n";
        $runSizeInfo .= "  set -r ${component}_io_layout = $io_layout->[$inx]\n";
        $runSizeInfo .= "  set -r ${component}_mask_table = $mask_table->[$inx]\n";
        # handle hyperthreading
        my $ht_flag = ($rt_res->[$inx] < $rt->[$inx]) ? '.true.' : '.false.';
        $runSizeInfo .= "  set -r ${component}_hyperthread = $ht_flag\n";
        $runSizeInfo .= "  set -r scheduler_${component}_threads = $rt_res->[$inx]\n";
        # set atm_(ny|ny)blocks to sensible values
        # if atm threads is unset or zero in the <resources> tag,
        #   FREExperiment:MPISizeParameters(Compatible|Generic) will set it to 1
        if ( $component eq 'atm' ) {
            $runSizeInfo .= "  set -r atm_nxblocks = 1\n";
            if (FRETargets::containsOpenMP( $fre->target() )) {
                $runSizeInfo .= sprintf "  set -r atm_nyblocks = %d\n", 2 * $rt->[$inx];
            }
            else {
                $runSizeInfo .= "  set -r atm_nyblocks = 1\n";
            }
        }
    }

    if ($cf) {
        foreach my $inx ( 0 .. $#components ) {
            my $component = $components[$inx];
            if ( $rp->[$inx] > 0 ) {
                $runCommand .= ' :' if $runCommand ne $runCommandLauncher;
                $runCommand .= ' '
                    . $fre->propertyParameterized( 'FRE.mpi.runCommand.option.mpiprocs',
                    '$' . 'tot_' . ${component} . '_ranks' );
                $runCommand .= ' '
                    . $fre->propertyParameterized( 'FRE.mpi.runCommand.option.nthreads',
                    '$scheduler_' . ${component} . '_threads' );
                $runCommand .= ' ' . $fre->property('FRE.mpi.runCommand.executable');
            }
        }
    }
    else {
        $runCommand .= ' '
            . $fre->propertyParameterized( 'FRE.mpi.runCommand.option.mpiprocs', '$npes' );
        $runCommand .= ' ' . $fre->propertyParameterized( 'FRE.mpi.runCommand.option.nthreads', 1 );
        $runCommand .= ' ' . $fre->property('FRE.mpi.runCommand.executable');
    }

    $fre->out( FREMsg::NOTE, "Running executable with:", $runCommand );
    FRETemplate::setAlias( $fre, $r, 'runCommand', $runCommand );
    ${$r} =~ s/$placeholder/$runSizeInfo/;

} ## end sub setRunCommand($$$)

sub setInputDatasets($$$)

    # ------ arguments: $fre $refToScript $refToDatasetsArray
{

    my ( $fre, $r, $d ) = @_;

    my $prefix                 = FRETemplate::PRAGMA_PREFIX;
    my $dataFiles              = FRETemplate::PRAGMA_DATAFILES;
    my $placeholderDataFiles   = qr/^[ \t]*$prefix[ \t]+$dataFiles[ \t]*$/mo;
    my $fmsDataSets            = FRETemplate::PRAGMA_FMSDATASETS;
    my $placeholderFMSDataSets = qr/^[ \t]*$prefix[ \t]+$fmsDataSets[ \t]*$/mo;

    my ( $csh, $dataSets, @results ) = ( '', '', @{$d} );

    while ( scalar(@results) > 0 ) {
        my $source = shift @results;
        my $target = shift @results;
        if ( $source =~ m/\// ) {
            my ( $cshSnippet, $status ) = $prepareInputFile->( $fre, $source, $target );
            if ($cshSnippet) {
                $csh .= $cshSnippet . "\n";
            }
            else {
                $fre->out( FREMsg::FATAL,
                    "The pathname '$source' can't be setup in the runscript" );
                return undef;
            }
        }
        else {
            $dataSets .= ' ' . $source;
        }
    }

    if ($dataSets) {
        $fre->out( FREMsg::WARNING,
            "The usage of 'get_fms_data' datasets is no longer supported - please list your input files explicitly in the XML file"
        );
        ${$r} =~ s/$placeholderFMSDataSets/get_fms_data$dataSets/;
    }
    else {
        ${$r} =~ s/$placeholderFMSDataSets//;
    }

    ${$r} =~ s/$placeholderDataFiles/$csh/;

    return 1;

} ## end sub setInputDatasets($$$)

sub setTable($$$$)

    # ------ arguments: $fre $refToScript $tableName $tableData
{

    my ( $fre, $r, $n, $d ) = @_;

    my $prefix       = FRETemplate::PRAGMA_PREFIX;
    my $genericTable = FRETemplate::PRAGMA_GENERIC_TABLE;
    my ( $placeholderPrefix, $placeholderSuffix )
        = ( qr/^([ \t]*)$prefix[ \t]+$genericTable[ \t]*\([ \t]*/mo, qr/[ \t]*\)[ \t]*$/mo );

    if ( ${$r} =~ m/$placeholderPrefix$n$placeholderSuffix/ ) {
        $d = "cat >> $n <<EOF\n$d\nEOF\n" if $d;
        substr( ${$r}, $-[0], $+[0] - $-[0] ) = $d;
    }

}

sub setNamelists($$$)

    # ------ arguments: $fre $refToScript $namelistsHandle
{

    my ( $fre, $r, $h ) = @_;

    my $prefix             = FRETemplate::PRAGMA_PREFIX;
    my $nmlAsFortranString = $h->asFortranString();

    $checkNamelists->( $fre, $h );

    {
        my $namelists   = FRETemplate::PRAGMA_NAMELISTS_EXPANDED;
        my $placeholder = qr/^[ \t]*$prefix[ \t]+$namelists[ \t]*$/mo;
        my $nmlString   = '';
        $nmlString .= 'cat > input.nml <<EOF' . "\n";
        $nmlString .= $nmlAsFortranString;
        $nmlString .= 'EOF' . "\n";
        ${$r} =~ s/$placeholder/$nmlString/;
    }

    {
        my $namelists   = FRETemplate::PRAGMA_NAMELISTS_UNEXPANDED;
        my $placeholder = qr/^[ \t]*$prefix[ \t]+$namelists[ \t]*$/mo;
        my $nmlString   = '';
        $nmlString .= 'cat > input.nml.unexpanded <<\EOF' . "\n";
        $nmlString .= $nmlAsFortranString;
        $nmlString .= '\EOF' . "\n";
        ${$r} =~ s/$placeholder/$nmlString/;
    }

} ## end sub setNamelists($$$)

sub setShellCommands($$$$)

    # ------ arguments: $fre $refToScript $destinationName $shellCommands
{

    my ( $fre, $r, $n, $d ) = @_;

    if ( my $anchor = $FRETemplatePragmaCsh{$n} ) {
        chomp($d);
        my $prefix      = FRETemplate::PRAGMA_PREFIX;
        my $placeholder = qr/^[ \t]*$prefix[ \t]+$anchor[ \t]*$/m;
        ${$r} =~ s/$placeholder/$d/;
    }

}

# //////////////////////////////////////////////////////////////////////////////
# //////////////////////////////////////////////////////////// Initialization //
# //////////////////////////////////////////////////////////////////////////////

return 1;
