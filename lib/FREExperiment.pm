#
# ------------------------------------------------------------------------------
# FMS/FRE Project: Experiment Management Module
# ------------------------------------------------------------------------------
# Copyright (C) NOAA Geophysical Fluid Dynamics Laboratory, 2009-2013, 2016
# Designed and written by V. Balaji, Amy Langenhorst, Aleksey Yakovlev and
# Seth Underwood
#

package FREExperiment;

use strict;

use List::Util();

use FREDefaults();
use FREMsg();
use FRENamelists();
use FRETargets();
use FREUtil();

# //////////////////////////////////////////////////////////////////////////////
# ////////////////////////////////////////////////////////// Global Constants //
# //////////////////////////////////////////////////////////////////////////////

use constant DIRECTORIES => FREDefaults::ExperimentDirs();
use constant REGRESSION_SUITE => ( 'basic', 'restarts', 'scaling' );

# //////////////////////////////////////////////////////////////////////////////
# ////////////////////////////////////////////////////////// Global Variables //
# //////////////////////////////////////////////////////////////////////////////

my %FREExperimentMap = ();

# //////////////////////////////////////////////////////////////////////////////
# ///////////////////////////////////////////////////////////////// Utilities //
# //////////////////////////////////////////////////////////////////////////////

my $experimentFind = sub($)

    # ------ arguments: $expName
{
    my $e = shift;
    return ( exists( $FREExperimentMap{$e} ) ) ? $FREExperimentMap{$e} : '';
};

my $experimentDirsCreate = sub($)

    # ------ arguments: $object
{
    my $r = shift;
    foreach my $t (FREExperiment::DIRECTORIES) {
        my $dirName = $t . 'Dir';
        $r->{$dirName} = $r->property($dirName);
    }
};

