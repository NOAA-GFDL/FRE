package FREAnalysis;

#use strict; use warnings;
require Exporter;
our @ISA       = qw(Exporter);
our @EXPORT_OK = qw(analysis);

sub analysis {
    my $args          = shift;
    my $ts_av_Node    = $args->{node};
    my $expt          = $args->{experiment};
    my $gridspec      = $args->{gridSpec};
    my $staticfile    = $args->{staticFile};
    my $tsORav        = $args->{type};
    my $diagfile      = $args->{diagSrc};
    my $ppRootDir     = $args->{ppRootDir};
    my $component     = $args->{comp};
    my $dtvars_ref    = $args->{dtvarsRef};
    my $analysisdir   = $args->{analysisDir};
    my $aoutscriptdir = $args->{scriptDir};
    my $workdir       = $args->{workDir};
    my $archivedir    = $args->{archDir};
    my $experID       = $args->{experID};
    my $realizID      = $args->{realizID};
    my $runID         = $args->{runID};
    my $opt_t         = $args->{opt_t};
    my $opt_O         = $args->{opt_O};
    my $opt_Y         = $args->{opt_Y};
    my $opt_Z         = $args->{opt_Z};
    my $opt_V         = $args->{opt_V};
    my $opt_u         = $args->{opt_u};
    my $sim0          = $args->{sim0};
    my $opt_R         = $args->{opt_R};
    my $hist_dir      = $args->{histDir};
    my $nlat          = $args->{nLat};
    my $nlon          = $args->{nLon};
    my $frexml        = $args->{absXmlPath};
    my $stdoutdir     = $args->{stdoutDir};
    my $opt_P         = $args->{opt_P};
    my $opt_T         = $args->{stdTarget};
    my $opt_s         = $args->{opt_s};

    # exit if no analysis nodes found
    my $anum = &anodenum($ts_av_Node);
    if ( $anum <= 0 ) { return; }

    #$opt_v=1;

    #----list inputs
    if ($opt_V) {
        print "node: $tsORav\n";
        print "component: $component\n";
        print "expt: $expt\n";
        print "frexml: $frexml\n";
        print "stdoutdir: $stdoutdir\n";
    }

    # global variables
    my $csh = "";
    my ( $freq, $cl, $asrcdir, $thevar, $season, $ssn );

    # timeAverage and timeSeries are slightly different
    if ( $tsORav eq "timeSeries" ) {
        $freq    = $ts_av_Node->findvalue('@freq');
        $cl      = $ts_av_Node->findvalue('@chunkLength');
        $asrcdir = "$ppRootDir/$component/ts/$freq/$cl";
        if ($opt_V) { print "freq: $freq\nchunkLength: $cl\n"; }
    }
    elsif ( $tsORav eq "timeAverage" ) {
        $freq    = $ts_av_Node->findvalue('@source');
        $cl      = $ts_av_Node->findvalue('@interval');
        $asrcdir = "$ppRootDir/$component/av/$freq" . "_$cl";
        if ($opt_V) { print "source: $freq\ninterval: $cl\n"; }
    }
    else {
        print STDERR
            "ERROR from analysis.PM: timeSeries or timeAverage must be specified. Skip analysis\n";
        return;
    }

    if ($opt_V) {
        print "gridspec: $gridspec\n";
        print "staticfile: $staticfile\n";
        print "diagfile: $diagfile\n";
        print "ppRootDir: $ppRootDir\n";
        print "dtvars_ref: $dtvars_ref\n";
        print "analysisdir: $analysisdir\n";
        print "aoutscriptdir: $aoutscriptdir\n";
        print "workdir: $workdir\n";
        print "archivedir: $archivedir\n";
        print "\$opt_t: $opt_t\n";
        print "\$opt_O: $opt_O\n";
        print "\$opt_Y: $opt_Y\n";
        print "\$opt_Z: $opt_Z\n";
        print "\$opt_V: $opt_V\n";
        print "\$opt_s: $opt_s\n";
        print "sim0: $sim0\n";
        print "hist_dir: $hist_dir\n";
        print "nlat, nlon: $nlat, $nlon\n";
    } ## end if ($opt_V)

    if ($opt_V) { print STDERR "ANALYSIS: Found $anum analysis scripts for $asrcdir\n"; }

    my $clnumber = $cl;
    $clnumber =~ s/yr$//;

    ( $season, $ssn ) = seasonAV($freq);

    # looking for the availablechunks based on the first variable found in $asrcdir
    ( my $first_ref, my $last_ref ) = availablechunks( $asrcdir, $component, $clnumber, $freq );
    my @availablechunksfirst = @$first_ref;
    my @availablechunkslast  = @$last_ref;

    # do not do anything if no data available
    if ( @availablechunksfirst < 1 ) {
        print STDERR "ANALYSIS: No data available for analysis figures in $asrcdir\n\n";
        return;
    }

    if ($opt_V) {
        print STDERR "availablechunks start= @availablechunksfirst\n";
        print STDERR "availablechunks end  = @availablechunkslast\n";
    }

    #----Now loop through each analysis under the current TS or AV node
    foreach my $ananode ( $ts_av_Node->findnodes('analysis') ) {

        my @arrayofExptsH;    # array of experiments hash
        my $iExpt = 0;        # index number of experiments in arrayofExptsH

        # queue the analysis attributes specified in the xml file for the analysis node
        my @fields = queueAnaAttr($ananode);
        push @arrayofExptsH, {@fields};

        my $switch = $arrayofExptsH[$iExpt]{'switch'};
        if ( ( substr( $switch, 0, 2 ) eq "of" ) or ( substr( $switch, 0, 2 ) eq "OF" ) ) { next; }

        #----adjust start and end date
        my $astart = $arrayofExptsH[$iExpt]{astartYear};
        my $aend   = $arrayofExptsH[$iExpt]{aendYear};
        my ( $flag, $astartYear, $aendYear, $databegyr, $dataendyr, @missing )
            = start_end_date( $astart, $aend, $opt_Y, $opt_Z, \@availablechunksfirst,
            \@availablechunkslast, $clnumber );
        if ( @missing > 0 ) {
            print STDERR
                "ANALYSIS: cannot process timeSeries analysis, missing these chunks: @missing \n";
        }
        if ( $flag eq "bad" or ( $tsORav eq "timeSeries" and @missing > 0 ) ) { next; }

        #make sure asrcdir ends in '/' (arl)
        my $asrcdirlen = ( length $asrcdir ) - 1;
        if ( substr( $asrcdir, $asrcdirlen ) ne '/' ) { $asrcdir = $asrcdir . '/'; }

        # put the start and end date into the array of expt hash
        $arrayofExptsH[$iExpt]{astartYear} = $astartYear;
        $arrayofExptsH[$iExpt]{aendYear}   = $aendYear;
        $arrayofExptsH[$iExpt]{databegyr}  = $databegyr;
        $arrayofExptsH[$iExpt]{dataendyr}  = $dataendyr;

        # variables for the expt to go into the array of expt hash
        $arrayofExptsH[$iExpt]{exptname}   = $expt;
        $arrayofExptsH[$iExpt]{clnumber}   = $clnumber;
        $arrayofExptsH[$iExpt]{archivedir} = cleanpath($archivedir);
        $arrayofExptsH[$iExpt]{asrcdir}    = cleanpath($asrcdir);
        $arrayofExptsH[$iExpt]{asrcfile}   = cleanpath($asrcfile);     #Time averages only
        $arrayofExptsH[$iExpt]{gridspec}   = cleanpath($gridspec);
        $arrayofExptsH[$iExpt]{staticfile} = cleanpath($staticfile);
        $arrayofExptsH[$iExpt]{hist_dir}   = cleanpath($hist_dir);
        $arrayofExptsH[$iExpt]{nlon}       = $nlon;
        $arrayofExptsH[$iExpt]{nlat}       = $nlat;
        $arrayofExptsH[$iExpt]{time}       = $opt_t;

        # These variables always use cntl's
        $mode = $arrayofExptsH[$iExpt]{mode};
        $arrayofExptsH[$iExpt]{MODEL_start_yr} = substr( $sim0, 0, 4 );
        $arrayofExptsH[$iExpt]{freq} = $freq;

        #$arrayofExptsH[0]{freq} = substr($sim0,0,4);

        #### additional experiments? no problem.

        my $myflag;
        my $addexptyrstr;
        foreach my $addexptNode ( $ananode->findnodes('addexpt') ) {
            $iExpt++;
            my @fields = queueAnaAttr($addexptNode);
            push @arrayofExptsH, {@fields};

            # check the addexpt. switch, exptname, xmlfile, script
            # must on, or found, or exist. Otherwise exit the analysis node.
            my $switch = $arrayofExptsH[$iExpt]->{'switch'};
            if ( ( substr( $switch, 0, 2 ) eq "of" ) or ( substr( $switch, 0, 2 ) eq "OF" ) ) {
                last;
            }
            if ( !$arrayofExptsH[$iExpt]->{exptname} ) {
                print STDERR "ANALYSIS: No experiment name specified for the addexpt. Skipped\n";
                $myflag = -1;
                last;
            }

            if ( !$arrayofExptsH[$iExpt]->{xmlfile} ) {
                print STDERR "ANALYSIS: No xmlfile specified for the addexpt. Skipped\n";
                $myflag = -1;
                last;
            }
            if ( !-e $arrayofExptsH[$iExpt]->{xmlfile} ) {
                print STDERR "ANALYSIS: xmlfile does not exist for the addexpt. Skipped\n";
                $myflag = -1;
                last;
            }

            my $freopts = '';
            if ( "$arrayofExptsH[$iExpt]->{platform}" ne '' ) {
                $freopts .= " -p $arrayofExptsH[$iExpt]->{platform}";
            }
            if ( "$arrayofExptsH[$iExpt]->{target}" ne '' ) {
                $freopts .= " -t $arrayofExptsH[$iExpt]->{target}";
            }

            #----passed basic checking, find info from the xmlfile and expt name
            my $xmlfile   = $arrayofExptsH[$iExpt]->{xmlfile};
            my $exptname  = $arrayofExptsH[$iExpt]->{exptname};
            my $addexptcl = $arrayofExptsH[$iExpt]->{chunk} || $cl;
            my $clnumber  = $addexptcl;
            $clnumber =~ s/yr$//;

            chomp( my $ppRootDir = `frelist $freopts -d postProcess -x $xmlfile $exptname` );

            chomp( my $gridspec
                    = `frelist $freopts -e 'input/dataFile[\@label="gridSpec"]/dataSource' -x $xmlfile $exptname`
            );
            if ( !-f $gridSpec ) {
                chomp( my $gridspec
                        = `frelist $freopts -e 'input/gridSpec/\@file' -x $xmlfile $exptname` );
            }
            my $staticfile = "$ppRootDir/$component/$component.static.nc";
            my $asrcdir_addexpt;
            if ( $tsORav eq "timeSeries" ) {
                $asrcdir_addexpt = "$ppRootDir/$component/ts/$freq/$addexptcl";
            }
            else {
                $asrcdir_addexpt = "$ppRootDir/$component/av/$freq" . "_$addexptcl";
            }

            if ($opt_V) {
                print " addexpt $iExpt xmlfile   = $xmlfile \n";
                print " addexpt $iExpt exptname  = $exptname \n";
                print " addexpt $iExpt ppRootDir = $ppRootDir \n";
                print " addexpt $iExpt staticfile= $staticfile \n";
                print " addexpt $iExpt asrcdir   = $asrcdir_addexpt \n";
                print " addexpt $iExpt clnumber  = $clnumber \n";
            }

            #---- find the available chunks for the addexpt
            # define the @existing to all the periods based on @tsvars[0]
            ( my $first_ref, my $last_ref )
                = availablechunks( $asrcdir_addexpt, $component, $clnumber, $freq );
            my @addavailablechunksfirst = @$first_ref;
            my @addavailablechunkslast  = @$last_ref;

            # exit the analysis node if no data available
            if ( @addavailablechunksfirst < 1 ) {
                print STDERR "ANALYSIS: requested data not found for the addexpt. Skipped\n";
                $myflag = -1;
                last;
            }

            #---- start and end date from the <addexpt argument>, if not found, use cntl's
            my $astart = $arrayofExptsH[$iExpt]->{astartYear} || $arrayofExptsH[0]->{astartYear};
            my $aend   = $arrayofExptsH[$iExpt]->{aendYear}   || $arrayofExptsH[0]->{aendYear};

            #----adjust start and end date
            my ( $flag, $astartYear, $aendYear, $databegyr, $dataendyr, @missing )
                = start_end_date( $astart, $aend, $astart, $aend, \@addavailablechunksfirst,
                \@addavailablechunkslast, $clnumber );
            if ( $flag eq "bad" or ( $tsORav eq "timeSeries" and @missing > 0 ) ) {
                print STDERR "ANALYSIS:   files are not complete for addexpt $iExpt. Skipped. \n";
                if ($opt_V) { print STDERR "ANALYSIS: Missing chunks: \n @missing \n" }
                $myflag = -1;
                last;
            }

            if ( $astartYear and $aendYear ) { $addexptyrstr = $astartYear . "-" . $aendYear }

            if ($opt_V) {
                print STDERR
                    " addexpt $iExpt astartYear: $astartYear aendYear: $aendYear databegyr: $databegyr dataendyr: $dataendyr\n";
                print STDERR " addexpt $iExpt missing: @missing\n";
            }

            #
            # fill the $arrayofExptsH with modified or additional infomation
            $arrayofExptsH[$iExpt]{astartYear} = $astartYear;
            $arrayofExptsH[$iExpt]{aendYear}   = $aendYear;
            $arrayofExptsH[$iExpt]{databegyr}  = $databegyr;
            $arrayofExptsH[$iExpt]{dataendyr}  = $dataendyr;

            # more variables for the expt
            $arrayofExptsH[$iExpt]{clnumber}   = $clnumber;          #same as expt[0]
            $arrayofExptsH[$iExpt]{archivedir} = $archivedir;
            $arrayofExptsH[$iExpt]{asrcdir}    = $asrcdir_addexpt;

            # $arrayofExptsH[$iExpt]{asrcfile} = $asrcfile;  #Time averages only
            $arrayofExptsH[$iExpt]{gridspec}   = $gridspec;
            $arrayofExptsH[$iExpt]{staticfile} = $staticfile;
            $arrayofExptsH[$iExpt]{hist_dir}
                = "$archivedir/$arrayofExptsH[$iExpt]{exptname}/history";

            #that could be wrong, theoretically.
            $arrayofExptsH[$iExpt]{nlon} = $nlon;
            $arrayofExptsH[$iExpt]{nlat} = $nlat;

        }    ########### foreach my $addexptNode

        if ( $myflag eq -1 ) {

            #print STDERR "addexpts data not complete. process next analysis node\n";
            next;
        }

        ### find the analysis template script: $aScript. if not found, out of the analysis node
        my $aScript;
        $aScript = $arrayofExptsH[0]{script};
        if ( !$aScript ) { $aScript = $ananode->findnodes('script'); }
        if ( !$aScript ) {
            print STDERR "ANALYSIS: analysis template script not specified, skipped\n";
            next;
        }
        my @aargu = split( '\ ', $aScript );
        $aScript = shift @aargu;
        $aScript =~ s/"//g;
        $aScript =~ s/\$\(name\)/$expt/g;
        my @afile = split( '\/', $aScript );
        if ($opt_V) {
            print STDERR "###analysis script $aScript\n";
            print STDERR "###analysis### argu,", @aargu, "\n";
        }

        ### find the cksum CRC number of the @aargu
        my @cksumCRC = (-1);
        if ( @aargu gt 0 ) { @cksumCRC = split( "\ ", `echo "@aargu" | cksum` ) }
        if ($opt_V) {"The cksumCRC of aargu array = $cksumCRC[0] \n   "}

        ### define where to put the figures: $figureDir
        my $figureDir = "";
        if ($opt_O) { $figureDir = $opt_O; }    #taking command line output dir
        if ( !$figureDir ) {
            $figureDir = $ananode->findnodes('outdir');
        }                                       # the <outdir> node in <analysis>
        if ( !$figureDir ) {
            $figureDir = $arrayofExptsH[0]{figureDir};
        }                                       # the attribute of <analysis>
        if ( !$figureDir ) { $figureDir = "$analysisdir"; }    # the node in <setup>
        if ( !$figureDir ) { $figureDir = "$archivedir"; }     # the default
        $figureDir =~ s/\$user/$user/g;
        $figureDir =~ s/\$USER/$user/g;
        $figureDir =~ s/\$ARCHIVE/\/archive\/$user/g;
        $figureDir =~ s/\$expt/$expt/;
        $figureDir =~ s/\$archive/$archivedir/;
        $figureDir =~ s/\$addexptName/$arrayofExptsH[1]{exptname}/;
        $figureDir =~ s/"//g;
        $figureDir =~ s/\/$//g;
        print "ANALYSIS: Figures will be written to $figureDir\n" if $opt_V;

        #might be in /net, so can't mkdir directly, analysis scripts must create this.
        #unless (-d "$figureDir") {
        #   print "ANALYSIS: Creating output dir $figureDir\n";# if $opt_V;
        #   if ( substr($figureDir,0,8) eq '/archive' ) {
        #       acarch("mkdir -p $figureDir ");
        #   } else {
        #       system "mkdir -p $figureDir ";
        #   }
        #}

        ### $aoutscriptdir_final: $aoutscriptdir appended with expts
        my $aoutscriptdir_final;
        if ( $iExpt == 0 ) {
            $aoutscriptdir_final = "$aoutscriptdir";
        }
        elsif ( $iExpt == 1 ) {
            $aoutscriptdir_final = "$aoutscriptdir/vs_$arrayofExptsH[$iExpt]{exptname}";
            if ($addexptyrstr) {
                $aoutscriptdir_final
                    = "$aoutscriptdir/${expt}/vs_$arrayofExptsH[$iExpt]{exptname}_$addexptyrstr";
            }
        }
        else {
            $aoutscriptdir_final = "$aoutscriptdir/vs_${iExpt}_addexpt";
        }

        unless ( -d "$aoutscriptdir_final" ) { system "mkdir -p $aoutscriptdir_final"; }

        my $aScriptout;    # the script to submit for each analysis

        my $unique = '';
        if ($opt_u) { $unique = ".$opt_u" }

        ####
        # if specify1year is found
        if ( $arrayofExptsH[0]{specify1year} ) {
            my $availablechunk = $arrayofExptsH[0]{specify1year};
            my $asrcfile       = "$component.$availablechunk.$ssn.nc";
            if ( $cksumCRC[0] gt 0 ) {
                $aScriptout
                    = "$aoutscriptdir_final/$afile[$#afile].$availablechunk$unique.$cksumCRC[0]";
            }
            else {
                $aScriptout = "$aoutscriptdir_final/$afile[$#afile].$availablechunk$unique";
            }
            if ( -e $aScriptout and !$opt_R ) {
                print STDERR "ANALYSIS: $aScriptout already exists, SKIP\n";
                next;
            }
            filltemplate(
                \@arrayofExptsH,        cleanpath($figureDir),
                $aScript,               \@aargu,
                cleanpath($aScriptout), $iExpt,
                cleanpath($workdir),    $mode,
                cleanpath($asrcfile),   $opt_s,
                $opt_u,                 $opt_V,
                cleanpath($frexml),     cleanpath($stdoutdir),
                $opt_P,                 $opt_T,
                $experID,               $realizID,
                $runID
            );

            #
        } ## end if ( $arrayofExptsH[0]...)
        else {

            #
            my $cumulative;
            if ( $tsORav eq "timeSeries" ) { $cumulative = $arrayofExptsH[0]{cumulative} || "yes"; }
            if ( $tsORav eq "timeAverage" ) { $cumulative = $arrayofExptsH[0]{cumulative} || "no"; }

            if ( $cumulative eq "yes" or $cumulative eq "YES" ) {
                if ($opt_V) { print "accumulative mode \n"; }
                my $availablechunk = "$arrayofExptsH[0]{astartYear}-$arrayofExptsH[0]{aendYear}";
                if ( $arrayofExptsH[0]{specify1year} ) {
                    $availablechunk = $arrayofExptsH[0]{specify1year};
                }
                if ( $cksumCRC[0] gt 0 ) {
                    $aScriptout
                        = "$aoutscriptdir_final/$afile[$#afile].$availablechunk$unique.$cksumCRC[0]";
                }
                else {
                    $aScriptout = "$aoutscriptdir_final/$afile[$#afile].$availablechunk$unique";
                }
                if ( -e $aScriptout and !$opt_R ) {
                    print STDERR "ANALYSIS: $aScriptout already exists, SKIP\n";
                    next;
                }

                # find all the chunks
                my @cumchunks;
                my $afreq = $arrayofExptsH[0]{afreq};
                for ( my $n = 0; $n < @availablechunksfirst; $n = $n + $afreq ) {
                    if (   $availablechunksfirst[$n] < $databegyr
                        or $availablechunkslast[$n] > $dataendyr ) {
                        next;
                    }
                    push( @cumchunks, "$availablechunksfirst[$n]-$availablechunkslast[$n]," );
                }
                my $tt = "{@cumchunks}";
                $tt =~ s/\,\}$/\}/;
                $tt =~ s/\ //g;
                my $asrcfile = "$component.$tt.$ssn.nc";
                if ($opt_V) { print "asrcfile:: $asrcfile\n" }

                # only proceed if ending analysis time == -t time, unless -Y or -Z are given
                if (    !$opt_Y
                    and !$opt_Z
                    and $arrayofExptsH[$ii]{time} !~ /^$arrayofExptsH[0]{aendYear}/ ) {
                    print STDERR
                        "ANALYSIS: skipping accumulative $aScriptout because ending analysis year ($arrayofExptsH[0]{aendYear}) != ending time specified on command-line -t ($arrayofExptsH[$ii]{time})\n";
                    next;
                }

#----#---- fill the variables in the template
#if ($opt_V) {print STDERR "fill these vars: @arrayofExptsH\n,$figureDir\n,$aScript\n,$aScriptout\n,$iExpt\n,$workdir\n,$mode\n"; }
                if ( $tsORav eq "timeAverage" ) {
                    filltemplate(
                        \@arrayofExptsH,        cleanpath($figureDir),
                        $aScript,               \@aargu,
                        cleanpath($aScriptout), $iExpt,
                        cleanpath($workdir),    $mode,
                        cleanpath($asrcfile),   $opt_s,
                        $opt_u,                 $opt_V,
                        cleanpath($frexml),     cleanpath($stdoutdir),
                        $opt_P,                 $opt_T,
                        $experID,               $realizID,
                        $runID
                    );
                }
                else {
                    filltemplate(
                        \@arrayofExptsH,        cleanpath($figureDir),
                        $aScript,               \@aargu,
                        cleanpath($aScriptout), $iExpt,
                        cleanpath($workdir),    $mode,
                        "",                     $opt_s,
                        $opt_u,                 $opt_V,
                        cleanpath($frexml),     cleanpath($stdoutdir),
                        $opt_P,                 $opt_T,
                        $experID,               $realizID,
                        $runID
                    );
                }

            } ## end if ( $cumulative eq "yes"...)
            else {    #if ($cumulative

                if ($opt_V) { print "non-accumulative mode \n"; }

                # loop through each available chunk
                my $afreq = $arrayofExptsH[0]{afreq};
                for ( my $n = 0; $n < @availablechunksfirst; $n = $n + $afreq ) {
                    if (   $availablechunksfirst[$n] < $databegyr
                        or $availablechunkslast[$n] > $dataendyr ) {
                        next;
                    }

                    my $availablechunk = "$availablechunksfirst[$n]-$availablechunkslast[$n]";

                    if ( "$availablechunksfirst[$n]" eq "$availablechunkslast[$n]" ) {
                        $availablechunk = "$availablechunksfirst[$n]";
                    }

                    my $asrcfile = "$component.$availablechunk.$ssn.nc";
                    if ( $cksumCRC[0] gt 0 ) {
                        $aScriptout
                            = "$aoutscriptdir_final/$afile[$#afile].$availablechunk$unique.$cksumCRC[0]";
                    }
                    else {
                        $aScriptout = "$aoutscriptdir_final/$afile[$#afile].$availablechunk$unique";
                    }
                    if ( -e $aScriptout and !$opt_R ) {
                        print STDERR "ANALYSIS: $aScriptout already exists, SKIP\n";
                        next;
                    }

                    # redefine the start and end year to each chunk
                    for ( my $ii = 0; $ii <= $iExpt; $ii++ ) {
                        $arrayofExptsH[$ii]{astartYear} = $availablechunksfirst[$n];
                        $arrayofExptsH[$ii]{aendYear}   = $availablechunkslast[$n];
                        $arrayofExptsH[$ii]{databegyr}  = $availablechunksfirst[$n];
                        $arrayofExptsH[$ii]{dataendyr}  = $availablechunkslast[$n];
                    }

                    # only proceed if ending analysis time == -t time, unless -Y or -Z are given
                    if ( !$opt_Y and !$opt_Z and $arrayofExptsH[$ii]{time} !~ /^$availablechunkslast[$n]/ ) {
                        print STDERR
                            "ANALYSIS: skipping non-accumulative $aScriptout because ending analysis year ($availablechunkslast[$n]) != ending time specified on command-line -t ($arrayofExptsH[$ii]{time})\n";
                        next;
                    }

#----#---- fill the variables in the template
#if ($opt_V) {print STDERR "fill these vars: @arrayofExptsH\n,$figureDir\n,$aScript\n,$aScriptout\n,$iExpt\n,$workdir\n,$mode\n";}
                    if ( $tsORav eq "timeAverage" ) {
                        filltemplate(
                            \@arrayofExptsH,        cleanpath($figureDir),
                            $aScript,               \@aargu,
                            cleanpath($aScriptout), $iExpt,
                            cleanpath($workdir),    $mode,
                            cleanpath($asrcfile),   $opt_s,
                            $opt_u,                 $opt_V,
                            cleanpath($frexml),     cleanpath($stdoutdir),
                            $opt_P,                 $opt_T,
                            $experID,               $realizID,
                            $runID
                        );
                    }
                    else {
                        filltemplate(
                            \@arrayofExptsH,        cleanpath($figureDir),
                            $aScript,               \@aargu,
                            cleanpath($aScriptout), $iExpt,
                            cleanpath($workdir),    $mode,
                            "",                     $opt_s,
                            $opt_u,                 $opt_V,
                            cleanpath($frexml),     cleanpath($stdoutdir),
                            $opt_P,                 $opt_T
                            ),
                            $experID, $realizID, $runID;
                    }
                }    #for (my $n = 0 ...
            }    #if ($cumulative ..
            ####

        }    # if specify1year
    }    #   foreach my $ananode

} ## end sub analysis

