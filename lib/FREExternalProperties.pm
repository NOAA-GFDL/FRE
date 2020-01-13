#
# $Id: FREExternalProperties.pm,v 1.1.4.7 2013/03/01 19:46:51 afy Exp $
# ------------------------------------------------------------------------------
# FMS/FRE Project: External Properties Management Module
# ------------------------------------------------------------------------------
# afy    Ver   1.00  Initial version                                September 09
# afy -------------- Branch 1.1.4 --------------------------------- March 11
# afy    Ver   1.00  Module revived                                 March 11
# afy    Ver   2.00  Module redesigned as the FREProperties base    March 11
# afy    Ver   2.01  Modify placeholdersExpand (no envvars)         March 11
# afy    Ver   3.00  Cosmetics in the version log                   March 11
# afy    Ver   4.00  Modify propertiesExtract (conditionCheck)      November 11
# afy    Ver   5.00  Modify propertyInsert subroutine (no check)    December 11
# afy    Ver   5.01  Add propertyExists subroutine (check is here)  December 11
# afy    Ver   5.02  Modify propertiesExtract (call ^)              December 11
# afy    Ver   5.03  Modify propertiesExtract (verbosity)           December 11
# afy    Ver   5.04  Modify new (verbosity via argument)            December 11
# afy    Ver   5.05  Modify propertiesExtract (warnings => fatal)   December 11
# afy    Ver   6.00  Modify PROPERTY_NAME_PATTERN (allow colon)     September 12
# afy    Ver   6.01  Modify propertiesExtract (allow colon)         September 12
# afy    Ver   7.00  Remove PROPERTY_NAME_PATTERN                   February 13
# afy    Ver   7.01  Add FREExternalPropertiesNamePattern           February 13
# afy    Ver   7.02  Modify all the subs, using the name pattern    February 13
# ------------------------------------------------------------------------------
# Copyright (C) NOAA Geophysical Fluid Dynamics Laboratory, 2009-2013
# Designed and written by V. Balaji, Amy Langenhorst and Aleksey Yakovlev
#

package FREExternalProperties;

use strict;

use FREMsg();

# //////////////////////////////////////////////////////////////////////////////
# ////////////////////////////////////////////////////////// Global Variables //
# //////////////////////////////////////////////////////////////////////////////

my $FREExternalPropertiesNamePattern = qr/[a-zA-Z]\w*(?:(?:\.|:)\w+)*/o;

# //////////////////////////////////////////////////////////////////////////////
# ///////////////////////////////////////////////////////////////// Utilities //
# //////////////////////////////////////////////////////////////////////////////

my $placeholdersExpand = sub($$)

    # ------ arguments: $object $string
    # ------ expand all the known placeholders in the given $string
{
    my ( $r, $s ) = @_;
    if ( index( $s, '$' ) >= 0 ) {
        foreach my $k ( keys( %{$r} ) ) {
            last unless index( $s, '$' ) >= 0;
            my $v = $r->{$k};
            $s =~ s/\$\($k\)/$v/g;
        }
    }
    return $s;
};