my $experimentDirsVerify = sub($$)

    # ------ arguments: $object $expName
{
    my ( $r, $e ) = @_;
    my $result = 1;
    my ( $fre, @expNamed ) = ( $r->fre(), split( ';', $r->property('FRE.directory.expNamed') ) );
    foreach my $t (FREExperiment::DIRECTORIES) {
        my $d = $r->{ $t . 'Dir' };
        if ($d) {

# --------------------------------------------- check presence of the experiment name in the directory
            if ( scalar( grep( $_ eq $t, @expNamed ) ) > 0 ) {
                unless ( FREUtil::dirContains( $d, $e ) > 0 ) {
                    $fre->out( FREMsg::FATAL,
                        "The '$t' directory ($d) doesn't contain the experiment name" );
                    $result = 0;
                    last;
                }
            }

# -------------------------------------------------------- check placement the directory on the filesystem
            my $pathsMapping = $r->property( 'FRE.directory.' . $t . '.paths.mapping' );
            if ($pathsMapping) {
                chomp( my @groupNames = split( /\s+/, qx(id -Gn) ) );
                my $paths = FREUtil::strFindByPattern( $pathsMapping, @groupNames );
                if ($paths) {
                    my $pathsForMatch = $paths;
                    $pathsForMatch =~ s/\$/\\\$/g;
                    if ( $d !~ m/^$pathsForMatch$/ ) {
                        my @paths = split( '\|', $paths );
                        my $pathsForOut = join( ', ', @paths );
                        $fre->out( FREMsg::FATAL,
                            "The '$t' directory ($d) can't be set up - it must be one of ($pathsForOut)"
                        );
                        $result = 0;
                        last;
                    }
                }
                else {
                    $fre->out( FREMsg::FATAL,
                        "The external property 'directory.$t.paths.mapping' is defined as '$pathsMapping' - this syntax is invalid"
                    );
                    $result = 0;
                    last;
                }
            } ## end if ($pathsMapping)
            else {
                my $roots = $r->property( 'FRE.directory.' . $t . '.roots' );
                if ($roots) {
                    my $rootsForMatch = $roots;
                    $rootsForMatch =~ s/\$/\\\$/g;
                    if ( scalar( grep( "$d/" =~ m/^$_\//, split( ';', $rootsForMatch ) ) ) == 0 ) {
                        my @roots = split( ';', $roots );
                        my $rootsForOut = join( ', ', @roots );
                        $fre->out( FREMsg::FATAL,
                            "The '$t' directory ($d) can't be set up - it must be on one of ($rootsForOut) filesystems"
                        );
                        $result = 0;
                        last;
                    }
                }
                else {
                    $fre->out( FREMsg::FATAL,
                        "The '$t' directory isn't bound by external properties" );
                    $result = 0;
                    last;
                }
            } ## end else [ if ($pathsMapping) ]
        } ## end if ($d)
        else {
            $fre->out( FREMsg::FATAL, "The '$t' directory is empty" );
            $result = 0;
            last;
        }
    } ## end foreach my $t (FREExperiment::DIRECTORIES)
    return $result;
};

my $experimentCreate;
$experimentCreate = sub($$$)

    # ------ arguments: $className $fre $expName
    # ------ create the experiment chain up to the root
{
    my ( $c, $fre, $e ) = @_;
    my $exp = $experimentFind->($e);
    if ( !$exp ) {
        my @experiments = $fre->experimentNames($e);
        if ( scalar( grep( $_ eq $e, @experiments ) ) > 0 ) {
            my $r = {};
            bless $r, $c;

            # ---------------------------- populate object fields
            $r->{fre}  = $fre;
            $r->{name} = $e;
            $r->{node} = $fre->experimentNode($e);

            # ---------------------------- Figure out whether experiment belongs in database or not
            my $publicMetadataNode = $fre->experimentNode($e)->findnodes('publicMetadata');
            if ($publicMetadataNode) {
                my $dbswitchValue = $fre->experimentNode($e)->findvalue('publicMetadata/@DBswitch');
                if ( !$dbswitchValue ) {

                    # The user took the time to create the publicMetadata tags,
                    # but they failed to set any DBswitch, so we're no assuming that they want the
                    # experiment in the database per discussions on 9/25/17.
                    $r->{MDBIswitch} = 1;
                }
                else {

                    # Now, let's check to see if they've set it to no!
                    if ( $dbswitchValue =~ /^(no|false|off)$/i ) {
                        $r->{MDBIswitch} = 0;
                    }
                    else {

                        # The DBswitch wasn't off|false|no, so Put all the things in Curator!
                        $r->{MDBIswitch} = 1;
                    }
                }
            } ## end if ($publicMetadataNode)
            else {

                # No publicMetadata no Curator
                $r->{MDBIswitch} = 0;
            }

            # ------------------------------------------------------ create and verify directories
            $experimentDirsCreate->($r);
            unless ( $experimentDirsVerify->( $r, $e ) ) {
                $fre->out( FREMsg::FATAL,
                    "The experiment '$e' can't be set up because of a problem with directories" );
                return '';
            }

# ------------------------------------------------------------- find and create the parent if needed
            my $expParentName = $r->experimentValue('@inherit');
            if ( $expParentName eq $e ) {
                $fre->out( FREMsg::FATAL, "The experiment '$e' cannot inherit itself" );
                return '';
            }
            elsif ($expParentName) {
                if ( scalar( grep( $_ eq $expParentName, @experiments ) ) > 0 ) {
                    $r->{parent} = $experimentCreate->( $c, $fre, $expParentName );
                }
                else {
                    $fre->out( FREMsg::FATAL,
                        "The experiment '$e' inherits from non-existent experiment '$expParentName'"
                    );
                    return '';
                }
            }
            else {
                $r->{parent} = '';
            }

       # ----------------------------------------------------------------------- save the experiment
            $FREExperimentMap{$e} = $r;

            # ----------------------------------------- return the newly created object handle
            return $r;
        } ## end if ( scalar( grep( $_ ...)))
        else {

            # ------------------------------------- experiment doesn't exist
            $fre->out( FREMsg::FATAL, "The experiment '$e' doesn't exist" );
            return '';
        }
    } ## end if ( !$exp )
    else {

        # ---------------- experiment exists: return it
        return $exp;
    }
};

my $strMergeWS = sub($)

    # ------ arguments: $string
    # ------ merge all the workspaces to a single space
{
    my $s = shift;
    $s =~ s/(?:^\s+|\s+$)//gso;
    $s =~ s/\s+/ /gso;
    return $s;
};

my $strRemoveWS = sub($)

    # ------ arguments: $string
    # ------ remove all the workspaces
{
    my $s = shift;
    $s =~ s/\s+//gso;
    return $s;
};

my $rankSet;
$rankSet = sub($$$)

    # ------ arguments: $refToComponentHash $refToComponent $depth
    # ------ recursively set and return the component rank
    # ------ return -1 if loop is found
{
    my ( $h, $c, $d ) = @_;
    if ( $d < scalar( keys %{$h} ) ) {
        my @requires = split( ' ', $c->{requires} );
        if ( scalar(@requires) > 0 ) {
            my $rank = 0;
            foreach my $required (@requires) {
                my $refReq = $h->{$required};
                my $rankReq
                    = ( defined( $refReq->{rank} ) )
                    ? $refReq->{rank}
                    : $rankSet->( $h, $refReq, $d + 1 );
                if ( $rankReq < 0 ) {
                    return -1;
                }
                elsif ( $rankReq > $rank ) {
                    $rank = $rankReq;
                }
            }
            $rank++;
            $c->{rank} = $rank;
            return $rank;
        }
        else {
            $c->{rank} = 0;
            return 0;
        }
    } ## end if ( $d < scalar( keys...))
    else {
        return -1;
    }
};

my $regressionLabels = sub($)

    # ------ arguments: $object
{
    my $r        = shift;
    my @regNodes = $r->extractNodes( 'runtime', 'regression' );
    my @labels   = map( $r->nodeValue( $_, '@label' ) || $r->nodeValue( $_, '@name' ), @regNodes );
    return grep( $_ ne "", @labels );
};

my $regressionRunNode = sub($$)

    # ------ arguments: $object $label
{
    my ( $r, $l ) = @_;
    my @regNodes
        = $r->extractNodes( 'runtime', 'regression[@label="' . $l . '" or @name="' . $l . '"]' );
    return ( scalar(@regNodes) == 1 ) ? $regNodes[0] : undef;
};

my $productionRunNode = sub($)

    # ------ arguments: $object
{
    my $r = shift;
    my @prdNodes = $r->extractNodes( 'runtime', 'production' );
    return ( scalar(@prdNodes) == 1 ) ? $prdNodes[0] : undef;
};

my $extractOverrideParams = sub($$$)

    # ------ arguments: $exp $mamelistsHandle $runNode
{

    my ( $r, $h, $n ) = @_;
    my $fre = $r->fre();

    my $res = $r->nodeValue( $n, '@overrideParams' );
    $res .= ';' if ( $res and $res !~ /.*;$/ );

    my $atmosLayout = $r->nodeValue( $n, '@atmos_layout' );
    if ($atmosLayout) {
        $res .= "bgrid_core_driver_nml:layout=$atmosLayout;"
            if $h->namelistExists('bgrid_core_driver_nml');
        $res .= "fv_core_nml:layout=$atmosLayout;" if $h->namelistExists('fv_core_nml');
        $fre->out(
            FREMsg::WARNING,
            "Usage of the 'atmos_layout' attribute is deprecated; instead, use",
            "<run overrideParams=\"fv_core_nml:layout=$atmosLayout\" ...>",
            "or <run overrideParams=\"bgrid_core_driver_nml:layout=$atmosLayout\" ...>"
        );
    }

    my $zetacLayout = $r->nodeValue( $n, '@zetac_layout' );
    if ($zetacLayout) {
        $res .= "zetac_layout_nml:layout=$zetacLayout;";
        $fre->out(
            FREMsg::WARNING,
            "Usage of the 'zetac_layout' attribute is deprecated; instead, use",
            "<run overrideParams=\"zetac_layout_nml:layout=$zetacLayout;namelist:var=val;...\" ...>"
        );
    }

    my $iceLayout = $r->nodeValue( $n, '@ice_layout' );
    if ($iceLayout) {
        $res .= "ice_model_nml:layout=$iceLayout;";
        $fre->out(
            FREMsg::WARNING,
            "Usage of the 'ice_layout' attribute is deprecated; instead, use",
            "<run overrideParams=\"ice_model_nml:layout=$iceLayout;namelist:var=val;...\" ...>"
        );
    }

    my $oceanLayout = $r->nodeValue( $n, '@ocean_layout' );
    if ($oceanLayout) {
        $res .= "ocean_model_nml:layout=$oceanLayout;";
        $fre->out(
            FREMsg::WARNING,
            "Usage of the 'ocean_layout' attribute is deprecated; instead, use",
            "<run overrideParams=\"ocean_model_nml:layout=$oceanLayout;namelist:var=val;...\" ...>"
        );
    }

    my $landLayout = $r->nodeValue( $n, '@land_layout' );
    if ($landLayout) {
        $res .= "land_model_nml:layout=$landLayout;";
        $fre->out(
            FREMsg::WARNING,
            "Usage of the 'land_layout' attribute is deprecated; instead, use",
            "<run overrideParams=\"land_model_nml:layout=$landLayout;namelist:var=val;...\" ...>"
        );
    }

    return $res;

};

my $overrideRegressionNamelists = sub($$$)

    # ------ arguments: $exp $namelistsHandle $runNode
{

    my ( $r, $h, $n ) = @_;
    my $fre = $r->fre();

    my $overrideTypeless = sub($$$) {
        my ( $l, $v, $x ) = @_;
        if ( $h->namelistExists($l) ) {
            $h->namelistTypelessPut( $l, $v, $x );
        }
        else {
            $h->namelistPut( $l, "\t$v = $x" );
        }
    };

    foreach my $nml ( split( ';', $extractOverrideParams->( $r, $h, $n ) ) ) {
        my ( $name, $var, $val ) = split( /[:=]/, $nml );
        $name =~ s/\s*//g;
        $var =~ s/\s*//g;
        unless ( $name and $var ) {
            $fre->out( FREMsg::WARNING, "Got an empty namelist in overrideParams" );
            next;
        }
        if ( $var =~ /(?:npes|nthreads|layout)$/ ) {
            $fre->out( FREMsg::FATAL,
                sprintf
                    "At XML line %s you attempted to override the $name namelist for parameter $var in experiment %s, regression run %s. Overrides for some parameters (*npes, *nthreads, or *layout) are no longer allowed; specify these in the <regression>/<run>/<resources> tag. See FRE Documentation at http://wiki.gfdl.noaa.gov/index.php/FRE_User_Documentation#Resource_specification",
                $n->line_number,
                $r->name,
                $n->parentNode->getAttribute('name')
            );
            exit FREDefaults::STATUS_COMMAND_GENERIC_PROBLEM;
        }
        $fre->out( FREMsg::NOTE, "overrideParams from xml: $name:$var=$val" );
        my $contentOld = $h->namelistGet($name);
        $fre->out( FREMsg::NOTE, "Original namelist: '$name'\n$contentOld" );
        $overrideTypeless->( $name, $var, $val );
        my $contentNew = $h->namelistGet($name);
        $fre->out( FREMsg::NOTE, "Overridden namelist: '$name'\n$contentNew" );
    } ## end foreach my $nml ( split( ';'...))

    return $h;

};

my $overrideProductionNamelists = sub($$)

    # ------ arguments: $object $namelistsHandle
{

    my ( $r, $h ) = @_;

    my $overrideLayout = sub($$) {
        my ( $l, $x ) = @_;
        if ( $h->namelistExists($l) ) {
            $h->namelistLayoutPut( $l, 'layout', $x );
        }
        else {
            $h->namelistPut( $l, "\tlayout = $x" );
        }
    };

    my $atmosLayout = $r->extractValue('runtime/production/peLayout/@atmos');
    $overrideLayout->( 'bgrid_core_driver_nml', $atmosLayout ) if $atmosLayout;
    $overrideLayout->( 'fv_core_nml',           $atmosLayout ) if $atmosLayout;

    my $zetacLayout = $r->extractValue('runtime/production/peLayout/@zetac');
    $overrideLayout->( 'zetacLayout_nml', $zetacLayout ) if $zetacLayout;

    my $iceLayout = $r->extractValue('runtime/production/peLayout/@ice');
    $overrideLayout->( 'ice_model_nml', $iceLayout ) if $iceLayout;

    my $oceanLayout = $r->extractValue('runtime/production/peLayout/@ocean');
    $overrideLayout->( 'ocean_model_nml', $oceanLayout ) if $oceanLayout;

    my $landLayout = $r->extractValue('runtime/production/peLayout/@land');
    $overrideLayout->( 'land_model_nml', $landLayout ) if $landLayout;

    return $h;

};

my $MPISizeCompatible = sub($$)

    # ------ arguments: $fre $namelistsHandle
{
    my ( $fre, $h ) = @_;
    my $compatible = 1;

    # only use enabled components for MPI use
    my @all_components = split( ';', $fre->property('FRE.mpi.component.names') );
    my @enabled        = split( ';', $fre->property('FRE.mpi.component.enabled') );
    my @enabled_components = map { $all_components[$_] } grep { $enabled[$_] } 0 .. $#enabled;
    my %long_names = _long_component_names($fre);

    # currently only atm and ocn are enabled so the generic MPI parameters function
    # will never be used
    my @compatibleComponents = ( 'atm', 'ocn' );

    foreach my $component (@enabled_components) {

        # loop thru non-compatible enabled components
        unless ( scalar( grep( $_ eq $component, @compatibleComponents ) ) > 0 ) {

            # if a non-compatible enabled component
            # (checking both normal 3-letter name and legacy/long name)
            # is found to be enabled in coupler, use the generic MPI parameters function
            if (defined( FRENamelists::namelistBooleanGet( $h, 'coupler_nml', "do_$component" ) )
                or defined(
                    FRENamelists::namelistBooleanGet(
                        $h, 'coupler_nml', "do_$long_names{$component}"
                    )
                )
                ) {
                $compatible = 0;
                last;
            }
        }
    } ## end foreach my $component (@enabled_components)
    return $compatible;
};

my $MPISizeParametersCompatible = sub($$$$$)

    # ------ arguments: $exp $resources $namelistsHandle $ensembleSize
{

    my ( $r, $resources, $h, $s ) = @_;
    my $n = $resources->{npes};

    my ( $fre, $concurrent ) = ( $r->fre(), $h->namelistBooleanGet( 'coupler_nml', 'concurrent' ) );
    $concurrent = 1 unless defined($concurrent);

    # With the hyperthreading changes this paragraph may be a problem.
    # During the HT checking (in getResourceRequests()) components with threads specified
    # are checked to verify they are 2+. The problem is if the threads are unspecified
    # for an active second component (one component must have ranks/threads specified)
    # and HT is enabled. In that case getResourceRequests() won't catch the threads=1
    # because it's defined here.
    my $atmosNP = $resources->{atm}->{ranks}   || 0;
    my $atmosNT = $resources->{atm}->{threads} || 1;
    my $oceanNP = $resources->{ocn}->{ranks}   || 0;
    my $oceanNT = $resources->{ocn}->{threads} || 1;

    if ( $atmosNP < 0 ) {
        $fre->out( FREMsg::FATAL,
            "Number '$atmosNP' of atmospheric MPI processes must be non-negative" );
        return undef;
    }
    elsif ( $atmosNP > $n ) {
        $fre->out( FREMsg::FATAL,
            "Number '$atmosNP' of atmospheric MPI processes must be less or equal than a total number '$n' of MPI processes"
        );
        return undef;
    }

    if ( $oceanNP < 0 ) {
        $fre->out( FREMsg::FATAL,
            "Number '$oceanNP' of oceanic MPI processes must be non-negative" );
        return undef;
    }
    elsif ( $oceanNP > $n ) {
        $fre->out( FREMsg::FATAL,
            "Number '$oceanNP' of oceanic MPI processes must be less or equal than a total number '$n' of MPI processes"
        );
        return undef;
    }

    if ( FRETargets::containsOpenMP( $fre->target() ) ) {
        my $coresPerNode = $fre->property('FRE.scheduler.run.coresPerJob.inc');
        if ( $atmosNT <= 0 ) {
            $fre->out( FREMsg::FATAL,
                "Number '$atmosNT' of atmospheric OpenMP threads must be positive" );
            return undef;
        }
        elsif ( $atmosNT > $coresPerNode ) {
            $fre->out( FREMsg::FATAL,
                "Number '$atmosNT' of atmospheric OpenMP threads must be less or equal than a number '$coresPerNode' of cores per node"
            );
            return undef;
        }
        if ( $oceanNT <= 0 ) {
            $fre->out( FREMsg::FATAL,
                "Number '$oceanNT' of oceanic OpenMP threads must be positive" );
            return undef;
        }
        elsif ( $oceanNT > $coresPerNode ) {
            $fre->out( FREMsg::FATAL,
                "Number '$oceanNT' of oceanic OpenMP threads must be less or equal than a number '$coresPerNode' of cores per node"
            );
            return undef;
        }
    } ## end if ( FRETargets::containsOpenMP...)

    if ( $atmosNP > 0 || $oceanNP > 0 ) {
        my $ok   = 1;
        my @npes = ();
        my @ntds = ( $atmosNT, $oceanNT );
        if ( $atmosNP < $n && $oceanNP == 0 ) {
            @npes = ($concurrent) ? ( $atmosNP * $s, ( $n - $atmosNP ) * $s ) : ( $n * $s, 0 );
        }
        elsif ( $atmosNP == 0 && $oceanNP < $n ) {
            @npes = ($concurrent) ? ( ( $n - $oceanNP ) * $s, $oceanNP * $s ) : ( $n * $s, 0 );
        }
        elsif ( $atmosNP == $n && $oceanNP == 0 ) {
            @npes = ( $atmosNP * $s, 0 );
        }
        elsif ( $atmosNP == 0 && $oceanNP == $n ) {
            @npes = ( 0, $oceanNP * $s );
        }
        elsif ( $atmosNP == $n || $oceanNP == $n ) {
            if ($concurrent) {
                $fre->out( FREMsg::FATAL,
                    "Concurrent run - total number '$n' of MPI processes is equal to '$atmosNP' atmospheric ones OR to '$oceanNP' oceanic ones"
                );
                $ok = 0;
            }
            else {
                @npes = ( $n * $s, 0 );
            }
        }
        elsif ( $atmosNP + $oceanNP == $n ) {
            @npes = ( $atmosNP * $s, $oceanNP * $s );
        }
        else {
            $fre->out( FREMsg::FATAL,
                "Total number '$n' of MPI processes isn't equal to the sum of '$atmosNP' atmospheric and '$oceanNP' oceanic ones"
            );
            $ok = 0;
        }
        return ($ok)
            ? { npes => $n * $s, coupler => 1, npesList => \@npes, ntdsList => \@ntds }
            : undef;
    } ## end if ( $atmosNP > 0 || $oceanNP...)
    else {
        return { npes => $n * $s };
    }

};

my $MPISizeComponentEnabled = sub($$$)

    # ------ arguments: $exp $namelistsHandle $componentName
{
    my ( $r, $h, $n ) = @_;
    my ( $fre, $result ) = ( $r->fre(), undef );
    my @subComponents = split( ';', $fre->property("FRE.mpi.$n.subComponents") );
    my %long_component_names = _long_component_names($fre);

    # check component name (e.g. atm) and legacy long name (e.g. atmos)
    foreach my $component ( $n, $long_component_names{$n}, @subComponents ) {
        my $enabled = $h->namelistBooleanGet( 'coupler_nml', "do_$component" );
        if ( defined($enabled) ) {
            if ($enabled) {
                $result = 1;
                last;
            }
            elsif ( !defined($result) ) {
                $result = 0;
            }
        }
    }
    return $result;
};

# Returns a hash whose keys are the 3-letter standard component names
# and value is the legacy/long name. The only use for the long names is
# do_atmos = 1 style coupler namelist entries
sub _long_component_names {
    my $fre   = shift;
    my @short = split ';', $fre->property('FRE.mpi.component.names');
    my @long  = split ';', $fre->property('FRE.mpi.component.long_names');
    my %hash;
    $hash{ $short[$_] } = $long[$_] for 0 .. $#short;
    return %hash;
}

my $MPISizeParametersGeneric = sub($$$$)

    # ------ arguments: $exp $resources $namelistsHandle $ensembleSize
{
    my ( $r, $resources, $h, $s ) = @_;
    my $n             = $resources->{npes};
    my $pairSplit     = sub($) { return split( '<', shift ) };
    my $pairJoin      = sub($$) { return join( '<', @_ ) };
    my $fre           = $r->fre();
    my %sizes         = ();
    my @enabled       = split( ';', $fre->property('FRE.mpi.component.enabled') );
    my @components    = split( ';', $fre->property('FRE.mpi.component.names') );
    my $openMPEnabled = FRETargets::containsOpenMP( $fre->target() );
    my $coresPerNode
        = ($openMPEnabled) ? $fre->property('FRE.scheduler.run.coresPerJob.inc') : undef;

# ------------------------------------------------------------------------- determine component sizes
    for ( my $inx = 0; $inx < scalar(@components); $inx++ ) {
        my $component = $components[$inx];
        my $enabled = $MPISizeComponentEnabled->( $r, $h, $component );

        # use the fre.properties enabled flag if the coupler_nml value is undefined
        # or if the coupler_nml value is yes and the fre.properties value is no
        $enabled = $enabled[$inx] if !defined($enabled) or $enabled && !$enabled[$inx];
        if ($enabled) {
            if ( my $npes = $resources->{$component}->{ranks} ) {
                $sizes{"${component}_npes"} = $npes * $s;
                if ($openMPEnabled) {
                    my $ntds = $resources->{$component}->{threads};
                    unless ( defined($ntds) ) {
                        $sizes{"${component}_ntds"} = 1;
                    }
                    elsif ( 0 < $ntds && $ntds <= $coresPerNode ) {
                        $sizes{"${component}_ntds"} = $ntds;
                    }
                    elsif ( $ntds <= 0 ) {
                        $fre->out( FREMsg::FATAL,
                            "The component $component must request a positive number of threads" );
                        return undef;
                    }
                    else {
                        $fre->out( FREMsg::FATAL,
                            "The component $component's thread request ($ntds) must be less or equal than a number '$coresPerNode' of cores per node"
                        );
                        return undef;
                    }
                } ## end if ($openMPEnabled)
                else {
                    $sizes{"${component}_ntds"} = 1;
                }
            } ## end if ( my $npes = $resources...)
            else {
                $fre->out( FREMsg::FATAL,
                    "The component $component must request a positive number of ranks" );
                return undef;
            }
        } ## end if ($enabled)
        else {
            $sizes{"${component}_npes"} = 0;
            $sizes{"${component}_ntds"} = 1;
        }
    } ## end for ( my $inx = 0; $inx...)

# --------------------------------------------------- select enabled components (with positive sizes)
    if ( my @componentsEnabled = grep( $sizes{"${_}_npes"} > 0, @components ) ) {
        my %pairs = ();
        my @pairsAllowed = split( ';', $fre->property('FRE.mpi.component.serials') );

       # -------------------------------- determine components pairing (for enabled components only)
        foreach my $componentL (@componentsEnabled) {
            foreach my $componentR (@componentsEnabled) {
                if ( $h->namelistBooleanGet( 'coupler_nml', "serial_${componentL}_${componentR}" ) )
                {
                    my $pairCurrent = $pairJoin->( $componentL, $componentR );
                    if ( grep( $_ eq $pairCurrent, @pairsAllowed ) ) {
                        my $componentLExtra = undef;
                        foreach my $pair ( keys %pairs ) {
                            my ( $componentLExisting, $componentRExisting ) = $pairSplit->($pair);
                            $componentLExtra = $componentLExisting
                                if $componentRExisting eq $componentR;
                        }
                        unless ($componentLExtra) {
                            $pairs{$pairCurrent} = 1;
                        }
                        else {
                            $fre->out( FREMsg::FATAL,
                                "Components '$componentL' and '$componentR' can't be run serially - the '$componentLExtra' and '$componentR' are already configured to run serially"
                            );
                            return undef;
                        }
                    }
                    else {
                        $fre->out( FREMsg::FATAL,
                            "Components '$componentL' and '$componentR' aren't allowed to run serially"
                        );
                        return undef;
                    }
                } ## end if ( $h->namelistBooleanGet...)
            } ## end foreach my $componentR (@componentsEnabled)
        } ## end foreach my $componentL (@componentsEnabled)

 # ----------------------------------------------- modify component sizes according to their pairing
        while ( my @pairs = keys %pairs ) {
            my @pairComponentsL = map( ( $pairSplit->($_) )[0], @pairs );
            foreach my $pair (@pairs) {
                my ( $componentL, $componentR ) = $pairSplit->($pair);
                unless ( grep( $_ eq $componentR, @pairComponentsL ) ) {
                    $sizes{"${componentL}_npes"} = List::Util::max( $sizes{"${componentL}_npes"},
                        $sizes{"${componentR}_npes"} );
                    $sizes{"${componentL}_ntds"} = List::Util::max( $sizes{"${componentL}_ntds"},
                        $sizes{"${componentR}_ntds"} );
                    $sizes{"${componentR}_npes"} = 0;
                    delete $pairs{$pair};
                }
            }
        }

        # ----------------------------------------------- normal return
        my @npes = map( $sizes{"${_}_npes"}, @components );
        my @ntds = map( $sizes{"${_}_ntds"}, @components );
        return { npes => $n * $s, coupler => 1, npesList => \@npes, ntdsList => \@ntds };
    } ## end if ( my @componentsEnabled...)
    else {
        my $componentsForOut = join( ', ', @components );
        $fre->out( FREMsg::FATAL,
            "At least one of the components '$componentsForOut' must be configured to run" );
        return undef;
    }
};

my $MPISizeParameters = sub($$$)

    # ------ arguments: $exp $resources $namelistsHandle
{

    my ( $r, $resources, $h ) = @_;
    my $fre = $r->fre();
    my $n   = $resources->{npes};

    my $ensembleSize = $h->namelistIntegerGet( 'ensemble_nml', 'ensemble_size' );
    $ensembleSize = 1 unless defined($ensembleSize);

    if ( $ensembleSize > 0 ) {
        if ( $h->namelistExists('coupler_nml') ) {
            my $func
                = ( $MPISizeCompatible->( $fre, $h ) )
                ? $MPISizeParametersCompatible
                : $MPISizeParametersGeneric;
            return $func->( $r, $resources, $h, $ensembleSize );
        }
        elsif ( $n > 0 ) {
            return { npes => $n * $ensembleSize };
        }
        else {
            $fre->out( FREMsg::FATAL,
                "The <production> or <regression/run> attribute 'npes' must be defined and have a positive value"
            );
            return undef;
        }
    }
    else {
        $fre->out( FREMsg::FATAL,
            "The variable 'ensemble_nml:ensemble_size' must have a positive value" );
        return undef;
    }

};

my $regressionPostfix = sub($$$$$$$$$)

# ------ arguments: $exp $label $runNo $hoursFlag $segmentsNmb $monthsNmb $daysNmb $hoursNmb $mpiInfo
{
    my ( $r, $l, $i, $hf, $sn, $mn, $dn, $hn, $h ) = @_;
    my ( $fre, $timing, $size ) = ( $r->fre(), $sn . 'x' . $mn . 'm' . $dn . 'd', '' );
    $timing .= $hn . 'h' if $hf;
    if ( $h->{coupler} ) {
        my ( $refNPes, $refNTds ) = ( $h->{npesList}, $h->{ntdsList} );
        my @suffixes = split( ';', $fre->property('FRE.mpi.component.suffixes') );
        for ( my $inx = 0; $inx < scalar( @{$refNPes} ); $inx++ ) {
            $size .= '_' . $refNPes->[$inx] . 'x' . $refNTds->[$inx] . $suffixes[$inx]
                if $refNPes->[$inx] > 0;
        }
    }
    else {
        $size = '_' . $h->{npes} . 'pe';
    }
    return $timing . $size;
};

# //////////////////////////////////////////////////////////////////////////////
# ////////////////////////////////////////// Class initialization/termination //
# //////////////////////////////////////////////////////////////////////////////

sub new($$$)

    # ------ arguments: $className $fre $expName
    # ------ called as class method
    # ------ creates an object and populates it
{
    my ( $c, $fre, $e ) = @_;
    return $experimentCreate->( $c, $fre, $e );
}

sub DESTROY

    # ------ arguments: $object
    # ------ called automatically
{
}

# //////////////////////////////////////////////////////////////////////////////
# //////////////////////////////////////////////////////////// Object methods //
# //////////////////////////////////////////////////////////////////////////////

sub fre($)

    # ------ arguments: $object
    # ------ called as object method
{
    my $r = shift;
    return $r->{fre};
}

sub name($)

    # ------ arguments: $object
    # ------ called as object method
{
    my $r = shift;
    return $r->{name};
}

sub node($)

    # ------ arguments: $object
    # ------ called as object method
{
    my $r = shift;
    return $r->{node};
}

sub parent($)

    # ------ arguments: $object
    # ------ called as object method
{
    my $r = shift;
    return $r->{parent};
}

sub dir($$)

    # ------ arguments: $object $dirType
    # ------ called as object method
{
    my ( $r, $t ) = @_;
    return $r->{ $t . 'Dir' };
}

sub rootDir($)

    # ------ arguments: $object
    # ------ called as object method
{
    my $r = shift;
    return $r->dir('root');
}

sub srcDir($)

    # ------ arguments: $object
    # ------ called as object method
{
    my $r = shift;
    return $r->dir('src');
}

sub execDir($)

    # ------ arguments: $object
    # ------ called as object method
{
    my $r = shift;
    return $r->dir('exec');
}

sub scriptsDir($)

    # ------ arguments: $object
    # ------ called as object method
{
    my $r = shift;
    return $r->dir('scripts');
}

sub stdoutDir($)

    # ------ arguments: $object
    # ------ called as object method
{
    my $r = shift;
    return $r->dir('stdout');
}

sub stdoutTmpDir($)

    # ------ arguments: $object
    # ------ called as object method
{
    my $r = shift;
    return $r->dir('stdoutTmp');
}

sub stateDir($)

    # ------ arguments: $object
    # ------ called as object method
{
    my $r = shift;
    return $r->dir('state');
}

sub workDir($)

    # ------ arguments: $object
    # ------ called as object method
{
    my $r = shift;
    return $r->dir('work');
}

sub ptmpDir($)

    # ------ arguments: $object
    # ------ called as object method
{
    my $r = shift;
    return $r->dir('ptmp');
}

sub archiveDir($)

    # ------ arguments: $object
    # ------ called as object method
{
    my $r = shift;
    return $r->dir('archive');
}

sub postProcessDir($)

    # ------ arguments: $object
    # ------ called as object method
{
    my $r = shift;
    return $r->dir('postProcess');
}

sub analysisDir($)

    # ------ arguments: $object
    # ------ called as object method
{
    my $r = shift;
    return $r->dir('analysis');
}

sub includeDir($)

    # ------ arguments: $object
    # ------ called as object method
{
    my $r = shift;
    return $r->dir('include');
}

sub placeholdersExpand($$)

    # ------ arguments: $object $string
    # ------ called as object method
    # ------ expand all the experiment level placeholders in the given $string
{
    my ( $r, $s ) = @_;
    if ( index( $s, '$' ) >= 0 ) {
        my $v = $r->{name};
        $s =~ s/\$(?:\(name\)|\{name\}|name)/$v/g;
    }
    return $s;
}

sub property($$)

    # ------ arguments: $object $propertyName
    # ------ called as object method
    # ------ return the value of the property $propertyName, expanded on the experiment level
{
    my ( $r, $k ) = @_;
    return $r->placeholdersExpand( $r->fre()->property($k) );
}

sub nodeValue($$$)

    # ------ arguments: $object $node $xPath
    # ------ called as object method
    # ------ return $xPath value relative to the given $node
{
    my ( $r, $n, $x ) = @_;
    return $r->placeholdersExpand( $r->fre()->nodeValue( $n, $x ) );
}

sub experimentValue($$)

    # ------ arguments: $object $xPath
    # ------ called as object method
    # ------ return $xPath value relative to the experiment node
{
    my ( $r, $x ) = @_;
    return $r->nodeValue( $r->node(), $x );
}

sub description($)

    # ------ arguments: $object
    # ------ called as object method
    # ------ returns the experiment description
{
    my $r = shift;
    return $r->experimentValue('description');
}

sub executable($)

    # ------ arguments: $object
    # ------ called as object method
    # ------ return standard executable name for the given experiment
{
    my $r = shift;
    my ( $execDir, $name ) = ( $r->execDir(), $r->name() );
    return "$execDir/fms_$name.x";
}

sub executableCanBeBuilt($)

    # ------ arguments: $object
    # ------ called as object method
    # ------ return 1 if the executable for the given experiment can be built
{
    my $r = shift;
    return (   $r->experimentValue('*/source/codeBase') ne ''
            || $r->experimentValue('*/source/csh') ne ''
            || $r->experimentValue('*/compile/cppDefs') ne ''
            || $r->experimentValue('*/compile/srcList') ne ''
            || $r->experimentValue('*/compile/pathNames') ne ''
            || $r->experimentValue('*/compile/csh') ne '' );
}

# //////////////////////////////////////////////////////////////////////////////
# ////////////////////////////////////////// Data Extraction With Inheritance //
# //////////////////////////////////////////////////////////////////////////////

sub extractNodes($$$)

    # ------ arguments: $object $xPathRoot $xPathChildren
    # ------ called as object method
    # ------ return a nodes list corresponding to the $xPathRoot/$xPathChildren, following inherits
    # ------ if xPathRoot returns a list of nodes, only the first node will be taken into account
{
    my ( $r, $x, $y ) = @_;
    my ( $exp, @results ) = ( $r, () );
    while ( $exp and scalar(@results) == 0 ) {
        my $rootNode = $exp->node()->findnodes($x)->get_node(1);
        push @results, $rootNode->findnodes($y) if $rootNode;
        $exp = $exp->parent();
    }
    return @results;
}

sub extractValue($$)

    # ------ arguments: $object $xPath
    # ------ called as object method
    # ------ return a value corresponding to the $xPath, following inherits
{
    my ( $r, $x ) = @_;
    my ( $exp, $value ) = ( $r, '' );
    while ( $exp and !$value ) {
        $value = $exp->experimentValue($x);
        $exp   = $exp->parent();
    }
    return $value;
}

sub extractComponentValue($$$)

  # ------ arguments: $object $xPath $componentName
  # ------ called as object method
  # ------ return a value corresponding to the $xPath under the <component> node, following inherits
{
    my ( $r, $x, $c ) = @_;
    my ( $exp, $value ) = ( $r, '' );
    while ( $exp and !$value ) {
        $value = $exp->experimentValue( 'component[@name="' . $c . '"]/' . $x );
        $exp   = $exp->parent();
    }
    return $value;
}

sub extractSourceValue($$$)

# ------ arguments: $object $xPath $componentName
# ------ called as object method
# ------ return a value corresponding to the $xPath under the <component/source> node, following inherits
{
    my ( $r, $x, $c ) = @_;
    my ( $exp, $value ) = ( $r, '' );
    while ( $exp and !$value ) {
        $value = $exp->experimentValue( 'component[@name="' . $c . '"]/source/' . $x );
        $exp   = $exp->parent();
    }
    return $value;
}

sub extractCompileValue($$$)

# ------ arguments: $object $xPath $componentName
# ------ called as object method
# ------ return a value corresponding to the $xPath under the <component/compile> node, following inherits
{
    my ( $r, $x, $c ) = @_;
    my ( $exp, $value ) = ( $r, '' );
    while ( $exp and !$value ) {
        $value = $exp->experimentValue( 'component[@name="' . $c . '"]/compile/' . $x );
        $exp   = $exp->parent();
    }
    return $value;
}

sub extractDoF90Cpp($$)

# ------ arguments: $object $xPath $componentName
# ------ called as object method
# ------ return a value corresponding to the $xPath under the <component/compile> node, following inherits
{
    my ( $r, $c ) = @_;
    my ( $exp, $value ) = ( $r, '' );
    my $compileNodes = $exp->node()->findnodes( 'component[@name="' . $c . '"]/compile' );
    return '' unless $compileNodes;
    my $compileNode = $compileNodes->get_node(1);
    while ( $exp and !$value ) {
        $value = $exp->nodeValue( $compileNode, '@doF90Cpp' );
        $exp = $exp->parent();
    }
    if ( $value !~ /(?i:yes|on|true)/ ) {
        $value = '';
    }
    return $value;
}

sub extractExecutable($)

    # ------ arguments: $object
    # ------ called as object method
    # ------ return predefined executable name (if found) and experiment object, following inherits
{

    my $r = shift;
    my ( $exp, $fre, $makeSenseToCompile, @results ) = ( $r, $r->fre(), undef, () );

    while ($exp) {
        $makeSenseToCompile = $exp->executableCanBeBuilt();
        @results = $fre->dataFilesMerged( $exp->node(), 'executable', 'file' );
        last if scalar(@results) > 0 || $makeSenseToCompile;
        $exp = $exp->parent();
    }

    if ( scalar(@results) > 0 ) {
        $fre->out( FREMsg::WARNING,
            "The executable name is predefined more than once - all the extra definitions are ignored"
        ) if scalar(@results) > 1;
        return ( @results[0], $exp );
    }
    elsif ($makeSenseToCompile) {
        return ( undef, $exp );
    }
    else {
        return ( undef, undef );
    }

} ## end sub extractExecutable($)

sub extractMkmfTemplate($$)

    # ------ arguments: $object $componentName
    # ------ called as object method
    # ------ extracts a mkmf template, following inherits
{

    my ( $r, $c ) = @_;
    my ( $exp, $fre, @results ) = ( $r, $r->fre(), () );

    while ( $exp and scalar(@results) == 0 ) {
        my @nodes = $exp->node()->findnodes( 'component[@name="' . $c . '"]/compile' );
        foreach my $node (@nodes) {
            push @results, $fre->dataFilesMerged( $node, 'mkmfTemplate', 'file' );
        }
        $exp = $exp->parent();
    }

    $fre->out( FREMsg::WARNING,
        "The '$c' component mkmf template is defined more than once - all the extra definitions are ignored"
    ) if scalar(@results) > 1;
    return @results[0];

}

sub extractDatasets($)

    # ------ arguments: $object
    # ------ called as object method
    # ------ extracts file pathnames together with their target names, following inherits
{

    my $r = shift;
    my ( $exp, $fre, @results ) = ( $r, $r->fre(), () );

    while ( $exp and scalar(@results) == 0 ) {

        # --------------------------------------------- get the input node
        my $inputNode = $exp->node()->findnodes('input')->get_node(1);

        # ------------------------------------------------ process the input node
        if ($inputNode) {

            # ----------------------------------------------------- get <dataFile> nodes
            push @results, $fre->dataFiles( $inputNode, 'input' );

            # ----------------------------------------------------- get nodes in the old format
            my @nodesForCompatibility = $inputNode->findnodes('fmsDataSets');
            foreach my $node (@nodesForCompatibility) {
                my $sources = $exp->nodeValue( $node, 'text()' );
                my @sources = split( /\s+/, $sources );
                foreach my $line (@sources) {
                    next unless $line;
                    if ( substr( $line, 0, 1 ) eq '/' ) {
                        my @lineParts = split( '=', $line );
                        if ( scalar(@lineParts) > 2 ) {
                            $fre->out( FREMsg::WARNING,
                                "Too many names for renaming are defined at '$line' - all the extra names are ignored"
                            );
                        }
                        my ( $source, $target ) = @lineParts;
                        if ($target) {
                            $target = 'INPUT/' . $target;
                        }
                        else {
                            $target = FREUtil::fileIsArchive($source) ? 'INPUT/' : 'INPUT/.';
                        }
                        push @results, $source;
                        push @results, $target;
                    }
                    else {
                        push @results, $line;
                        push @results, '';
                    }
                } ## end foreach my $line (@sources)
            } ## end foreach my $node (@nodesForCompatibility)
        } ## end if ($inputNode)

        # ---------------------------- repeat for the parent
        $exp = $exp->parent();
    } ## end while ( $exp and scalar(@results...))

    return @results;

} ## end sub extractDatasets($)

sub extractNamelists($)

    # ------ arguments: $object
    # ------ called as object method
    # ------ following inherits, but doesn't overwrite existing hash entries
    # ------ returns namelists handle
{

    my $r = shift;
    my ( $exp, $fre, $nmls ) = ( $r, $r->fre(), FRENamelists->new() );

    my $clean_inline_namelist_content = sub {
        my $content = shift;
        for ($content) {
            s/^\s*$//mg;
            s/^\n//;
            s/\s*(?:\/\s*)?$//;
        }
        return $content;
    };

    my $split_file_into_namelists = sub {
        my $filePath = shift;
        my $content  = qx(cat $filePath);
        $content =~ s/^\s*$//mg;
        $content =~ s/^\s*#.*$//mg;
        $content = $fre->placeholdersExpand($content);
        $content = $exp->placeholdersExpand($content);
        return split /\/\s*$/m, $content;
    };

    $fre->out( FREMsg::NOTE, "Extracting namelists..." );

    my $exp_count = 0;
    while ($exp) {

        # -------------------------------------------- get the input node
        my $inputNode = $exp->node()->findnodes('input')->get_node(1);

        # ------------------------------------------------ process the input node
        if ($inputNode) {

            # ----------------------------------- handle override namelists
            my @overrideNmlNodes = grep { $_->getAttribute('override') =~ /(?:yes|on|true)/i }
                $inputNode->findnodes('namelist[@name and @override]');

            # If child experiment, apply the override
            if ( $exp_count == 0 ) {
                for my $overrideNmlNode (@overrideNmlNodes) {
                    my $namelist_name
                        = FREUtil::cleanstr( $exp->nodeValue( $overrideNmlNode, '@name' ) );

                    # Get the child namelist
                    my $child_namelist_content = $clean_inline_namelist_content->(
                        $exp->nodeValue( $overrideNmlNode, 'text()' ) );
                    $fre->out( FREMsg::NOTE,
                        "Namelist override for $namelist_name, child settings:" );
                    $fre->out( FREMsg::NOTE, "\n$child_namelist_content" );

                    # Get the base namelist
                    my $base_namelist_content;
                    my $e = $exp->parent;
                GET_BASE_NAMELIST:
                    while ($e) {
                        if ( my $node = $e->node()->findnodes('input')->get_node(1) ) {

                            # Check for inline namelists first
                            if ( my $nml
                                = $node->findnodes("namelist[\@name='$namelist_name']")->get_node(1)
                                ) {
                                $base_namelist_content = $clean_inline_namelist_content->(
                                    $e->nodeValue( $nml, 'text()' ) );
                                last GET_BASE_NAMELIST;
                            }

                            # Then external namelists
                            else {

                             # Main namelist parsing code returns error if any nmlFiles don't exist,
                             # so just filter out the missing ones here for simplicity
                                for my $filePath ( grep { -f and -r }
                                    $fre->dataFilesMerged( $node, 'namelist', 'file' ) ) {
                                    for my $fileNml ( $split_file_into_namelists->($filePath) ) {
                                        $fileNml =~ s/^\s*\&//;
                                        $fileNml =~ s/\s*(?:\/\s*)?$//;
                                        my ( $name, $content ) = split( '\s', $fileNml, 2 );
                                        if ( $name eq $namelist_name ) {
                                            $base_namelist_content = $content;
                                            last GET_BASE_NAMELIST;
                                        }
                                    }
                                }
                            }
                        } ## end if ( my $node = $e->node...)
                        $e = $e->parent();
                    } ## end GET_BASE_NAMELIST: while ($e)
                    if ($base_namelist_content) {
                        $fre->out( FREMsg::NOTE,
                            "Namelist override for $namelist_name, base settings:" );
                        $fre->out( FREMsg::NOTE, "\n$base_namelist_content" );
                    }
                    else {
                        $fre->out( FREMsg::NOTE,
                            "Namelist override for $namelist_name, base settings: none" );
                    }

                    # Combine the namelists
                    my $combined_namelist_content
                        = FRENamelists::mergeNamelistContent( $base_namelist_content,
                        $child_namelist_content );
                    $fre->out( FREMsg::NOTE,
                        "Namelist override for $namelist_name, combined settings:" );
                    $fre->out( FREMsg::NOTE, "\n$combined_namelist_content" );
                    $nmls->namelistPut( $namelist_name, $combined_namelist_content );
                } ## end for my $overrideNmlNode...
            } ## end if ( $exp_count == 0 )

            # If ancestor experiment, search for overrides and die if found
            else {
                if (@overrideNmlNodes) {
                    $fre->out( FREMsg::FATAL,
                        sprintf
                            "Ancestor experiments not allowed to have namelist overrides; %s offending namelists:\n",
                        scalar @overrideNmlNodes
                    );
                    for my $nml (@overrideNmlNodes) {
                        $fre->out( FREMsg::FATAL, $nml->toString );
                    }
                    return undef;
                }
            }

            # ----------------------------------- get inline namelists (they take precedence)
            my @inlineNmlNodes = $inputNode->findnodes('namelist[@name]');
            foreach my $inlineNmlNode (@inlineNmlNodes) {
                my $name = FREUtil::cleanstr( $exp->nodeValue( $inlineNmlNode, '@name' ) );
                my $content = $clean_inline_namelist_content->(
                    $exp->nodeValue( $inlineNmlNode, 'text()' ) );
                if ( $nmls->namelistExists($name) ) {
                    my $expName = $exp->name();
                    $fre->out( FREMsg::NOTE,
                        "Using secondary specification of '$name' rather than the original setting in '$expName'"
                    );
                }
                elsif ($name) {
                    $nmls->namelistPut( $name, $content );
                }
            }

          # --------------------------------------------------------------- get namelists from files
            my @nmlFiles = $fre->dataFilesMerged( $inputNode, 'namelist', 'file' );
            foreach my $filePath (@nmlFiles) {
                if ( -f $filePath and -r $filePath ) {
                    my @fileNmls = $split_file_into_namelists->($filePath);
                    foreach my $fileNml (@fileNmls) {
                        $fileNml =~ s/^\s*\&//;
                        $fileNml =~ s/\s*(?:\/\s*)?$//;
                        my ( $name, $content ) = split( '\s', $fileNml, 2 );
                        if ( $nmls->namelistExists($name) ) {
                            $fre->out( FREMsg::NOTE,
                                "Using secondary specification of '$name' rather than the original setting in '$filePath'"
                            );
                        }
                        elsif ($name) {
                            $nmls->namelistPut( $name, $content );
                        }
                    }
                }
                else {
                    return undef;
                }
            } ## end foreach my $filePath (@nmlFiles)
        } ## end if ($inputNode)

        # ---------------------------- repeat for the parent
        $exp = $exp->parent();
        ++$exp_count;
    } ## end while ($exp)

    return $nmls;

} ## end sub extractNamelists($)

sub extractTable($$)

    # ------ arguments: $object $label
    # ------ called as object method
    # ------ returns data, corresponding to the $label table, following inherits
{

    my ( $r, $l ) = @_;
    my ( $exp, $fre, $value ) = ( $r, $r->fre(), '' );

    # ------------------------------------------- get the input node
    my $inputNode = $exp->node()->findnodes('input')->get_node(1);

    # --------------------------------------------- process the input node
    if ($inputNode) {

        # ----------------- Find nodes that have the wrong @order attribute.
        my @inlineAppendTableNodes
            = $inputNode->findnodes( $l . '[@order and not(@order="append")]' );
        if (@inlineAppendTableNodes) {
            $fre->out( FREMsg::FATAL, "The value for attribute order in $l is not valid." );
            return undef;
        }

# ----------------- get inline tables except for "@order="append"" (they must be before tables from files and appended nodes)
        my @inlineTableNodes
            = $inputNode->findnodes( $l . '[not(@file) and not(@order="append")]' );
        foreach my $inlineTableNode (@inlineTableNodes) {
            $value .= $exp->nodeValue( $inlineTableNode, 'text()' );
        }

        # --------------------------------------------------------------- get tables from files
        my @tableFiles = $fre->dataFilesMerged( $inputNode, $l, 'file' );
        foreach my $filePath (@tableFiles) {
            if ( -f $filePath and -r $filePath ) {
                my $fileContent = qx(cat $filePath);
                $fileContent = $fre->placeholdersExpand($fileContent);
                $fileContent = $exp->placeholdersExpand($fileContent);
                $value .= $fileContent;
            }
            else {
                return undef;
            }
        }
    } ## end if ($inputNode)

    # ---------------------------- repeat for the parent
    if ( $exp->parent() and !$value ) {
        $value .= $exp->parent()->extractTable($l);
    }

    #  ---------------------------- now add appended tables
    if ($inputNode) {

        # ----------------- get [@order="append"] tables
        my @inlineAppendTableNodes = $inputNode->findnodes( $l . '[@order="append"]' );
        foreach my $inlineAppendTableNode (@inlineAppendTableNodes) {
            $value .= $exp->nodeValue( $inlineAppendTableNode, 'text()' );
        }
    }

    # ---------------------------- sanitize table
    $value =~ s/\n\s*\n/\n/sg;
    $value =~ s/^\s*\n\s*//s;
    $value =~ s/\s*\n\s*$//s;

    return $value;

} ## end sub extractTable($$)

sub extractShellCommands($$%)

    # ------ arguments: $object $xPath %adjustment
    # ------ called as object method
    # ------ returns shell commands, corresponding to the $xPath, following inherits
    # ------ adjusts commands, depending on node types
{

    my ( $r, $x, %a ) = @_;
    my ( $exp, $value ) = ( $r, '' );

    while ( $exp and !$value ) {
        my @nodes = $exp->node()->findnodes($x);
        foreach my $node (@nodes) {
            my $type    = $exp->nodeValue( $node, '@type' );
            my $content = $exp->nodeValue( $node, 'text()' );
            if ( exists( $a{$type} ) ) { $content = $a{$type}[0] . $content . $a{$type}[1]; }
            $value .= $content;
        }
        $exp = $exp->parent();
    }

    return $value;

}

sub extractVariableFile($$)

    # ------ arguments: $object $label
    # ------ called as object method
    # ------ returns filename for the $label variable, following inherits
{

    my ( $r, $l ) = @_;
    my ( $exp, $fre, @results ) = ( $r, $r->fre(), () );

    while ( $exp and scalar(@results) == 0 ) {
        my $inputNode = $exp->node()->findnodes('input')->get_node(1);
        push @results, $fre->dataFilesMerged( $inputNode, $l, 'file' ) if $inputNode;
        $exp = $exp->parent();
    }

    $fre->out( FREMsg::WARNING,
        "The variable '$l' is defined more than once - all the extra definitions are ignored" )
        if scalar(@results) > 1;
    return @results[0];

}

sub extractReferenceFiles($)

    # ------ arguments: $object
    # ------ called as object method
    # ------ return list of reference files, following inherits
{

    my $r = shift;
    my ( $exp, $fre, @results ) = ( $r, $r->fre(), () );

    while ( $exp and scalar(@results) == 0 ) {
        my $runTimeNode = $exp->node()->findnodes('runtime')->get_node(1);
        push @results, $fre->dataFilesMerged( $runTimeNode, 'reference', 'restart' )
            if $runTimeNode;
        $exp = $exp->parent();
    }

    return @results;

}

sub extractReferenceExperiments($)

    # ------ arguments: $object
    # ------ called as object method
    # ------ return list of reference experiment names, following inherits
{
    my ( $r, @results ) = ( shift, () );
    my @nodes = $r->extractNodes( 'runtime', 'reference/@experiment' );
    foreach my $node (@nodes) { push @results, $r->nodeValue( $node, '.' ); }
    return @results;
}

sub extractPPRefineDiagScripts($)

    # ------ arguments: $object
    # ------ called as object method
    # ------ return list of postprocessing refine diagnostics scriptnames, following inherits
{
    my ( $r, @results ) = ( shift, () );
    my @nodes = $r->extractNodes( 'postProcess', 'refineDiag/@script' );
    foreach my $node (@nodes) { push @results, split /\s+/, $r->nodeValue( $node, '.' ); }
    return @results;
}

sub extractCheckoutInfo($)

    # ------ arguments: $object
    # ------ called as object method
    # ------ return a reference to checkout info, following inherits
{

    my $r = shift;
    my ( $fre, $expName, @componentNodes )
        = ( $r->fre(), $r->name(), $r->node()->findnodes('component') );

    if ( scalar(@componentNodes) > 0 ) {
        my %components;
        foreach my $componentNode (@componentNodes) {
            my $name = $r->nodeValue( $componentNode, '@name' );
            if ($name) {
                $fre->out( FREMsg::NOTE, "COMPONENTLOOP ((($name)))" );
                if ( !exists( $components{$name} ) ) {

# ------------------------------------- get and check library data; skip the component if the library defined
                    my $libraryPath = $r->extractComponentValue( 'library/@path', $name );
                    if ($libraryPath) {
                        if ( -f $libraryPath ) {
                            my $libraryHeaderDir
                                = $r->extractComponentValue( 'library/@headerDir', $name );
                            if ($libraryHeaderDir) {
                                if ( -d $libraryHeaderDir ) {
                                    $fre->out( FREMsg::NOTE,
                                        "You have requested library '$libraryPath' for component '$name' - we will skip the component checkout"
                                    );
                                    next;
                                }
                                else {
                                    $fre->out( FREMsg::FATAL,
                                        "Component '$name' specifies non-existent library header directory '$libraryHeaderDir'"
                                    );
                                    return 0;
                                }
                            }
                            else {
                                $fre->out( FREMsg::FATAL,
                                    "Component '$name' specifies library '$libraryPath' but no header directory"
                                );
                                return 0;
                            }
                        } ## end if ( -f $libraryPath )
                        else {
                            $fre->out( FREMsg::FATAL,
                                "Component '$name' specifies non-existent library '$libraryPath'" );
                            return 0;
                        }
                    } ## end if ($libraryPath)

# ------------------------------------------------------------------------------- get and check component data for sources checkout
                    my $codeBase = $strMergeWS->( $r->extractSourceValue( 'codeBase', $name ) );
                    if ($codeBase) {
                        my $codeTag = $strRemoveWS->(
                            $r->extractSourceValue( 'codeBase/@version', $name ) );
                        if ($codeTag) {
                            my $vcBrand
                                = $strRemoveWS->(
                                $r->extractSourceValue( '@versionControl', $name ) )
                                || 'cvs';
                            if ($vcBrand) {
                                my $vcRoot
                                    = $strRemoveWS->( $r->extractSourceValue( '@root', $name ) )
                                    || $r->property('FRE.versioncontrol.cvs.root');
                                if ( $vcRoot =~ /:/ or ( -d $vcRoot and -r $vcRoot ) ) {

# ------------------------------------------------------------------------------------------ save component data into the hash
                                    my %component = ();
                                    $component{codeBase}   = $codeBase;
                                    $component{codeTag}    = $codeTag;
                                    $component{vcBrand}    = $vcBrand;
                                    $component{vcRoot}     = $vcRoot;
                                    $component{sourceCsh}  = $r->extractSourceValue( 'csh', $name );
                                    $component{lineNumber} = $componentNode->line_number();

# ----------------------------------------------------------------------------------------------- print what we got
                                    $fre->out(
                                        FREMsg::NOTE,
                                        "name           = $name",
                                        "codeBase       = $component{codeBase}",
                                        "codeTag        = $component{codeTag}",
                                        "vcBrand        = $component{vcBrand}",
                                        "vcRoot         = $component{vcRoot}",
                                        "sourceCsh      = $component{sourceCsh}"
                                    );

# -------------------------------------------------------------- link the component to the components hash
                                    $components{$name} = \%component;
                                } ## end if ( $vcRoot =~ /:/ or...)
                                else {
                                    $fre->out( FREMsg::FATAL,
                                        "Component '$name': the directory '$vcRoot' doesn't exist or not readable"
                                    );
                                    return 0;
                                }
                            } ## end if ($vcBrand)
                            else {
                                $fre->out( FREMsg::FATAL,
                                    "Component '$name': element <source> doesn't specify a version control system"
                                );
                                return 0;
                            }
                        } ## end if ($codeTag)
                        else {
                            $fre->out( FREMsg::FATAL,
                                "Component '$name': element <source> doesn't specify a version attribute for its code base"
                            );
                            return 0;
                        }
                    } ## end if ($codeBase)
                    else {
                        $fre->out( FREMsg::FATAL,
                            "Component '$name': element <source> doesn't specify a code base" );
                        return 0;
                    }
                } ## end if ( !exists( $components...))
                else {
                    $fre->out( FREMsg::FATAL,
                        "Component '$name' is defined more than once - make sure each component has a distinct name"
                    );
                    return 0;
                }
            } ## end if ($name)
            else {
                $fre->out( FREMsg::FATAL, "Components with empty names aren't allowed" );
                return 0;
            }
        } ## end foreach my $componentNode (...)
        return \%components;
    } ## end if ( scalar(@componentNodes...))
    else {
        $fre->out( FREMsg::FATAL, "The experiment '$expName' doesn't contain any components" );
        return 0;
    }

} ## end sub extractCheckoutInfo($)

sub extractCompileInfo($)

    # ------ arguments: $object
    # ------ called as object method
    # ------ return a reference to compile info
{

    my $r = shift;
    my ( $fre, $expName, @componentNodes )
        = ( $r->fre(), $r->name(), $r->node()->findnodes('component') );

    if ( scalar(@componentNodes) > 0 ) {
        my %components;
        foreach my $componentNode (@componentNodes) {

            # ----------------------------------------- get and check the component name
            my $name = $r->nodeValue( $componentNode, '@name' );
            if ($name) {
                $fre->out( FREMsg::NOTE, "COMPONENTLOOP: ((($name)))" );
                if ( !exists( $components{$name} ) ) {

      # ----------------------------------------------- get and check component data for compilation
                    my $paths = $strMergeWS->( $r->nodeValue( $componentNode, '@paths' ) );
                    if ($paths) {

# -------------------------------------------------------------------- get and check include directories
                        my $includeDirs
                            = $strMergeWS->( $r->extractComponentValue( '@includeDir', $name ) );
                        if ($includeDirs) {
                            foreach my $includeDir ( split( ' ', $includeDirs ) ) {
                                if ( !-d $includeDir ) {
                                    $fre->out( FREMsg::FATAL,
                                        "Component '$name' specifies non-existent include directory '$includeDir'"
                                    );
                                    return 0;
                                }
                            }
                        }

# --------------------------------------------- get and check library data; skip the component if the library defined
                        my $libPath
                            = $strRemoveWS->( $r->extractComponentValue( 'library/@path', $name ) );
                        my $libHeaderDir = $strRemoveWS->(
                            $r->extractComponentValue( 'library/@headerDir', $name ) );
                        if ($libPath) {
                            if ( -f $libPath ) {
                                if ($libHeaderDir) {
                                    if ( -d $libHeaderDir ) {
                                        $fre->out( FREMsg::NOTE,
                                            "You have requested library '$libPath' for component '$name': we will skip the component compilation"
                                        );
                                    }
                                    else {
                                        $fre->out( FREMsg::FATAL,
                                            "Component '$name' specifies non-existent library header directory '$libHeaderDir'"
                                        );
                                        return 0;
                                    }
                                }
                                else {
                                    $fre->out( FREMsg::FATAL,
                                        "Component '$name' specifies library '$libPath' but no header directory"
                                    );
                                    return 0;
                                }
                            } ## end if ( -f $libPath )
                            else {
                                $fre->out( FREMsg::FATAL,
                                    "Component '$name' specifies non-existent library '$libPath'" );
                                return 0;
                            }
                        } ## end if ($libPath)

# ----------------------------------------------------------------------------------- save component data into the hash
                        my %component = ();
                        $component{paths} = $paths;
                        $component{requires}
                            = $strMergeWS->( $r->nodeValue( $componentNode, '@requires' ) );
                        $component{includeDirs}  = $includeDirs;
                        $component{libPath}      = $libPath;
                        $component{libHeaderDir} = $libHeaderDir;
                        $component{srcList}
                            = $strMergeWS->( $r->extractCompileValue( 'srcList', $name ) );
                        $component{pathNames}
                            = $strMergeWS->( $r->extractCompileValue( 'pathNames/@file', $name ) );
                        $component{cppDefs} = FREUtil::strStripPaired(
                            $strMergeWS->( $r->extractCompileValue( 'cppDefs', $name ) ) );
                        $component{makeOverrides}
                            = $strMergeWS->( $r->extractCompileValue( 'makeOverrides', $name ) );
                        $component{compileCsh} = $r->extractCompileValue( 'csh', $name );
                        $component{mkmfTemplate} = $strRemoveWS->( $r->extractMkmfTemplate($name) )
                            || $fre->mkmfTemplate();
                        $component{doF90Cpp}   = $r->extractDoF90Cpp($name);
                        $component{lineNumber} = $componentNode->line_number();
                        $component{rank}       = undef;

# ------------------------------------------------------------------------------------------- print what we got
                        $fre->out(
                            FREMsg::NOTE,
                            "name            = $name",
                            "paths           = $component{paths}",
                            "requires        = $component{requires}",
                            "includeDir      = $component{includeDirs}",
                            "libPath         = $component{libPath}",
                            "libHeaderDir    = $component{libHeaderDir}",
                            "srcList         = $component{srcList}",
                            "pathNames       = $component{pathNames}",
                            "cppDefs         = $component{cppDefs}",
                            "makeOverrides   = $component{makeOverrides}",
                            "compileCsh      = $component{compileCsh}",
                            "mkmfTemplate    = $component{mkmfTemplate}"
                        );

# ------------------------------------------------------------ link the component to the components hash
                        $components{$name} = \%component;
                    } ## end if ($paths)
                    else {
                        $fre->out( FREMsg::FATAL,
                            "Component '$name' doesn't specify the mandatory 'paths' attribute" );
                        return 0;
                    }
                } ## end if ( !exists( $components...))
                else {
                    $fre->out( FREMsg::FATAL,
                        "Component '$name' is defined more than once - make sure each component has a distinct name"
                    );
                    return 0;
                }
            } ## end if ($name)
            else {
                $fre->out( FREMsg::FATAL, "Components with empty names aren't allowed" );
                return 0;
            }
        } ## end foreach my $componentNode (...)

# ------------------------------------------------------------------ verify intercomponent references
        foreach my $name ( keys %components ) {
            my $ref = $components{$name};
            foreach my $required ( split( ' ', $ref->{requires} ) ) {
                if ( !exists( $components{$required} ) ) {
                    $fre->out( FREMsg::FATAL,
                        "Component '$name' refers to a non-existent component '$required'" );
                    return 0;
                }
            }
        }

      # ------------------------------------------------------------------- compute components ranks
        foreach my $name ( keys %components ) {
            my $ref = $components{$name};
            if ( !defined( $ref->{rank} ) ) {
                if ( $rankSet->( \%components, $ref, 0 ) < 0 ) {
                    $fre->out( FREMsg::FATAL, "Component '$name' refers to itself via a loop" );
                    return 0;
                }
            }
        }

        # ------------------------------------------------------------------------ normal return
        return \%components;
    } ## end if ( scalar(@componentNodes...))
    else {
        $fre->out( FREMsg::FATAL, "The experiment '$expName' doesn't contain any components" );
        return 0;
    }

} ## end sub extractCompileInfo($)

sub extractRegressionLabels($$)

    # ------ arguments: $object $regressionOption
{
    my ( $r, $l ) = @_;
    my ( $fre, $expName, @expLabels ) = ( $r->fre(), $r->name(), $regressionLabels->($r) );
    unless ( my @expDuplicateLabels = FREUtil::listDuplicates(@expLabels) ) {
        my @optLabels = split( ',', $l );
        my @optUnknownLabels = ();
        {
            foreach my $optLabel (@optLabels) {
                push @optUnknownLabels, $optLabel
                    if $optLabel ne 'all'
                    && $optLabel ne 'suite'
                    && grep( $_ eq $optLabel, @expLabels ) == 0;
            }
        }
        if ( scalar(@optUnknownLabels) == 0 ) {
            my @result = ();
            if ( grep( $_ eq 'all', @optLabels ) > 0 ) {
                @result = @expLabels;
            }
            elsif ( grep( $_ eq 'suite', @optLabels ) > 0 ) {
                foreach my $expLabel (@expLabels) {
                    push @result, $expLabel
                        if grep( $_ eq $expLabel, @optLabels ) > 0
                        || grep( $_ eq $expLabel, FREExperiment::REGRESSION_SUITE ) > 0;
                }
            }
            else {
                foreach my $expLabel (@expLabels) {
                    push @result, $expLabel if grep( $_ eq $expLabel, @optLabels ) > 0;
                }
            }
            return @result;
        }
        else {
            my $optUnknownLabels = join( ', ', @optUnknownLabels );
            $fre->out( FREMsg::FATAL,
                "The experiment '$expName' doesn't contains regression tests '$optUnknownLabels'" );
            return ();
        }
    } ## end unless ( my @expDuplicateLabels...)
    else {
        my $expDuplicateLabels = join( ', ', @expDuplicateLabels );
        $fre->out( FREMsg::FATAL,
            "The experiment '$expName' contains non-unique regression tests '$expDuplicateLabels'"
        );
        return ();
    }
} ## end sub extractRegressionLabels($$)

sub extractRegressionRunInfo($$)

    # ------ arguments: $object $label
    # ------ called as object method
    # ------ return a reference to the regression run info
{
    my ( $r, $l ) = @_;
    my ( $fre, $expName ) = ( $r->fre(), $r->name() );
    if ( my $nmls = $r->extractNamelists() ) {
        if ( my $regNode = $regressionRunNode->( $r, $l ) ) {
            my @runNodes = $regNode->findnodes('run');
            if ( scalar(@runNodes) > 0 ) {
                my ( $ok, %runs ) = ( 1, () );
                for ( my $i = 0; $i < scalar(@runNodes); $i++ ) {
                    my $resources = $r->getResourceRequests( $nmls, $runNodes[$i] ) or return;
                    my $msl = $r->nodeValue( $runNodes[$i], '@months' );
                    my $dsl = $r->nodeValue( $runNodes[$i], '@days' );
                    my $hsl = $r->nodeValue( $runNodes[$i], '@hours' );
                    my $srt = $resources->{jobWallclock};

                    my $patternRunTime = qr/^\d?\d:\d\d:\d\d$/;

                    if ( $srt =~ m/$patternRunTime/ ) {
                        if ( $msl or $dsl or $hsl ) {
                            my @msa = split( ' ', $msl );
                            my @dsa = split( ' ', $dsl );
                            my @hsa = split( ' ', $hsl );
                            my $spj = List::Util::max( scalar(@msa), scalar(@dsa), scalar(@hsa) );
                            while ( scalar(@msa) < $spj ) { push( @msa, '0' ); }
                            while ( scalar(@dsa) < $spj ) { push( @dsa, '0' ); }
                            while ( scalar(@hsa) < $spj ) { push( @hsa, '0' ); }
                            my $nmlsOverridden = $overrideRegressionNamelists->( $r, $nmls->copy(),
                                $runNodes[$i] );

                            if ( my $mpiInfo
                                = $MPISizeParameters->( $r, $resources, $nmlsOverridden ) ) {
                                addResourceRequestsToMpiInfo( $fre, $resources, $mpiInfo );

                                my %run = ();
                                $run{label}   = $l;
                                $run{number}  = $i;
                                $run{postfix} = $regressionPostfix->(
                                    $r, $l, $i, $hsl, $spj, $msa[0], $dsa[0], $hsa[0], $mpiInfo
                                );
                                $run{mpiInfo}        = $mpiInfo;
                                $run{months}         = join( ' ', @msa );
                                $run{days}           = join( ' ', @dsa );
                                $run{hours}          = join( ' ', @hsa );
                                $run{hoursDefined}   = ( $hsl ne "" );
                                $run{runTimeMinutes} = FREUtil::makeminutes($srt);
                                $run{namelists}      = $nmlsOverridden;
                                $runs{$i}            = \%run;
                            }
                            else {
                                $fre->out( FREMsg::FATAL,
                                    "The experiment '$expName', the regression test '$l', run '$i' - model size parameters are invalid"
                                );
                                $ok = 0;
                            }
                        } ## end if ( $msl or $dsl or $hsl)
                        else {
                            $fre->out( FREMsg::FATAL,
                                "The experiment '$expName', the regression test '$l', run '$i' - timing parameters must be defined"
                            );
                            $ok = 0;
                        }
                    } ## end if ( $srt =~ m/$patternRunTime/)
                    else {
                        $fre->out( FREMsg::FATAL,
                            "The experiment '$expName', the regression test '$l', run '$i' - the running time '$srt' must be nonempty and have the HH:MM:SS format"
                        );
                        $ok = 0;
                    }
                } ## end for ( my $i = 0; $i < scalar...)
                return ($ok) ? \%runs : 0;
            } ## end if ( scalar(@runNodes)...)
            else {
                $fre->out( FREMsg::FATAL,
                    "The experiment '$expName' - the regression test '$l' doesn't have any runs" );
                return 0;
            }
        } ## end if ( my $regNode = $regressionRunNode...)
        else {
            $fre->out( FREMsg::FATAL,
                "The experiment '$expName' - the regression test '$l' doesn't exist or defined more than once"
            );
            return 0;
        }
    } ## end if ( my $nmls = $r->extractNamelists...)
    else {
        $fre->out( FREMsg::FATAL, "The experiment '$expName' - unable to extract namelists" );
        return 0;
    }
} ## end sub extractRegressionRunInfo($$$)

sub extractProductionRunInfo($)

    # ------ arguments: $object
    # ------ called as object method
    # ------ return a reference to the production run info
{
    my ( $r ) = @_;
    my ( $fre, $expName ) = ( $r->fre(), $r->name() );
    if ( my $nmls = $r->extractNamelists() ) {
        if ( my $prdNode = $productionRunNode->($r) ) {
            my $resources = $r->getResourceRequests( $nmls ) or return;
            my $mpiInfo = $MPISizeParameters->( $r, $resources, $nmls->copy );
            addResourceRequestsToMpiInfo( $fre, $resources, $mpiInfo );

            my $smt = $r->nodeValue( $prdNode, '@simTime' );
            my $smu = $r->nodeValue( $prdNode, '@units' );
            my $srt = $resources->{jobWallclock}
                || $fre->runTime( $resources->{npes_with_threads} );
            my $gmt = $r->nodeValue( $prdNode, 'segment/@simTime' );
            my $gmu = $r->nodeValue( $prdNode, 'segment/@units' );
            my $grt = $resources->{segRuntime};
            my $patternUnits = qr/^(?:years|year|months|month)$/;
            if ( ( $smt > 0 ) and ( $smu =~ m/$patternUnits/ ) ) {

                if ( ( $gmt > 0 ) and ( $gmu =~ m/$patternUnits/ ) ) {
                    my $patternYears = qr/^(?:years|year)$/;
                    $smt *= 12 if $smu =~ m/$patternYears/;
                    $gmt *= 12 if $gmu =~ m/$patternYears/;
                    if ( $gmt <= $smt ) {
                        my $patternRunTime = qr/^\d?\d:\d\d:\d\d$/;
                        if ( $srt =~ m/$patternRunTime/ ) {
                            if ( $grt =~ m/$patternRunTime/ ) {
                                my ( $srtMinutes, $grtMinutes )
                                    = ( FREUtil::makeminutes($srt), FREUtil::makeminutes($grt) );
                                if ( $grtMinutes <= $srtMinutes ) {
                                    if ($mpiInfo) {
                                        my %run = ();
                                        $run{mpiInfo}           = $mpiInfo;
                                        $run{simTimeMonths}     = $smt;
                                        $run{simRunTimeMinutes} = $srtMinutes;
                                        $run{segTimeMonths}     = $gmt;
                                        $run{segRunTimeMinutes} = $grtMinutes;
                                        $run{namelists}         = $nmls->copy;
                                        return \%run;
                                    }
                                    else {
                                        $fre->out( FREMsg::FATAL,
                                            "The experiment '$expName' - model size parameters are invalid"
                                        );
                                        return 0;
                                    }
                                }
                                else {
                                    $fre->out( FREMsg::FATAL,
                                        "The experiment '$expName' - the segment running time '$grtMinutes' must not exceed the maximum job running time allowed '$srtMinutes'"
                                    );
                                    return 0;
                                }
                            } ## end if ( $grt =~ m/$patternRunTime/)
                            else {
                                $fre->out( FREMsg::FATAL,
                                    "The experiment '$expName' - the segment running time '$grt' must be nonempty and have the HH:MM:SS format"
                                );
                                return 0;
                            }
                        } ## end if ( $srt =~ m/$patternRunTime/)
                        else {
                            $fre->out( FREMsg::FATAL,
                                "The experiment '$expName' - the simulation running time '$srt' must be nonempty and have the HH:MM:SS format"
                            );
                            return 0;
                        }
                    } ## end if ( $gmt <= $smt )
                    else {
                        $fre->out( FREMsg::FATAL,
                            "The experiment '$expName' - the segment model time '$gmt' must not exceed the simulation model time '$smt'"
                        );
                        return 0;
                    }
                } ## end if ( ( $gmt > 0 ) and ...)
                else {
                    $fre->out( FREMsg::FATAL,
                        "The experiment '$expName' - the segment model time '$gmt' must be nonempty and have one of (years|year|months|month) units defined"
                    );
                    return 0;
                }
            } ## end if ( ( $smt > 0 ) and ...)
            else {
                $fre->out( FREMsg::FATAL,
                    "The experiment '$expName' - the simulation model time '$smt' must be nonempty and have one of (years|year|months|month) units defined"
                );
                return 0;
            }
        } ## end if ( my $prdNode = $productionRunNode...)
        else {
            $fre->out( FREMsg::FATAL,
                "The experiment '$expName' - production parameters aren't defined" );
            return 0;
        }
    } ## end if ( my $nmls = $r->extractNamelists...)
    else {
        $fre->out( FREMsg::FATAL, "The experiment '$expName' - unable to extract namelists" );
        return 0;
    }
} ## end sub extractProductionRunInfo($$)

# Convenience function used in extractProductionRunInfo and extractRegressionRunInfo
# MPISizeParameters() generates $mpiInfo from resource requests,
# but a few additional related parameters must be added as well.
# Given the complexity of MPISizeParameters(), those additional related parameters
# are added using this function.
# ------ arguments: $fre $resources $mpiInfo
# ------ returns: nothing, $mpiInfo is changed
sub addResourceRequestsToMpiInfo {
    my ( $fre, $resources, $info ) = @_;
    my @components = split( ';', $fre->property('FRE.mpi.component.names') );

    $info->{layoutList}      = [ map { $resources->{$_}->{layout} } @components ];
    $info->{ioLayoutList}    = [ map { $resources->{$_}->{io_layout} } @components ];
    $info->{maskTableList}   = [ map { $resources->{$_}->{mask_table} } @components ];
    $info->{ranksPerEnsList} = [ map { $resources->{$_}->{ranks} } @components ];
    $info->{ntdsResList}     = [ map { $resources->{$_}->{resource_threads} } @components ];
}

# Get resource info from <runtime>/.../<resources> tag
# and decides whether hyperthreading will be used
# ------ arguments: $exp namelists           -- for production
# ------ arguments: $exp namelists $run_node -- for regression
# ------ returns: hashref containing resource specs or undef on failure
sub getResourceRequests($$) {
    my ( $exp, $namelists, $regression_run_node ) = @_;
    my $fre                = $exp->fre;
    my $site               = $fre->platformSite;
    my @components         = split( ';', $fre->property('FRE.mpi.component.names') );
    my @enabled            = split( ';', $fre->property('FRE.mpi.component.enabled') );
    my @enabled_components = map { $components[$_] } grep { $enabled[$_] } 0 .. $#enabled;
    my $concurrent         = $namelists->namelistBooleanGet( 'coupler_nml', 'concurrent' );
    my @types              = (qw( ranks threads hyperthread layout io_layout mask_table ));
    my %data;
    my $node;

    # given a list of suitable resource nodes, pick the site-specific one
    my $pick_node = sub {
        my @site_nodes    = grep { $_->hasAttribute('site') } @_;
        my @nonsite_nodes = grep { !$_->hasAttribute('site') } @_;

        if ( my $n = @site_nodes ) {
            $fre->out( FREMsg::WARNING,
                "Found $n equally suitable site-specific resources tags; using first one" )
                if $n > 1;
            return $site_nodes[0];
        }
        if ( my $n = @nonsite_nodes ) {
            $fre->out( FREMsg::WARNING,
                "Found $n equally suitable site-agnostic resources tags; using first one" )
                if $n > 1;
            return $nonsite_nodes[0];
        }
    };

    # if node is given, try to find <resources> tag with no inheritance
    if ($regression_run_node) {
        $node = $pick_node->(
            $regression_run_node->findnodes("resources[\@site = '$site' or not(\@site)]") );
    }

    # for production OR if regression <resources> tag wasn't found,
    # find first resource node with experiment inheritance
    if ( !$node ) {
        $node = $pick_node->(
            $exp->extractNodes(
                'runtime', "production/resources[\@site = '$site' or not(\@site)]"
            )
        );
    }

    # bail out if no resources tag can be found
    if ( !$node ) {
        my $message
            = $regression_run_node
            ? "No resource request tag was found within <runtime>/<regression>/<run> OR within <runtime>/<production> or its experiment ancestors. "
            : "No resource request tag was found within <runtime>/<production> or its experiment ancestors. ";
        $message
            .= "A <resources> tag must now be specified. See FRE Documentation at http://wiki.gfdl.noaa.gov/index.php/FRE_User_Documentation#Resource_specification";
        $fre->out( FREMsg::FATAL, $message );
        return;
    }

    # Extract resource info
    $fre->out( FREMsg::NOTE, "Extracting resource requests..." );
    for my $var (qw( jobWallclock segRuntime )) {
        $data{$var} = $fre->nodeValue( $node, "\@$var" );
        if ( $data{$var} ) {
            $fre->out( FREMsg::NOTE, "$var = " . $data{$var} );
        }
        else {
            $fre->out( FREMsg::NOTE, "$var is unspecified" );
        }
    }
    for my $comp (@components) {
        for my $type (@types) {
            $data{$comp}{$type} = $fre->nodeValue( $node, "$comp/\@$type" );
        }
    }

    # Set threads to 1 unless openmp
    for my $comp (@components) {
        next unless $data{$comp}{threads} and $data{$comp}{threads} > 1;
        if ( !FRETargets::containsOpenMP( $fre->target ) ) {
            $fre->out( FREMsg::WARNING,
                "Component $comp has requested $data{$comp}{threads} threads but not using OpenMP; setting to 1"
            );
            $data{$comp}{threads} = 1;
        }
    }

    # Require ranks/threads for at least one component
    my %complete_specs = (
        atm => 4,
        ocn => 4,
        lnd => 2,
        ice => 2,
    );
    my $ok = 0;
    for my $comp (@components) {
        my $message;
        my $N = grep !/^$/, values %{ $data{$comp} };
        if ( $data{$comp}{ranks} and $data{$comp}{threads} ) {
            $ok = 1 if $ok >= 0;
        }
        if ( ($data{$comp}{ranks} and not $data{$comp}{threads}) or ($data{$comp}{threads} and not $data{$comp}{ranks})) {
            $ok = -1;
        }
        if ( $N >= $complete_specs{$comp} ) {
            $message = "Component $comp has complete resource request specifications: ";
        }
        elsif ( $N > 0 ) {
            $message = "Component $comp has partial resource request specifications: ";
        }
        else {
            $message = "Component $comp has no request specifications.  ";
        }
        for my $type (@types) {
            if ( $data{$comp}{$type} ) {
                $message .= "$type=$data{$comp}{$type}, ";
            }
        }
        chop $message for 1, 2;
        $fre->out( FREMsg::NOTE, $message );
    } ## end for my $comp (@components)
    if ( $ok != 1) {
        $fre->out( FREMsg::FATAL,
            "A resource request tag was found but was incomplete. Ranks and threads must be specified for at least one model component. Also, threads must be non-zero if ranks are non-zero, and vice versa. See FRE Documentation at http://wiki.gfdl.noaa.gov/index.php/FRE_User_Documentation#Resource_specification"
        );
        return;
    }

    # Add up total ranks of MPI-enabled components (concurrent) or take the maximum (non-concurrent)
    if ($concurrent) {
        for my $comp (@enabled_components) {
            $data{npes} += $data{$comp}{ranks};
            $data{npes_with_threads} += $data{$comp}{ranks} * $data{$comp}{threads};
        }
    }
    else {
        my %ranks = map { $_ => $data{$_}{ranks} } @enabled_components;
        my @sorted = sort { $ranks{$b} <=> $ranks{$a} } keys %ranks;
        $data{npes}              = $data{ $sorted[0] }{ranks};
        $data{npes_with_threads} = $data{ $sorted[0] }{ranks} * $data{ $sorted[0] }{threads};
    }
    $fre->out( FREMsg::NOTE, "Setting npes=$data{npes}" );

    # Apply hyperthreading if desired and possible
    for my $comp (@enabled_components) {
        $data{$comp}{resource_threads} = $data{$comp}{threads} if $data{$comp}{threads};
    }
    for my $comp (@enabled_components) {
        if ($data{$comp}{hyperthread} && $data{$comp}{hyperthread} =~ /yes|true|on/i) {
            if ( !$fre->property('FRE.mpi.runCommand.hyperthreading.allowed') ) {
                $fre->out( FREMsg::WARNING,
                    "Hyperthreading was requested but isn't supported on this platform." );
            }
            elsif (! $data{$comp}{ranks}) {
                $fre->out( FREMsg::NOTE,
                    "Won't use hyperthreading for component $comp as it requests no ranks." );
            }
            elsif ( !$data{$comp}{threads} ) {
                $fre->out( FREMsg::WARNING,
                    "Won't use hyperthreading for component $comp as it requested no threads" );
            }
            elsif ( $data{$comp}{threads} == 1 ) {
                $fre->out( FREMsg::WARNING,
                    "Won't use hyperthreading for component $comp as it requested only 1 thread" );
            }
            else {
                $data{$comp}{resource_threads} = POSIX::ceil( $data{$comp}{threads} / 2 );
                $fre->out( FREMsg::NOTE, "Will use hyperthreading ($data{$comp}{resource_threads} physical threads) for component $comp" );
            }
        }
    }

    return \%data;
} ## end sub getResourceRequests($$)

# //////////////////////////////////////////////////////////////////////////////
# //////////////////////////////////////////////////////////// Initialization //
# //////////////////////////////////////////////////////////////////////////////

return 1;