sub graindate {
    my $date      = $_[0];
    my $freq      = $_[1];
    my $formatstr = "";

    if ( "$freq" =~ /daily/ or "$freq" =~ /day/ ) {
        $formatstr = 8;
    }
    elsif ( "$freq" =~ /mon/ ) {
        $formatstr = 6;
    }
    elsif ( "$freq" =~ /ann/ or "$freq" =~ /yr/ or "$freq" =~ /year/ ) {
        $formatstr = 4;
    }
    elsif ( "$freq" =~ /hour/ or "$freq" =~ /hr/ ) {
        $formatstr = 10;
    }
    elsif ( "$freq" =~ /season/ ) {
        my $month = substr( $date, 4, 2 );
        unless ( $month == 12 or $month == 3 or $month == 6 or $month == 9 ) {
            if ($opt_V) {
                print STDERR "WARNING: graindate: $month is not the beginning of a known season.\n";
            }
        }
        my $year = substr( $date, 0, 4 );
        if ( $month == 12 ) {
            $year = $year + 1;
            $year = padzeros($year);
            return "$year.DJF";
        }
        elsif ( $month == 1 or $month == 2 ) {
            return "$year.DJF";
        }
        elsif ( $month == 3 or $month == 4 or $month == 5 ) {
            return "$year.MAM";
        }
        elsif ( $month == 6 or $month == 7 or $month == 8 ) {
            return "$year.JJA";
        }
        elsif ( $month == 9 or $month == 10 or $month == 11 ) {
            return "$year.SON";
        }
        else {
            print STDERR "WARNING: graindate: month $month not recognized";
            $formatstr = 6;
        }
    } ## end elsif ( "$freq" =~ /season/)
    else {
        print STDERR "WARNING: frequency not recognized in graindate\n";
        $formatstr = 10;
    }

    return substr( $date, 0, $formatstr );
} ## end sub graindate

