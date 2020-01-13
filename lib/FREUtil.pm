#
# $Id: FREUtil.pm,v 18.0.2.11.2.1.4.3 2014/10/15 17:10:58 Amy.Langenhorst Exp $
# ------------------------------------------------------------------------------
# FMS/FRE Project: Utilities Module
# ------------------------------------------------------------------------------
# Copyright (C) NOAA Geophysical Fluid Dynamics Laboratory, 2000-2012, 2016
# Designed and written by V. Balaji, Amy Langenhorst, Aleksey Yakovlev and
# Seth Underwood
#

package FREUtil;

use strict;

use POSIX qw(floor);
use File::Path();
use File::Spec();
use File::stat;
use Date::Manip();
use XML::LibXML();

# //////////////////////////////////////////////////////////////////////////////
# ////////////////////////////////////////////////////////// Global Constants //
# //////////////////////////////////////////////////////////////////////////////

use constant ARCHIVE_EXTENSION => qr/\.(?:nc\.cpio|cpio|nc\.tar|tar)/;
use constant MAPPING_SEPARATOR => ';';

# //////////////////////////////////////////////////////////////////////////////
# //////////////////////////////////////////////////////// Exported Functions //
# //////////////////////////////////////////////////////////////////////////////

#make sure experiment exists in xml
sub checkExptExists {
    my $e    = $_[0];
    my $omit = 0;
    if ( $_[1] ) { $omit = $_[1]; }
    my @exptNodes = $::root->findnodes("experiment[\@label='$e' or \@name='$e']");
    my $nodecount = scalar @exptNodes;
    if ( $nodecount eq 0 ) {
        print STDERR "ERROR: Experiment $e not found in your xml file $::opt_x.\n";
        return 0;
    }
    if ( $nodecount gt 1 ) {
        print STDERR
            "WARNING: Multiple experiments called $e were found in $::opt_x.\nWARNING: Using first instance.\n";
    }
    if ( !$omit and substr( $e, 0, 1 ) =~ /[0-9]/ ) {
        print STDERR
            "WARNING: Batch system does not accept jobs that start with a number.  Please change the name of experiment '$e' to start with a letter.\n";
    }

    return 1;
} ## end sub checkExptExists

#gets a value from xml, recurse using @inherit and optional second argument $expt
sub getxpathval {
    my $path = $_[0];
    my $e    = $::expt;
    if ( $_[1] ) { $e = $_[1]; }
    checkExptExists( $e, 1 );
    my $value = $::root->findvalue("experiment[\@label='$e' or \@name='$e']/$path");
    $value =~ s/\$root/$::rootdir/g;
    $value =~ s/\$FREROOT/$::rootdir/g;
    $value =~ s/\$archive/$::archivedir/g;
    $value =~ s/\$name/$e/g;
    $value =~ s/\$label/$e/g;

    if ( "$value" eq "" ) {
        my $mommy = $::root->findvalue("experiment[\@label='$e' or \@name='$e']/\@inherit");
        if ( "$mommy" eq "" ) {
            return "";
        }
        else {
            return getxpathval( $path, $mommy );
        }
    }
    else {
        return $value;
    }
} ## end sub getxpathval