my $propertiesExtract = sub($$$)

    # ------ arguments: $object $fileName $verbose
    # ------ extract properties from the $fileName and save them in the $object
    # ------ implement conditional parsing based on the hostname
{
    my ( $r, $f, $v ) = @_;
    my $conditionCheck = sub($) { return eval shift; };
    if ( open my $handle, '<', $f ) {
        my ( $ok, $conditionFlag, $conditionFlagGlobal, $command ) = ( 1, 1, 0, '' );
        while (<$handle>) {
            chomp( my $line = $_ );
            if ( $line =~ m/^\s*#if(?:\s*\((.*)\)\s*)?$/ ) {
                if ( $command eq '' ) {
                    $conditionFlag       = $conditionCheck->($1);
                    $conditionFlagGlobal = 1 if $conditionFlag;
                    $command             = 'if';
                }
                else {
                    FREMsg::out( $v, FREMsg::FATAL,
                        "File '$f' line $.: nested '#if' isn't allowed" );
                    $ok = 0;
                    last;
                }
            }
            elsif ( $line =~ m/^\s*#elsif(?:\s*\((.*)\)\s*)?$/ ) {
                if ( $command eq 'if' or $command eq 'elsif' ) {
                    $conditionFlag = ($conditionFlagGlobal) ? 0 : $conditionCheck->($1);
                    $conditionFlagGlobal = 1 if $conditionFlag;
                    $command = 'elsif';
                }
                else {
                    FREMsg::out( $v, FREMsg::FATAL,
                        "File '$f' line $.: '#elsif' must follow '#if' or '#elsif'" );
                    $ok = 0;
                    last;
                }
            }
            elsif ( $line =~ m/^\s*#else\s*$/ ) {
                if ( $command eq 'if' or $command eq 'elsif' ) {
                    $conditionFlag       = !$conditionFlagGlobal;
                    $conditionFlagGlobal = 1 if $conditionFlag;
                    $command             = 'else';
                }
                else {
                    FREMsg::out( $v, FREMsg::FATAL,
                        "File '$f' line $.: '#else' must follow '#if' or '#elsif'" );
                    $ok = 0;
                    last;
                }
            }
            elsif ( $line =~ m/^\s*#endif\s*$/ ) {
                if ( $command eq 'if' or $command eq 'elsif' or $command eq 'else' ) {
                    $conditionFlag       = 1;
                    $conditionFlagGlobal = 0;
                    $command             = '';
                }
                else {
                    FREMsg::out( $v, FREMsg::FATAL,
                        "File '$f' line $.: '#endif' must follow '#if' or '#elsif' or '#else'" );
                    $ok = 0;
                    last;
                }
            }
            elsif ( $line =~ m/^\s*$/ or $line =~ m/^\s*#/ or !$conditionFlag ) {
                next;
            }
            elsif ( $line =~ m/^\s*($FREExternalPropertiesNamePattern)\s*=\s*(.*)\s*$/ ) {
                my ( $key, $value ) = ( $1, $2 );
                if ( FREExternalProperties::propertyNameCheck($key) ) {
                    unless ( $r->propertyExists($key) ) {
                        $r->propertyInsert( $key, $placeholdersExpand->( $r, $value ) );
                    }
                    else {
                        FREMsg::out( $v, FREMsg::FATAL,
                            "File '$f' line $.: property name '$key' is already defined" );
                        $ok = 0;
                        last;
                    }
                }
                else {
                    FREMsg::out( $v, FREMsg::FATAL,
                        "File '$f' line $.: property name '$key' is not an identifier" );
                    $ok = 0;
                    last;
                }
            } ## end elsif ( $line =~ m/^\s*($FREExternalPropertiesNamePattern)\s*=\s*(.*)\s*$/)
            else {
                FREMsg::out( $v, FREMsg::FATAL,
                    "File '$f' line $.: invalid property syntax '$line'" );
                $ok = 0;
                last;
            }
        } ## end while (<$handle>)
        close $handle;
        return ($ok) ? $r : undef;
    } ## end if ( open my $handle, ...)
    else {
        FREMsg::out( $v, FREMsg::FATAL, "File '$f' is not found" );
        return undef;
    }
};

# //////////////////////////////////////////////////////////////////////////////
# //////////////////////////////////////////////////////////// Class methods //
# //////////////////////////////////////////////////////////////////////////////

sub propertyNameCheck($)

    # ------ arguments: $string
    # ------ return 1 if the given $string matches the property name pattern
{
    my $s = shift;
    return ( $s =~ m/^$FREExternalPropertiesNamePattern$/ ) ? 1 : 0;
}

sub propertyNamesExtract($)

# ------ arguments: $string
# ------ return a list of substrings of the $string, matching references to the property name pattern
{
    my $s = shift;
    return ( $s =~ m/\$\(($FREExternalPropertiesNamePattern)\)/g );
}

# //////////////////////////////////////////////////////////////////////////////
# ////////////////////////////////////////// Class initialization/termination //
# //////////////////////////////////////////////////////////////////////////////

sub new($$$)

    # ------ arguments: $className $fileName $verbose
    # ------ called as class method
    # ------ create an object and populate it from the $fileName
{
    my ( $c, $f, $v ) = @_;
    my $r = {};
    bless $r, $c;
    return $propertiesExtract->( $r, $f, $v );
}

sub DESTROY

    # ------ arguments: $object
    # ------ called automatically
{
    my $r = shift;
    %{$r} = ();
}

# //////////////////////////////////////////////////////////////////////////////
# //////////////////////////////////////////////////////////// Object methods //
# //////////////////////////////////////////////////////////////////////////////

sub propertyExists($$)

    # ------ arguments: $object $propertyName
    # ------ called as object method
    # ------ return 1 if the property exists
{
    my ( $r, $k ) = @_;
    return exists( $r->{$k} );
}

sub propertyInsert($$$)

    # ------ arguments: $object $propertyName $propertyValue
    # ------ called as object method
    # ------ blindly insert the property into the $object
    # ------ doesn't do any placeholder expansion
{
    my ( $r, $k, $p, $v ) = @_;
    $r->{$k} = $p;
}

sub property($$)

    # ------ arguments: $object $propertyName
    # ------ called as object method
    # ------ return the property value
{
    my ( $r, $k ) = @_;
    return $r->{$k};
}

sub propertiesList($$)

    # ------ arguments: $object $verbose
    # ------ called as object method
    # ------ list all the properties
{
    my ( $r, $v ) = @_;
    foreach my $k ( sort( keys( %{$r} ) ) ) {
        my $level = FREMsg::INFO;
        $level++ if index( $k, 'FRE' ) == 0 or index( $k, 'HSM' ) == 0;
        FREMsg::out( $v, $level, "Property: name = '$k' value = '$r->{$k}'" );
    }
}

# //////////////////////////////////////////////////////////////////////////////
# //////////////////////////////////////////////////////////// Initialization //
# //////////////////////////////////////////////////////////////////////////////

return 1;