sub padzeros {
    my $date = "$_[0]";
    if ( length($date) > 3 ) { return $date; }

    #this causes a bug.  you should think of another way to test this.
    #   if (scalar "$date" == 4) { return $date; }
    #maybe this will do?
    $date = $date + 1 - 1;
    if    ( $date > 999 ) { return $date; }
    elsif ( $date > 99 )  { return "0$date"; }
    elsif ( $date > 9 )   { return "00$date"; }
    else                  { return "000$date"; }
}

sub writescript {
    my ( $out, $mode, $outscript, $argu, $opt_s ) = @_;

    open( OUT, "> $outscript" );
    print OUT $out;
    close(OUT);

    my $status = system("chmod 755 $outscript");
    if ($status) { die "Sorry, I couldn't chmod $outscript"; }

    # submit to Slurm
    my $batch_command = "sbatch --chdir \$HOME $outscript";

    if ( substr( $mode, 0, 1 ) eq "i" ) {
        ####### The graphical analysis is specified in interactive mode #####
        print STDERR "ANALYSIS: Interactive analysis mode specified.\n";
        print STDERR "TO SUBMIT: csh $outscript @$aargu\n\n";
    }
    elsif ( substr( $mode, 0, 1 ) eq "o" ) {
        ####### The graphical analysis is specified in online mode ######
        print STDERR "ANALYSIS: Online analysis mode specified.\n";
        my $scriptoutput = `$outscript @$argu`;
        print "$scriptoutput\n";
    }
    elsif ( !$opt_s ) {
        print STDERR "ANALYSIS: Batch mode specified.\n";

        print STDERR "TO SUBMIT: $batch_command\n\n";
    }
    else {
        ####### The graphical analysis is specified in batch mode ######
        sleep 3;
        print STDERR "Submitting '$batch_command'\n";

        my $message = `$batch_command`;
        print $message;
    }

} ## end sub writescript