#write c-shell runscript, chmod, and optionally submit
#batchCmd = "qsub -pe $defaultQueue $npes -o $stdoutPath -r y -P $project -l h_cpu=$maxRunTime"
#writescript($cshscript,$outscript,$batchCmd,$defaultQueue,$npes,$stdoutPath,$project,$maxRunTime);
sub writescript {

    #my $script = $_[0];
    my $outscript    = $_[1];
    my $batchCmd     = $_[2];
    my $defaultQueue = $_[3];
    my $npes         = $_[4];
    my $stdoutPath   = $_[5];
    my $project      = $_[6];
    my $maxRunTime   = $_[7];

    #if($::opt_v){print "$batchCmd\n";}

    if   ( "$defaultQueue" ne "" ) { $batchCmd =~ s/\$defaultQueue/$defaultQueue/g; }
    else                           { $batchCmd =~ s/\$defaultQueue//g; }
    if   ( "$npes" ne "" ) { $batchCmd =~ s/\$npes/$npes/g; }
    else                   { $batchCmd =~ s/\$npes//g; }
    if   ( "$stdoutPath" ne "" ) { $batchCmd =~ s/\$stdoutPath/$stdoutPath/g; }
    else                         { $batchCmd =~ s/\$stdoutPath//g; }
    if   ( "$project" ne "" ) { $batchCmd =~ s/\$project/$project/g; }
    else                      { $batchCmd =~ s/\$project//g; }
    if   ( "$maxRunTime" ne "" ) { $batchCmd =~ s/\$maxRunTime/$maxRunTime/g; }
    else                         { $batchCmd =~ s/\$maxRunTime//g; }

    #if($::opt_v){print "$batchCmd\n";}

    ( my $volume, my $directory, my $filename ) = File::Spec->splitpath($outscript);
    if ( !-e $directory ) { mkdir $directory || die "Cannot make directory $directory\n"; }

    open( OUT, "> $outscript" );
    print OUT $_[0];
    close(OUT);

    my $status = system("chmod 755 $outscript");
    if ($status) { die "Sorry, I couldn't chmod $outscript"; }

    if ($::opt_s) {
        if ($::opt_v) { print "\nExecuting '$batchCmd $outscript'\n"; }
        my $qsub_msg = `$batchCmd $outscript`;
        print "\n$qsub_msg";
    }
    else {
        print "\nTO SUBMIT: $batchCmd $outscript\n";
    }
} ## end sub writescript

# convert a date string following either yyyy or yyyymmddinto to a
# Date::Manip date ('yyyymmddhh:mm:ss')
#
# As we move forward to allow for years past 9999, we need to set some
# guidance on how the passed in date string is interpreted.  Thus, we
# somewhat arbitrarily decide that if length($opt_t) < 7, we assume a
# year has been passed in, 8 and beyond assume yyyymmdd.
sub parseDate {
    my $date        = $_[0];
    my $return_date = undef;

    # Variables to hold year and mmdd to allow for date verification
    my $year   = "";
    my $mmdd   = "";
    my $hhmmss = "00:00:00";

    if ( length($date) < 8 ) {

        # Assume only a year has been passed in, and the month/day/time is
        # 01 Jan @ 00:00:00
        #
        # This assumption works until year 10,000,000, which for most
        # cases is a good assumption.
        $year = $date;
        $mmdd = "0101";
    }
    elsif ( $date =~ /^(\d{4,}\d{2}\d{2})(\d{2}:\d{2}:\d{2})$/ ) {
        ( $year, $mmdd ) = splitDate($1);
        $hhmmss = $2;
    }
    else {
        ( $year, $mmdd ) = splitDate($date);
    }

    # Verify year is > 0
    if ( int($year) <= 0 ) {
        print STDERR "ERROR: Non-positive years are not supported.\n";
    }
    else {

        # Using Date::Manip::ParseDate to verify a valid date.  But since
        # Date::Manip cannot handle certain dates, we force to use a date
        # between years 2000 and 2999.
        my $vYear = 2000 + int($year) % 2000;
        my $vDate = sprintf( "%04d%04d%8s", $vYear, $mmdd, $hhmmss );
        if ( Date::Manip::ParseDate($vDate) eq '' ) {
            print STDERR "ERROR: Date '$date' is not a valid date.\n";
        }
        else {
            $return_date = sprintf( "%04d%04d%8s", $year, $mmdd, $hhmmss );
        }
    }
    return $return_date;
} ## end sub parseDate

#convert a fortran date string ( "1,1,1,0,0,0" ) to a Date::Manip date
sub parseFortranDate {
    my $date = $_[0];
    my @tmparray = split( ',|\s+', $date );

    if ( scalar(@tmparray) == 0 and $date =~ /^$/ ) {

        # $date is blank, set a valid date
        @tmparray = ( 1, 1, 1, 0, 0, 0 );
    }
    elsif ( scalar(@tmparray) != 6 ) {
        print STDERR "ERROR: Date '$date' is not a valid Fortran date string.\n";
        exit 1;
    }

    return sprintf( "%04d%02d%02d%02d:%02d:%02d", @tmparray );
}

#pad to 4 digits
sub padzeros {
    my $date = "$_[0]";
    return sprintf( "%04d", int($date) );
}

#pad to 2 digits
sub pad2digits {
    my $date = $_[0];
    return sprintf( "%02d", int($date) );
}

#pad to 8 digits
sub pad8digits {
    my $date = "$_[0]";
    return sprintf( "%08d", int($date) );
}

# splitDate separates a Date::Manip date string into yyyy and
# mmddhh or mmddhh:mm:ss components.
sub splitDate($) {
    my ($date) = @_;

    return $date =~ /^(\d{4,})(\d{4}(?:\d{2}:\d{2}:\d{2})?$)/;
}

# unixDate is a simplified version of Date::Manip::UnixDate.  This
# simplified version will only return the date using two formats:
#   "%Y%m%d", and
#   "%Y%m%d%H"
# The reason for this is some versions of Date::Manip::UnixDate cannot
# deal with year 0001 --- which is needed for several of the GFDL
# models.  The use of Date::Manip::UnixDate in FRE is to return one of
# these two formats.
# This subroutine expects $dateTime to be an the format:
#   /^\d{4,}\d{4}\d{2}:\d{2}:\d{2}$/
# or the routine will return undef.
sub unixDate($$) {
    my ( $dateTime, $format ) = @_;
    my $return = undef;    # The default return value.

    # Parse the dateTime string to verify it is in the proper format.
    if ( $dateTime !~ /^\d{4,}\d{2}\d{2}\d{2}:\d{2}:\d{2}$/ ) {
        print STDERR "WARNING: '$dateTime' is not recognized as a date format.\n";
    }
    else {

        # Separate the dateTime string into its components.  Separating into
        # all components in case this routine needs to be expanded to do more
        # than just the two formats.
        my @dateArray = $dateTime =~ /^(\d{4,})(\d{2})(\d{2})(\d{2}):(\d{2}):(\d{2})$/;
        if ( $format =~ /^%Y%m%d$/ ) {
            $return = "$dateArray[0]$dateArray[1]$dateArray[2]";
        }
        elsif ( $format =~ /^%Y%m%d%H$/ ) {
            $return = "$dateArray[0]$dateArray[1]$dateArray[2]$dateArray[3]";
        }
        else {

            # Return $dateTime if none of the formats match
            $return = $dateTime;
        }
    }
    return $return;
} ## end sub unixDate($$)

# Calculate the difference between two date and returns a Date::Manip
# delta format.  This is not a full wrapper for Date::Manip::DateCalc
# as we only use it to calculate the difference between two dates.
sub dateCalc($$) {
    my ( $date1, $date2 ) = @_;

    my $err = 0;

    if ( $date1 !~ /^\d{4,}\d{4}\d{2}:\d{2}:\d{2}$/ ) {
        print STDERR "WARNING: '$date1' is not recognized as a date format.\n";
        $err += 1;
    }
    if ( $date2 !~ /^\d{4,}\d{4}\d{2}:\d{2}:\d{2}$/ ) {
        print STDERR "WARNING: '$date2' is not recognized as a date format.\n";
        $err += 1;
    }
    if ( $err > 0 ) {
        return undef;
    }

    # Separate out the year from the mmddhh:mm:ss portion of the date.
    my ( $y1, $mdt1 ) = splitDate($date1);
    my ( $y2, $mdt2 ) = splitDate($date2);

    my $y2k = 2000;

    my $d1mult = floor( int($y1) / $y2k );
    my $d1modu = int($y1) % $y2k;
    my $d2mult = floor( int($y2) / $y2k );
    my $d2modu = int($y2) % $y2k;

    # Strings to hold the modified dates that are between the years 2000
    # and 2999.  This is needed due to issues in Date::Manip that cannot
    # deal with low dates (i.e. 00010101) or dates beyond 99991224.
    my $d1_2k = sprintf( "%04d%s", $y2k + int($d1modu), $mdt1 );
    my $d2_2k = sprintf( "%04d%s", $y2k + int($d2modu), $mdt2 );

    my $delta = Date::Manip::DateCalc( $d1_2k, $d2_2k, \$err, 1 );

    # year_mod hold a Date::Manip delta string that will be used to
    # take into account the change in year introduced by forcing the
    # first delta calculation to be done on years between 2000 and 2999.
    my $year_mod = sprintf( "%d:0:0:0:0:0:0", $y2k * ( $d2mult - $d1mult ) );

    return Date::Manip::DateCalc( $delta, $year_mod, \$err, 1 );
} ## end sub dateCalc($$)

# wrapper for DateCalc handling low year numbers
# modifydate takes a date (usually of format yyyymmddhh:mm:ss), and modifies it via the
# instructions in $str (i.e. +1 year, -1 second --- using the manipulation rules for
# Date::Manip.
sub modifydate {
    my $date = $_[0];
    my $str  = $_[1];
    my $err;
    if ( "$date" eq '' ) {

        # Force the date to be 0001010100:00:00 if $date is empty
        $date = "0001010100:00:00";
    }

    # Force the date to be in the correct format
    $date = parseDate($date);

    # Date::Manip handles dates in the range 01 Feb, 0001 to 30 Nov, 9999.  Because we could deal
    # with dates outside that range, we force all dates to be within the years 2000-2999 to overcome
    # Date::Manip's issues.
    my $y2k = 2000;

    if ( $date !~ /\d{4,}\d{4}\d{2}:\d{2}:\d{2}/ ) {
        print STDERR "NOTE: Date '$date' not in the correct format.  Expected 'yyyymmddhh:mm:ss'\n";
        return undef;
    }

# Parse $str for number of years to add.  There will be issues if adding more than 6000 or subtracting
# more than 2000 from the passed in date (because of how the date is forced to be between years [2000,3999].
# We need to do something similar if changing the date more than 2000 years.
    my ( $preStr, $pm, $dYears, $postStr ) = $str =~ /(.*?)([-+])\s*(\d+)\s*years?(.*)/i;
    my $dYearsMult = floor( int($dYears) / $y2k );
    my $dYearsMod  = int($dYears) % $y2k;

    # Amount to add/subtract at the end.
    my $newDeltaYears = eval("$pm 1 * ($dYearsMult * $y2k)");

    # New string to pass to Date::Manip::DateCalc
    my $newStr = ( $dYears !~ /^$/ ) ? "$preStr $pm $dYearsMod year $postStr" : $str;

    # Separate the passed in yyyy and mmddhh:mm:ss
    my ( $oYear, $oMDT ) = splitDate($date);

    # Save how many 2thousand years the passed in yyyy has
    my $yyyyMult = floor( int($oYear) / $y2k );

    # Get the yyyy in the range [2000,3999]
    my $yyyy2to4 = $y2k + int($oYear) % $y2k;

    # New date string to pass to Date::Manip
    my $dDate = $yyyy2to4 . $oMDT;

    my $dateManipd = Date::Manip::DateCalc( $dDate, $newStr, \$err );
    if ( "$err" ne "" ) {
        print STDERR
            "NOTE: Encountered Date::Manip problem with modifydate/DateCalc '$date' '$str': '$err'\n";
        return undef;
    }

    # Convert back to a date based on the original date
    my ( $nYear, $nMDT ) = splitDate($dateManipd);
    my $yyyy = sprintf( "%04d", $y2k * $yyyyMult + int($nYear) - $y2k + $newDeltaYears );
    if ( int($yyyy) < 1 ) {
        print STDERR "NOTE: Performing '$str' on '$date' does not give a valid year: got '$yyyy'\n";
        return undef;
    }

    return $yyyy . $nMDT;
} ## end sub modifydate

# Determine if a given year is a leap year
#
# This routine is to be used within FREUtil.pm.  This is why no checks
# are done to determine if the year passed in is valid.  The routine
# calling isaLeapYear should perform the validity check.
sub isaLeapYear($) {
    my ($year) = @_;

    my $return = 0;    # default: false

    if ( $year % 4 == 0 and ( $year % 400 == 0 or $year % 100 != 0 ) ) {
        $return = 1;    # true
    }

    return $return;
}

# Return number of days in month
#
# This routine is only to be used within FREUtil.pm.  This is why no
# checks are done to determine if the input month number is valid.
sub daysInMonth($) {
    my ($month) = @_;

    my @monthDays = qw/31 28 31 30 31 30 31 31 30 31 30 31/;

    return $monthDays[ $month - 1 ];
}

# Return the number of days from Jan 01 of the year given
#
# This routine is only to be used within FREUtil.pm, this is why we
# ignore checks to determine if the passed in date is valid
sub daysSince01Jan ($$$) {
    my ( $mon, $day, $year ) = @_;

    my $days = 0;

    for ( my $i = 1; $i < $mon; $i++ ) {
        $days += daysInMonth($i);
        if ( $i == 2 and isaLeapYear($year) ) {
            $days += 1;
        }
    }
    $days += $day;
}

# Wrapper to Date::Manip::Date_DaysSince1BC to deal with possible years beyond 9999
sub daysSince1BC($$$) {
    my ( $mon, $day, $year ) = @_;

    # Simple, non-exhaustive checks on the validity of the passed in
    # values.
    if ( $year <= 0 ) {
        print STDERR "NOTE: year ($year) must be a positive digit.\n";
        return undef;
    }
    if ( $mon < 1 || $mon > 12 ) {
        print STDERR "Note: Month must be in the range [1,12]\n";
        return undef;
    }
    if ( $day < 1 || $day > ( daysInMonth($mon) + isaLeapYear($year) ) ) {
        print STDERR "Note: Day must be in the range [1,", daysInMonth($mon) + isaLeapYear($year),
            "]\n";
        return undef;
    }

    # Number of full years
    my $compYears = $year - 1;

    # Number of leap years from 1BC to $compYears
    my $numLeapYears
        = floor( $compYears / 4 ) - floor( $compYears / 100 ) + floor( $compYears / 400 );

    # Number of days in complete years
    my $numDaysCompYears = 365 * $compYears + $numLeapYears;

    return $numDaysCompYears + daysSince01Jan( $mon, $day, $year );
} ## end sub daysSince1BC($$$)

# Wrapper for Date::Manip::Date_Cmp.  As Date_Cmp for DM5 "does little
# more than use 'cmp'." However, since cmp will not work as required if
# the two strings have different lengths, this wrapper uses cmp on the
# separate date components.
sub dateCmp ($$) {
    my ( $date1, $date2 ) = @_;

    my $return = 0;

    my ( $yr1, $mo1, $dy1, $hr1, $mn1, $sc1 )
        = $date1 =~ /^(\d{4,})(\d{2})(\d{2})(\d{2}):(\d{2}):(\d{2})$/;
    my ( $yr2, $mo2, $dy2, $hr2, $mn2, $sc2 )
        = $date2 =~ /^(\d{4,})(\d{2})(\d{2})(\d{2}):(\d{2}):(\d{2})$/;

    if ( int($yr1) == int($yr2) ) {
        if ( int($mo1) == int($mo2) ) {
            if ( int($dy1) == int($dy2) ) {
                if ( int($hr1) == int($hr2) ) {
                    if ( int($mn1) == int($mn2) ) {
                        $return = $sc1 cmp $sc2;
                    }
                    else {
                        $return = $mn1 cmp $mn2;
                    }
                }
                else {
                    $return = $hr1 cmp $hr2;
                }
            }
            else {
                $return = $dy1 cmp $dy2;
            }
        }
        else {
            $return = $mn1 cmp $mn2;
        }
    } ## end if ( int($yr1) == int(...))
    else {
        $return = $yr1 cmp $yr2;
    }
    return $return;
} ## end sub dateCmp ($$)

#return appropriate date granularity
sub graindate {
    my $date = $_[0];
    my $freq = $_[1];

    my $formatstr = "";

    if ( $freq =~ /(?>day|daily)/i ) {

        # Return yyyymmdd
        ($formatstr) = parseDate($date) =~ /^(\d{4,}\d{2}\d{2})\d{2}:\d{2}:\d{2}$/;
    }
    elsif ( $freq =~ /(?>mon|month|monthly)/i ) {

        # Return yyyymm
        ($formatstr) = parseDate($date) =~ /^(\d{4,}\d{2})\d{2}\d{2}:\d{2}:\d{2}$/;
    }
    elsif ( $freq =~ /(?>ann|annual|yr|year)/i ) {

        # Return yyyy
        ($formatstr) = parseDate($date) =~ /^(\d{4,})\d{2}\d{2}\d{2}:\d{2}:\d{2}$/;
    }
    elsif ( $freq =~ /(?>hr|hour)/i ) {

        # Return yyyymmddhh
        ($formatstr) = parseDate($date) =~ /^(\d{4,}\d{2}\d{2}\d{2}):\d{2}:\d{2}$/;
    }
    elsif ( $freq =~ /min$/i ) {

        # Return yyyymmddhhMM
        ($formatstr) = parseDate($date) =~ /^(\d{4,}\d{2}\d{2}\d{2}:\d{2}):\d{2}$/;
    }
    elsif ( $freq =~ /season/i ) {
        my ( $year, $month ) = parseDate($date) =~ /^(\d{4,})(\d{2})\d{2}\d{2}:\d{2}:\d{2}$/;
        unless ( int($month) % 3 == 0 ) {
            if ($::opt_v) {
                print STDERR
                    "WARNING: graindate: $month is not the beginning of a known season in date $date.\n";
            }
        }
        if ( $month == 12 ) {
            $year      = int($year) + 1;
            $year      = padzeros($year);
            $formatstr = "$year.DJF";
        }
        elsif ( $month == 1 or $month == 2 ) {
            $formatstr = "$year.DJF";
        }
        elsif ( $month == 3 or $month == 4 or $month == 5 ) {
            $formatstr = "$year.MAM";
        }
        elsif ( $month == 6 or $month == 7 or $month == 8 ) {
            $formatstr = "$year.JJA";
        }
        elsif ( $month == 9 or $month == 10 or $month == 11 ) {
            $formatstr = "$year.SON";
        }
        else {
            print STDERR "WARNING: graindate: month $month not recognized";

            # Return yyyymm
            ($formatstr) = parseDate($date) =~ /^(\d{4,}\d{2})\d{2}\d{2}:\d{2}:\d{2}$/;
        }
    } ## end elsif ( $freq =~ /season/i)
    else {
        print STDERR "WARNING: frequency not recognized in graindate\n";

        # Return yyyymmddhh
        ($formatstr) = parseDate($date) =~ /^(\d{4,}\d{2}\d{2}\d{2}):\d{2}:\d{2}$/;
    }

    return $formatstr;
} ## end sub graindate

#return appropriate abbreviation
sub timeabbrev {
    my $freq = $_[0];

    if ( "$freq" =~ /daily/ or "$freq" =~ /day/ ) {
        return "day";
    }
    elsif ( "$freq" =~ /mon/ ) {
        return "mon";
    }
    elsif ( "$freq" =~ /ann/ or "$freq" =~ /yr/ or "$freq" =~ /year/ ) {
        return "ann";
    }
    elsif ( "$freq" =~ /hour/ or "$freq" =~ /hr/ ) {
        $freq =~ s/hour/hr/;
        return $freq;
    }
    elsif ( "$freq" =~ /season/ ) {
        return "sea";
    }
    elsif ( $freq =~ /min$/ ) {
        return "min";
    }
    else {
        print STDERR "WARNING: frequency not recognized in timeabbrev\n";
        return "unknown";
    }
} ## end sub timeabbrev

#find correct postProcess node to use, following inherits
sub getppNode {
    my $e = $_[0];

    my $ppNode
        = $::root->findnodes("experiment[\@label='$e' or \@name='$e']/postProcess")->get_node(1);

    if ($ppNode) {
        return $ppNode;
    }
    else {
        my $mommy = $::root->findvalue("experiment[\@label='$e' or \@name='$e']/\@inherit");
        if ( "$mommy" eq "" ) {
            print STDERR "WARNING: Can't find postProcess node for experiment '$e'.\n";
            return "";
        }
        else {
            getppNode($mommy);
        }
    }
} ## end sub getppNode

sub cleanstr

    # ------ clean up a string that should be space delimited tokens
{
    my $str = $_[0];
    $str =~ s/\n/ /g;
    $str =~ s/^\s*//;
    $str =~ s/\s*$//;
    $str =~ s/,/ /g;
    $str =~ s/ +/ /g;
    return $str;
}

sub makeminutes($)

    # ------ arguments: $string
    # ------ translates $string in "HH:MM:SS" format to minutes integer
{
    my $timevar = $_[0];
    ( my $hr, my $min, my $sec ) = split( /:/, $timevar );
    unless ( "$sec" eq "00" ) {
        die "Who do you think you are, specifying seconds in your runTime??\n";
    }
    if ( "$hr" ne "00" ) {
        $min = $min + ( $hr * 60 );
    }
    return $min;
}

sub strStripPaired($;$)

    # ------ arguments: $string $pattern
    # ------ strip paired substrings, surrounding the $string
    # ------ all the heading and tailing whitespaces will be stripped as well
{
    my ( $s, $t ) = @_;
    my $p = ($t) ? qr/$t/ : '"';
    $s =~ s/^\s*$p(.*)$p\s*$/$1/s;
    return $s;
}

sub strFindByPattern($@)

    # ------ arguments: $mapping $key
{
    my ( $mapPattern, @keys ) = @_;
    my @mappings = split( MAPPING_SEPARATOR, $mapPattern );
    if ( scalar(@mappings) > 0 ) {
        my ( $result, $mappingPattern ) = ( '', qr/^(.*)\{\{(.*)\}\}$/ );
    MAPSEARCH: while (1) {
            my $mapping = shift @mappings;
            if ( scalar(@mappings) > 0 ) {
                if ( $mapping =~ m/$mappingPattern/ ) {
                    my ( $value, $key ) = ( $1, $2 );
                    foreach my $k (@keys) {
                        if ( $k =~ m/$key/m ) {
                            $result = $value;
                            last MAPSEARCH;
                        }
                    }
                }
                else {
                    $result = '';
                    last MAPSEARCH;
                }
            }
            else {
                $result = $mapping;
                last MAPSEARCH;
            }
        } ## end MAPSEARCH: while (1)
        return $result;
    } ## end if ( scalar(@mappings)...)
    else {
        return '';
    }
} ## end sub strFindByPattern($@)

sub strFindByInterval($$)

    # ------ arguments: $mapping $number
{
    my ( $m, $n ) = @_;
    my @mappings = split( MAPPING_SEPARATOR, $m );
    if ( scalar(@mappings) > 0 ) {
        my ( $result, $mappingPattern ) = ( '', qr/^(.*)\{\{(\d+)\}\}$/ );
        while (1) {
            my $mapping = shift @mappings;
            if ( scalar(@mappings) > 0 ) {
                if ( $mapping =~ m/$mappingPattern/ ) {
                    my ( $value, $key ) = ( $1, $2 );
                    if ( $n <= $key ) {
                        $result = $value;
                        last;
                    }
                }
                else {
                    $result = '';
                    last;
                }
            }
            else {
                $result = $mapping;
                last;
            }
        } ## end while (1)
        return $result;
    } ## end if ( scalar(@mappings)...)
    else {
        return '';
    }
} ## end sub strFindByInterval($$)

sub listUnique(@)

    # ------ arguments: @list
    # ------ return the argument @list with all the duplicates removed
{
    my @result = ();
    foreach my $e (@_) { push @result, $e unless grep( $_ eq $e, @result ) }
    return @result;
}

sub listDuplicates(@)

    # ------ arguments: @list
    # ------ return the all the duplicates found in the argument @list
{
    my @result = ();
    foreach my $e (@_) { push @result, $e if grep( $_ eq $e, @_ ) > 1 }
    return FREUtil::listUnique(@result);
}

sub fileOwner($)

    # ------ arguments: $filename
    # ------ returns owner of the $filename
{
    my $stat = stat(shift);
    return getpwuid( $stat->File::stat::uid );
}

sub fileIsArchive($)

    # ------ arguments: $filename
    # ------ returns 1 if the $filename is archive
{
    my ( $p, $e ) = ( shift, FREUtil::ARCHIVE_EXTENSION );
    return ( $p =~ m/$e$/ );
}

sub fileArchiveExtensionStrip($)

    # ------ arguments: $filename
    # ------ returns the $filename with archive extension stripped
{
    my ( $p, $e ) = ( shift, FREUtil::ARCHIVE_EXTENSION );
    $p =~ s/$e$//;
    return $p;
}

sub createDir($)

    # ------ arguments: $dirName
    # ------ create a (multilevel) directory, passed as an argument
    # ------ return the created directory or an empty value
{
    my ( $d, $v ) = @_;
    my ( $dirAbs, @dirs ) = ( File::Spec->rel2abs($d), () );
    eval { @dirs = File::Path::mkpath($dirAbs) };
    if ($@) {
        return '';
    }
    elsif ( scalar(@dirs) > 0 ) {
        return $dirs[$#dirs];
    }
    else {
        return $dirAbs;
    }
}

sub dirContains($$)

    # ------ arguments: $dirName $string
    # ------ return a number of times the $string is contained in the $dirName
{
    my ( $d, $s ) = @_;
    my @dlist = split( '/', $d );
    return scalar( grep( $_ eq $s, @dlist ) );
}

sub environmentVariablesExpand($)

    # ------ arguments: $string
    # ------ expand environment variable placeholders in the given $string
{
    my $s = shift;
    foreach my $k ( 'HOME', 'USER', 'ARCHIVE' ) {
        last if $s !~ m/\$/;
        if ( exists( $ENV{$k} ) ) {
            my $v = $ENV{$k};
            $s =~ s/\$(?:$k|\{$k\})/$v/g;
        }
    }
    return $s;
}

sub timeString

    # ------ arguments: $timeString (optional)
    # ------ converts time to a human-decipherable string
    # ------ suitable for use in a filename (sortable, no spaces, colons, etc)
    # ------ resolution of seconds
{
    my $time = shift || time();    # ------ use current time by default
    my @time = localtime($time);
    return (  19000000 + $time[5] * 10000
            + ( $time[4] + 1 ) * 100
            + $time[3]
            + $time[2] * 0.01
            + $time[1] * 0.0001
            + $time[0] * 0.000001 );
}

sub jobID()

    # ------ arguments: none
    # ------ return the current job id, if it's available
{
    if ( exists $ENV{SLURM_JOB_ID} ) {
        return $ENV{SLURM_JOB_ID}
    }
    elsif ( exists $ENV{JOB_ID} ) {
        return $ENV{JOB_ID};
    }
    elsif ( exists $ENV{PBS_JOBID} ) {
        return $ENV{PBS_JOBID};
    }
    else {
        return '000000';
    }
}

sub home()

    # ------ arguments: none
{
    return $ENV{FRE_COMMANDS_HOME};
}

sub optionIntegersListParse($$)

    # ------ arguments: $name $value
{
    my ( $n, $v ) = @_;
    if ( substr( $v, 0, 1 ) ne '-' ) {
        my ( $valuesAll, %valuesHash ) = ( 0, () );
        foreach my $value ( split( ',', $v ) ) {
            if ( $value eq 'all' ) {
                $valuesAll = 1;
            }
            elsif ( $value =~ m/^0*(\d+)$/ ) {
                $valuesHash{$1} = 1;
            }
            elsif ( $value =~ m/^0*(\d+)-0*(\d+)$/ ) {
                foreach my $i ( $1 .. $2 ) { $valuesHash{$i} = 1; }
            }
            else {
                return (
                    '',
                    "The --$n option values list contains an invalid value '$value'",
                    "Allowed list values are non-negative integers or pairs of non-negative integers, separated by dash, and 'all'"
                );
            }
        }
        my @values = ($valuesAll) ? 'all' : sort { $a <=> $b } keys(%valuesHash);
        return join( ',', @values );
    } ## end if ( substr( $v, 0, 1 ...))
    else {
        return ( '', "The --$n option value is missed" );
    }
} ## end sub optionIntegersListParse($$)

sub optionValuesListParse($$@)

    # ------ arguments: $name $value @allowedValuesList
{
    my ( $n, $v, @a ) = @_;
    if ( substr( $v, 0, 1 ) ne '-' ) {
        my ( $valuesAll, %valuesHash ) = ( 0, () );
        foreach my $value ( split( ',', $v ) ) {
            if ( $value eq 'all' ) {
                $valuesAll = 1;
            }
            elsif ( scalar( grep( $_ eq $value, @a ) ) > 0 ) {
                $valuesHash{$value} = 1;
            }
            else {
                my $allowed = join( "', '", @a );
                return (
                    '',
                    "The --$n option values list contains the unknown '$value' value",
                    "Allowed values are '$allowed' and 'all'"
                );
            }
        }
        my @values = ($valuesAll) ? @a : grep( $valuesHash{$_}, @a );
        return join( ',', @values );
    } ## end if ( substr( $v, 0, 1 ...))
    else {
        return ( '', "The --$n option value is missed" );
    }
} ## end sub optionValuesListParse($$@)

sub decodeChildStatus($$)

    # ------ arguments: $? $!
    # ------ returns decoded child process native error status as a string
    # ------ The child process native status is a word. The low order byte's
    # ------ lowest 7 bits hold the signal number if the child was terminated
    # ------ by a signal. The high order byte holds the exit status if the
    # ------ child exited. See ``perldoc -f system'' for more information.
{
    my ( $child_error, $os_error ) = @_;

    my $error_string;

    # Test if Perl couldn't process the system call
    if ( $child_error == -1 ) {
        $error_string = "failed to execute: $os_error";
    }

    # Test the low order 7 bits for signal number
    elsif ( $child_error & 0b01111111 ) {
        $error_string = "terminated for signal " . ( $child_error & 0b01111111 );
    }

    # Otherwise shift the exit status down a byte and return it
    else {
        $error_string = "exited with status " . ( $child_error >> 8 );
    }

    return $error_string;
} ## end sub decodeChildStatus($$)

# //////////////////////////////////////////////////////////////////////////////
# //////////////////////////////////////////////////////////// Initialization //
# //////////////////////////////////////////////////////////////////////////////

return 1;