#---- find out all the availablechunks from first file to last file. Missing chunks
# in between are not checked, but the chunks with unexpected chunklength are excluded.

sub availablechunks {
    my @availablechunksfirst = ();
    my @availablechunkslast  = ();
    my ( $asrcdir, $component, $clnumber, $src ) = @_;

    #my @existingall = <$asrcdir/$component.*.nc>; #unacceptable performance on the pp/an nodes
    opendir( my $dh, "$asrcdir" );
    my @existingall
        = map { $_ =~ s/(.*)/$asrcdir\/$1/; $_; } sort( grep {/$component.*.nc$/} readdir($dh) );
    closedir($dh);

    #print "existingall has this many members: $#existingall\n";
    #print "existingall[0] is $existingall[0]\n";

    if ( @existingall < 1 ) {

        #my @cpios = <$asrcdir/$component.*.nc.cpio>;
        opendir( my $dh, "$asrcdir" );
        my @cpios = map { $_ =~ s/(.*)/$asrcdir\/$1/; $_; }
            sort( grep {/$component.*.nc.cpio/} readdir($dh) );
        closedir($dh);
        if ( @cpios < 1 ) {
            print STDERR "ANALYSIS: No .nc or .nc.cpio files found in: $asrcdir\n";
        }
        else {
            print STDERR "ANALYSIS: No nc files found in: $asrcdir\n";
            print STDERR
                "ANALYSIS: Try extracting the necessary cpio files in this directory first.\n";
        }
        return;
    }

    # find the first variable, but don't use it for checking date availability
    my @myvars = split( /\./, $existingall[0] );
    my $thevar = $myvars[ $#[myvars] - 2 ];

    my @existingdates = map { $_ =~ s/$asrcdir\/$component\.(.*?)\.(.*)\.nc/$1/; $_; } @existingall;

    my %tmphash = ();
    @tmphash{@existingdates} = ();
    my @existing = sort keys %tmphash;

    # loop through all the files(chunks) of $thevar
    foreach my $last (@existing) {
        my $first = $last;

        if ( $src =~ /hr$/ ) {
            $last =~ s/..........-//;
            $first =~ s/-..........//;
        }

        elsif ( $src =~ /daily$/ ) {
            $last =~ s/........-//;
            $first =~ s/-........//;
        }

        elsif ( $src =~ /monthly$/ and $thevar ne "01" ) {
            $last =~ s/......-//;
            $first =~ s/-......//;
        }
        else {
            $last =~ s/....-//;
            $first =~ s/-....//;
        }

        if ( substr( $last, 0, 4 ) - substr( $first, 0, 4 ) == $clnumber - 1 ) {
            @availablechunksfirst = ( @availablechunksfirst, substr( $first, 0, 4 ) );
            @availablechunkslast  = ( @availablechunkslast,  substr( $last,  0, 4 ) );
        }
        elsif ( ( substr( $last, 0, 6 ) - substr( $first, 0, 6 ) ) % 100 == 99 ) {
            @availablechunksfirst = ( @availablechunksfirst, substr( $first, 0, 6 ) );
            @availablechunkslast  = ( @availablechunkslast,  substr( $last,  0, 6 ) );
        }
    } ## end foreach my $last (@existing)

    return \@availablechunksfirst, \@availablechunkslast;
} ## end sub availablechunks

sub checkmissingchunks {

    # now check for the missing chunks
    my ( $databegyr, $dataendyr, $clnumber, $pt, $availablechunksfirst_ref ) = @_;
    my @chunks = @$availablechunksfirst_ref;

    my @themissing = ();
    my $count      = $pt;
    my $month      = substr( $chunks[$pt], 4, 2 );

#print "CHECKMISSINGCHUNKS: databegyr=$databegyr,dataendyr=$dataendyr,clnumber=$clnumber,month='$month',pt=$pt,chunks=$chunks\n";

    for ( my $check = $databegyr; $check <= $dataendyr; $check += $clnumber ) {

        #print "CHECKMISSINGCHUNKS: $check"."$month ne ".substr($chunks[$count],0,6)."\n";
        if ( padzeros($check) . $month != substr( $chunks[$count], 0, 6 ) ) {
            @themissing = ( @themissing, $check );
        }
        if ( "$month" eq '' and $count >= @chunks ) { last; }    #works for models starting in Jan
        $count++;
        if ( "$month" ne '' and $count >= @chunks ) { last; }  #works for models NOT starting in Jan
    }
    return @themissing;
} ## end sub checkmissingchunks

sub filltemplate {

    # fill the template with the passing variables
    my ($arrayofExptsH_ref, $figureDir, $aScript,  $aargu,     $aScriptout,
        $iExpt,             $workdir,   $mode,     $asrcfile,  $opt_s,
        $opt_u,             $opt_V,     $frexml,   $stdoutdir, $platform,
        $target,            $experID,   $realizID, $runID
    ) = @_;

    #if ( $opt_V ) {
    #   for(my $j=0; $j<2;$j++) {
    #      while(($key,$value) = each %{$arrayofExptsH_ref->[$j]} ) {
    #         print STDERR "$key -- $value\n";
    #      }
    #      print STDERR "\n";
    #   }
    #   print STDERR "in filltemplate: iExpt=$iExpt\n\n";
    #}

#    my ($aScriptout,$aScript, $workdir, $mode, $momGrid,$gridspec,$staticfile,$asrcdir,$asrcfile,$expt,$figureDir,$astartYear,$aendYear,$databegyr,$dataendyr,$clnumber,$specify1year,$archivedir) = @_;
    my $printout = "$aScriptout.printout"
        ;    #change this to send the stdout to stdoutdir... but will break analysis scripts. -arl
    chomp( my $scriptexists = `[ -f "$aScript" ] && echo exists` );
    unless ( $scriptexists eq "exists" ) {
        print "ERROR: Analysis script doesn't exist: '$aScript'\n";
        print
            "       Check that all variables are set. The fre-analysis module may need to be loaded.\n";
        exit 1;
    }

    # convert MOAB headers
    my $tmpcsh;
    if (system "grep '#SBATCH' $aScript") {
        print STDERR <<EOF;

NOTICE: Analysis script $aScript
NOTICE: doesn't have Slurm headers, so it be will be passed through
NOTICE: the converter utility 'convert-moab-headers', then submitted to Slurm.
NOTICE: However, please convert this script's MOAB headers to Slurm
NOTICE: as soon as convenient. For help adding Slurm headers,
NOTICE: try 'convert-moab-headers old_script > new_script',
NOTICE: and refer to the Moab-to-Slurm wiki:
NOTICE: http://wiki.gfdl.noaa.gov/index.php/Moab-to-Slurm_Conversion

EOF
        $tmpsch = `convert-moab-headers $aScript`;
    }
    else {
        $tmpsch = `cat $aScript`;
    }

    my $fremodule         = `echo \$LOADEDMODULES | tr ':' '\n' | egrep '^fre/.+'`;
    my $freanalysismodule = `echo \$LOADEDMODULES | tr ':' '\n' | egrep '^fre-analysis/.+'`;

    #
    $tmpsch =~ s/#PBS -o.*/#PBS -o $printout/;
    $tmpsch =~ s/(#SBATCH --output).*/$1=$printout/;
    $tmpsch =~ s/(#SBATCH -o).*/$1 $printout/;
    $tmpsch =~ s/set WORKDIR\s*$/set WORKDIR = $workdir/m;

    # a1r edit ln below
    $tmpsch =~ s/WORKDIR = ""\s*$/WORKDIR = \"$workdir\"/m;
    $tmpsch =~ s/set mode\s*$/set mode = $mode/m;

    # a1r edit ln below
    $tmpsch =~ s/mode = ""\s*$/mode = \"$mode\"/m;
    $tmpsch =~ s/set out_dir\s*$/set out_dir = $figureDir/m;

    # a1r edit ln below
    $tmpsch =~ s/out_dir = ""\s*$/out_dir = \"$figureDir\"/m;
    $tmpsch =~ s/set printout\s*$/set printout = $printout/m;

    # a1r edit ln below
    $tmpsch =~ s/printout = ""\s*$/printout = \"$printout\"/m;

    #----
    $tmpsch =~ s/set freq\s*$/set freq = $arrayofExptsH_ref->[0]->{freq}/m;

    #a1r edit ln below
    $tmpsch =~ s/freq = ""\s*$/freq = \"$arrayofExptsH_ref->[0]->{freq}\"/m;
    $tmpsch
        =~ s/set MODEL_start_yr\s*$/set MODEL_start_yr = $arrayofExptsH_ref->[0]->{MODEL_start_yr}/m;
    $tmpsch =~ s/set mom_version\s*$/set mom_version = $arrayofExptsH_ref->[0]->{momGrid}/m;
    $tmpsch =~ s/set gridspecfile\s*$/set gridspecfile = $arrayofExptsH_ref->[0]->{gridspec}/m;
    $tmpsch =~ s/set staticfile\s*$/set staticfile = $arrayofExptsH_ref->[0]->{staticfile}/m;
    $tmpsch =~ s/set argu\s*$/set argu = (@$aargu)/m;

    #a1r edit ln below
    $tmpsch =~ s/argu = ""\s*$/argu = \"(@$aargu)\"/m;
    $tmpsch =~ s/set in_data_dir\s*$/set in_data_dir = $arrayofExptsH_ref->[0]->{asrcdir}/m;

    #a1r edit ln below
    $tmpsch =~ s/in_data_dir = ""\s*$/in_data_dir = \"$arrayofExptsH_ref->[0]->{asrcdir}\"/m;

    #$tmpsch =~ s/set in_data_file/set in_data_file = $arrayofExptsH_ref->[0]->{asrcfile}/m;
    $tmpsch =~ s/set in_data_file\s*$/set in_data_file = $asrcfile/m;

    #a1r edit ln below
    $tmpsch =~ s/in_data_file = ""\s*$/in_data_file = \"$asrcfile\"/m;

    $tmpsch =~ s/set descriptor\s*$/set descriptor = $arrayofExptsH_ref->[0]->{exptname}/m;

    #a1r edit ln below
    $tmpsch =~ s/descriptor = ""\s*$/descriptor = \"$arrayofExptsH_ref->[0]->{exptname}\"/m;
    $tmpsch =~ s/set yr1\s*$/set yr1 = $arrayofExptsH_ref->[0]->{astartYear}/m;

    #a1r edit ln below
    $tmpsch =~ s/yr1 = ""\s*$/yr1 = \"$arrayofExptsH_ref->[0]->{astartYear}\"/m;
    $tmpsch =~ s/set yr2\s*$/set yr2 = $arrayofExptsH_ref->[0]->{aendYear}/m;

    #a1r edit ln below
    $tmpsch =~ s/yr2 = ""\s*$/yr2 = \"$arrayofExptsH_ref->[0]->{aendYear}\"/m;
    $tmpsch =~ s/set databegyr\s*$/set databegyr = $arrayofExptsH_ref->[0]->{databegyr}/m;

    #a1r edit ln below
    $tmpsch =~ s/databegyr = ""\s*$/databegyr = \"$arrayofExptsH_ref->[0]->{databegyr}\"/m;
    $tmpsch =~ s/set dataendyr\s*$/set dataendyr = $arrayofExptsH_ref->[0]->{dataendyr}/m;

    #a1r edit ln below
    $tmpsch =~ s/dataendyr = ""\s*$/dataendyr = \"$arrayofExptsH_ref->[0]->{dataendyr}\"/m;
    $tmpsch =~ s/set datachunk\s*$/set datachunk = $arrayofExptsH_ref->[0]->{clnumber}/m;

    #a1r edit ln below
    $tmpsch =~ s/datachunk = ""\s*$/datachunk = \"$arrayofExptsH_ref->[0]->{clnumber}\"/m;

    # specify_yr is a particular year, set by user, for daily data
    $tmpsch =~ s/set specify_yr\s*$/set specify_yr = $arrayofExptsH_ref->[0]->{specify1year}/m;
    $tmpsch =~ s/set hist_dir\s*$/set hist_dir = $arrayofExptsH_ref->[0]->{hist_dir}/m;
    $tmpsch =~ s/set nlon\s*$/set nlon = $arrayofExptsH_ref->[0]->{nlon}/m;
    $tmpsch =~ s/set nlat\s*$/set nlat = $arrayofExptsH_ref->[0]->{nlat}/m;
    $tmpsch =~ s/set frexml\s*$/set frexml = $frexml/m;
    $tmpsch =~ s/set fremodule\s*$/set fremodule = $fremodule/m;

    #a1r edit ln below
    $tmpsch =~ s/fremodule = ""\s*$/fremodule = \"$fremodule\"/m;
    $tmpsch =~ s/set freanalysismodule\s*$/set freanalysismodule = $freanalysismodule/m;
    $tmpsch =~ s/set stdoutdir\s*$/set stdoutdir = $stdoutdir/m;
    $tmpsch =~ s/setenv FREROOT.*/setenv FREROOT $ENV{FREROOT}/m;
    $tmpsch
        =~ s/set analysis_options\s*$/set analysis_options = $arrayofExptsH_ref->[0]->{options}/m;

    #a1r edit ln below
    $tmpsch
        =~ s/analysis_options = ""\s*$/analysis_options = \"$arrayofExptsH_ref->[0]->{options}\"/m;
    $tmpsch =~ s/set platform\s*$/set platform = $platform/m;
    $tmpsch =~ s/set target\s*$/set target = $target/m;
    $tmpsch =~ s/set unique\s*$/set unique = $opt_u/m;

    #eem tripleID implementation

    $tmpsch =~ s/set experID\s*$/set experID = $experID/m;
    $tmpsch =~ s/experID = ""\s*$/experID = \"$experID\"/m;
    $tmpsch =~ s/set realizID\s*$/set realizID = $realizID/m;
    $tmpsch =~ s/realizID = ""\s*$/realizID = \"$realizID\"/m;
    $tmpsch =~ s/set runID\s*$/set runID = $runID/m;
    $tmpsch =~ s/runID = ""\s*$/runID = \"$runID\"/m;
    $tmpsch =~ s/set tripleID\s*$/set tripleID = $experID$realizID$runID/m;
    $tmpsch =~ s/tripleID = ""\s*$/tripleID = \"$experID$realizID$runID\"/m;

    # for addtional experiments
    if ( $iExpt >= 1 ) {
        for my $i ( 1 .. $iExpt ) {
            my $ii = $i + 1;

            $tmpsch
                =~ s/set MODEL_start_yr_$ii\s*$/set MODEL_start_yr_$ii = $arrayofExptsH_ref->[0]->{MODEL_start_yr}/m;
            $tmpsch
                =~ s/set mom_version_$ii\s*$/set mom_version_$ii = $arrayofExptsH_ref->[$i]->{momGrid}/m;
            $tmpsch
                =~ s/set gridspecfile_$ii\s*$/set gridspecfile_$ii = $arrayofExptsH_ref->[$i]->{gridspec}/m;
            $tmpsch
                =~ s/set staticfile_$ii\s*$/set staticfile_$ii = $arrayofExptsH_ref->[$i]->{staticfile}/m;
            $tmpsch
                =~ s/set in_data_dir_$ii\s*$/set in_data_dir_$ii = $arrayofExptsH_ref->[$i]->{asrcdir}/m;

   #$tmpsch =~ s/set in_data_file_$ii/set in_data_file_$ii = $arrayofExptsH_ref->[$i]->{asrcfile}/m;
            $tmpsch =~ s/set in_data_file_$ii\s*$/set in_data_file_$ii = $asrcfile/m;
            $tmpsch
                =~ s/set descriptor_$ii\s*$/set descriptor_$ii = $arrayofExptsH_ref->[$i]->{exptname}/m;
            $tmpsch =~ s/set yr1_$ii\s*$/set yr1_$ii = $arrayofExptsH_ref->[$i]->{astartYear}/m;
            $tmpsch =~ s/set yr2_$ii\s*$/set yr2_$ii = $arrayofExptsH_ref->[$i]->{aendYear}/m;
            $tmpsch
                =~ s/set databegyr_$ii\s*$/set databegyr_$ii = $arrayofExptsH_ref->[$i]->{databegyr}/m;
            $tmpsch
                =~ s/set dataendyr_$ii\s*$/set dataendyr_$ii = $arrayofExptsH_ref->[$i]->{dataendyr}/m;
            $tmpsch
                =~ s/set datachunk_$ii\s*$/set datachunk_$ii = $arrayofExptsH_ref->[$i]->{clnumber}/m;

            # specify_yr is a particular year, set by user, for daily data
            $tmpsch
                =~ s/set specify_yr_$ii\s*$/set specify_yr_$ii = $arrayofExptsH_ref->[0]->{specify1year}/m;
            $tmpsch
                =~ s/set hist_dir_$ii\s*$/set hist_dir_$ii = $arrayofExptsH_ref->[$i]->{hist_dir}/m;
            $tmpsch =~ s/set nlon_$ii\s*$/set nlon_$ii = $arrayofExptsH_ref->[$i]->{nlon}/m;
            $tmpsch =~ s/set nlat_$ii\s*$/set nlat_$ii = $arrayofExptsH_ref->[$i]->{nlat}/m;
        } ## end for my $i ( 1 .. $iExpt)
    } ## end if ( $iExpt >= 1 )

    writescript( $tmpsch, $mode, $aScriptout, $aargu, $opt_s );
} ## end sub filltemplate

sub adjYearlow {

    # adjust data-beging-year to the beginging/endding of a data chunk
    my ( $edgeYear, @chunkedge ) = @_;

    foreach my $datachunk (@chunkedge) {
        my $edge = substr( $datachunk, 0, 4 );

        if ( $edgeYear < $edge ) { last; }
        elsif ( $edgeYear == $edge ) { $dataendyr = $edge; last; }
        else                         { $dataendyr = $edge; }

    }
    return $dataendyr;
}

sub adjYearhigh {

    # adjust data-beging-year to the beginging/endding of a data chunk
    my ( $edgeYear, @chunkedge ) = @_;

    foreach my $datachunk (@chunkedge) {
        my $edge = substr( $datachunk, 0, 4 );

        if    ( $edgeYear < $edge )  { $dataendyr = $edge; last; }
        elsif ( $edgeYear == $edge ) { $dataendyr = $edge; last; }
        else                         { $dataendyr = $edge; }

    }
    return $dataendyr;
}

sub queueAnaAttr {
    my $anaNode = $_[0];

    my $switch = $anaNode->findvalue('@switch');
    if ( !$switch ) { $switch = "on" }
    my $mode = $anaNode->findvalue('@mode');
    if ( !$mode or $mode eq "" ) { $mode = "batch"; }
    my $cumulative = $anaNode->findvalue('@cumulative');
    my $momGrid    = $anaNode->findvalue('@momGrid');
    if ( !$momGrid or $momGrid eq "" ) { $momGrid = "om3"; }
    my $figureDir = $anaNode->findvalue('@outdir');

    #----find out user specified one particular year
    my $specify1year = $anaNode->findvalue('@specify1year');

    #----find out user specified start year and end year
    my $astartYear = $anaNode->findvalue('@startYear');
    my $aendYear   = $anaNode->findvalue('@endYear');
    my $chunk      = $anaNode->findvalue('@chunkLength') || $anaNode->findvalue('@interval');

    my $afreq = $anaNode->findvalue('@DeltaInterval');
    if ( !$afreq ) { $afreq = 1 }

    my $name     = $anaNode->findvalue('@name');
    my $xml      = $anaNode->findvalue('@xmlfile');
    my $platform = $anaNode->findvalue('@platform');
    my $target   = $anaNode->findvalue('@target');

    my $script = $anaNode->findvalue('@script');

    my $options = $anaNode->findvalue('@options');

    return (
        'switch'     => $switch,
        mode         => $mode,
        cumulative   => $cumulative,
        momGrid      => $momGrid,
        figureDir    => $figureDir,
        specify1year => $specify1year,
        astartYear   => $astartYear,
        aendYear     => $aendYear,
        chunk        => $chunk,
        afreq        => $afreq,
        exptname     => $name,
        xmlfile      => $xml,
        platform     => $platform,
        target       => $target,
        script       => $script,
        options      => $options
    );
} ## end sub queueAnaAttr

sub seasonAV {

    # season is used for finding chunks
    # ssn is for output files
    my $frequency = $_[0];

    my $season;
    my $ssn;
    if ( $frequency eq "monthly" ) {
        $season = "01";
        $ssn    = "{01,02,03,04,05,06,07,08,09,10,11,12}";
    }
    elsif ( $frequency eq "seasonal" ) {
        $season = "DJF";
        $ssn    = "{DJF,MAM,JJA,SON}";
    }
    elsif ( $frequency eq "annual" ) {
        $season = "ann";
        $ssn    = "{ann}";
    }
    return $season, $ssn;

} ## end sub seasonAV

sub start_end_date {

    # $astartYear (input/output): start date. Always use $opt_Y if exist.
    #                     Set to first available chunk year if not specified by user.
    # $aendYear (input/output): end date
    # $databegyr (output): data start date. Low edge of $astartYear
    # $dataendyr (output): data end date. High edge of $aendYear

    my ( $astartYear, $aendYear, $opt_Y, $opt_Z, $availablechunksfirst_ref,
        $availablechunkslast_ref, $clnumber )
        = @_;

    my @availablechunksfirst = @$availablechunksfirst_ref;
    my @availablechunkslast  = @$availablechunkslast_ref;
    my $flag                 = "good";

    # If user did not specify a start or end year, the start or end year
    # will be first year of the first available chunk and
    # the last year of the last available chunk

    my $first0 = $availablechunksfirst[0];
    my $last0  = $availablechunkslast[$#availablechunkslast];
    if ( !$astartYear ) { $astartYear = substr( $first0, 0, 4 ) }
    if ( !$aendYear )   { $aendYear   = substr( $last0,  0, 4 ) }

    if ( length($astartYear) < 4 ) { $astartYear = padzeros($astartYear); }
    if ( length($aendYear) < 4 )   { $aendYear   = padzeros($aendYear); }

    # taking years from command line if exist
    if ($opt_Y) { $astartYear = $opt_Y; }
    if ($opt_Z) { $aendYear   = $opt_Z; }

    if ( $astartYear > $aendYear ) {
        print STDERR
            "ANALYSIS: Date setting ERROR: begin year $astartYear larger than ending year $aendYear\n";
        $flag = "bad";
        return $flag;
    }

    #### adjust start and end date if necessary

    # If user specified a start year earlier than the first available year, set to the
    # first available year
    if ( $astartYear < substr( $availablechunksfirst[0], 0, 4 ) ) {
        print STDERR "ANALYSIS: analysis starts from $availablechunksfirst[0]\n";
        print STDERR "ANALYSIS: years before $availablechunksfirst[0] skipped\n";
        $astartYear = $availablechunksfirst[0];
    }

    #     # If user specified an end year later than the last available year, set to the
    #     # last available year
    #     if ($aendYear > substr($availablechunkslast[$#availablechunkslast],0,4) ) {
    #        print STDERR "analysis ended at year $availablechunksfirst[0]\n";
    #        $aendYear = $availablechunkslast[$#availablechunkslast];}

    $astartYear = substr( $astartYear, 0, 4 );
    $aendYear   = substr( $aendYear,   0, 4 );

    if ($opt_V) {
        print STDERR "ANALYSIS: user specified start and end year: $astartYear - $aendYear\n";
    }

    # user specified years do not have to be on the begin or end of data chunks
    #----#---- data period needed for the start year
    my $databegyr = padzeros( adjYearlow( $astartYear, @availablechunksfirst ) );
    if ( !$databegyr ) { print STDERR "ANALYSIS: No required data available\n"; next; }

    #     #----#---- data period needed for the end year
    #     my $dataendyr = adjYearhigh($aendYear,@availablechunkslast);
    #     if (!$dataendyr) {print STDERR "No data available\n";next;}
    #my $dataendyr = $aendYear - $aendYear  % $clnumber +  $clnumber;
    my $dataendyr;
    my $reminder = ( $aendYear - $availablechunkslast[0] ) % $clnumber;
    if ( $reminder == 0 ) {
        $dataendyr = padzeros($aendYear);
    }
    else {
        $dataendyr = padzeros( $aendYear + $clnumber - $reminder );
    }

    #find the position of the user specified start year in availablechunksfirst
    my $pt = -1;
    for ( my $index = 0; $index <= @availablechunksfirst; $index++ ) {
        if ( substr( $availablechunksfirst[$index], 0, 4 ) == $databegyr ) {
            $pt = $index;
            last;
        }
    }

    if ( $pt < 0 ) {
        print "ANALYSIS: No chunks available for analysis\n";
        $flag = "bad";
        return $flag;
    }

    # now check for the missing chunks
    my @themissing
        = checkmissingchunks( $databegyr, $dataendyr, $clnumber, $pt, \@availablechunksfirst );

    #if (@themissing > 0) {
    #   print STDERR "Analysis: cannot process timeSeries, missing these chunks: @themissing. \n";
    #}

    if ($opt_V) {
        print STDERR
            "ANALYSIS: data needed for the start year and end year: $databegyr - $dataendyr\n";
    }

    return $flag, $astartYear, $aendYear, $databegyr, $dataendyr, @themissing;
} ## end sub start_end_date

#gets a value from xml, recurse using @inherit and optional second argument $expt
sub getxpathval {
    my $path = $_[0];
    my $e    = $expt;
    if ( $_[1] ) { $e    = $_[1]; }
    if ( $_[2] ) { $root = $_[2]; }
    checkExptExists($e);
    my $value = $root->findvalue("experiment[\@label='$e' or \@name='$e']/$path");
    $value =~ s/\$root/$rootdir/g;
    $value =~ s/\$archive/$archivedir/g;
    $value =~ s/\$name/$e/g;
    $value =~ s/\$label/$e/g;

    if ( "$value" eq "" ) {
        my $mommy = $root->findvalue("experiment[\@label='$e' or \@name='$e']/\@inherit");
        if ( "$mommy" eq "" ) {
            return "";
        }
        else { return getxpathval( $path, $mommy ); }
    }
    else {
        return $value;
    }
} ## end sub getxpathval

#make sure experiment exists in xml
sub checkExptExists {
    my $e         = $_[0];
    my $exptNodes = $root->findnodes("experiment[\@label='$e' or \@name='$e']");
    my $nodecount = $exptNodes->size();
    if ( $nodecount eq 0 ) {
        mailuser("Experiment $e not found in your xml file $frexml.");
        print STDERR "ERROR: Experiment $e not found in your xml file $frexml.\n";
        return 0;
    }
    if ( $nodecount gt 1 ) {
        print STDERR
            "WARNING: Multiple experiments called $e were found in $frexml.\nWARNING: Using first instance.\n";
    }
    return 1;
}

#return the number of analysis nodes under the given Node
sub anodenum {
    my $tNode = $_[0];
    my $anum  = 0;
    foreach my $atNode ( $tNode->findnodes('analysis') ) {
        my $switch = $atNode->findvalue('@switch');
        if ( ( substr( $switch, 0, 2 ) ne "of" ) and ( substr( $switch, 0, 2 ) ne "OF" ) ) {
            $anum++;
        }
    }
    return $anum;
}

#manipulate /archive
sub acarch {
    my $cmd = $_[0];
    chomp( my $unamem = `uname -m` );

    if ( "$unamem" eq "i686" ) {
        system "rsh ac-arch '$cmd'";
    }
    else {
        system "$cmd";
    }
}

1;

sub cleanpath

    # ------ clean up a string that should be a filepath
{
    my $str = $_[0];
    $str =~ s/\n//g;
    $str =~ s/^\s*//;
    $str =~ s/\s*$//;
    $str =~ s/\/+/\//g;
    return $str;
}
