#
# $Id: FREProperties.pm,v 18.0.2.19.4.1 2013/12/03 16:37:58 Amy.Langenhorst Exp $
# ------------------------------------------------------------------------------
# FMS/FRE Project: Properties Management Module
# ------------------------------------------------------------------------------
# arl    Ver   0.00  Merged revision 1.1.4.8 onto trunk             March 10
# afy -------------- Branch 18.0.2 -------------------------------- June 10
# afy    Ver   1.00  Modify externalPropertiesExtract (allow '=')   June 10
# afy    Ver   2.00  Modify treeProcessPlatform (platforms names)   September 10
# afy    Ver   2.01  Modify treeProcessDataSource (platforms names) September 10
# afy    Ver   2.02  Modify treeProcessProperty (better messages)   September 10
# afy    Ver   3.00  Add propertyNameCheck (from FREUtil)           September 10
# afy    Ver   3.01  Add propertyNamesExtract utility               September 10
# afy    Ver   3.02  Add placeholdersExpandAndCheck utility         September 10
# afy    Ver   3.03  Use 'index' instead of pattern search          September 10
# afy    Ver   3.04  Modify treeProcess (report missed properties)  September 10
# afy    Ver   4.00  Modify treeProcessPlatform (empty platforms)   September 10
# afy    Ver   4.01  Modify treeProcessDataSource (empty platforms) September 10
# afy    Ver   4.02  Don't support curly bracketted references      September 10
# afy    Ver   5.00  Modify treeProcessDataSource (sites!)          September 10
# afy    Ver   5.01  Don't expand placeholders in unbound nodes     September 10
# afy    Ver   6.00  Modify treeProcessPlatform (add 'stem')        November 10
# afy    Ver   7.00  Use new FREMsg module (symbolic level names)   January 11
# afy    Ver   7.01  Pass verbose flag via the object               January 11
# afy    Ver   7.02  Pass platformSiteIsLocal flag via the object   January 11
# afy    Ver   7.03  Modify placeholdersExpand (the flag above)     January 11
# afy    Ver   8.00  Use the FREExternalProperties as base module   March 11
# afy    Ver   8.01  Use new FREPlatforms module                    March 11
# afy    Ver   8.02  Remove propertyNameCheck utility               March 11
# afy    Ver   8.03  Remove propertyNamesExtract utility            March 11
# afy    Ver   8.04  Remove propertyInsert utility                  March 11
# afy    Ver   8.05  Remove externalPropertiesExtract utility       March 11
# afy    Ver   8.06  Modify new subroutine (call constructor)       March 11
# afy    Ver   8.07  Remove property subroutine                     March 11
# afy    Ver   8.08  Remove propertiesList subroutine               March 11
# afy    Ver   8.09  Modify placeholdersExpand (optimization)       March 11
# afy    Ver   9.00  Modify new subroutine (platformSiteIsLocal)    April 11
# afy    Ver   9.01  Revive property subroutine                     April 11
# afy    Ver  10.00  Remove platformSiteIsLocal subroutine          May 11
# afy    Ver  10.01  Add environmentVariablesExpand subroutine      May 11
# afy    Ver  10.02  Modify placeholdersExpand (call ^)             May 11
# afy    Ver  10.03  Modify new (no platform locality)              May 11
# afy    Ver  11.00  Modify new (correction in suite)               May 11
# afy    Ver  12.00  Revive platformSiteIsLocal utility/flag        October 11
# afy    Ver  12.01  Modify environmentVariablesExpand (locality)   October 11
# afy    Ver  12.02  Modify new subroutine (remoteUser)             October 11
# afy    Ver  13.00  Modify environmentVariablesExpand subroutine   November 11
# afy    Ver  13.01  Modify new subroutine (xmlfileOwner)           November 11
# afy    Ver  14.00  Modify new (FREPlatforms::equals*SiteHead)     December 11
# afy    Ver  14.01  Remove platformSiteIsLocal utility             December 11
# afy    Ver  15.00  Modify treeProcess* (return result, verbosity) December 11
# afy    Ver  15.01  Use new propertyExists subroutine              December 11
# afy    Ver  15.02  Make all the warnings fatal                    December 11
# afy    Ver  15.03  Modify new (verbosity via argument)            December 11
# afy    Ver  16.00  Modify treeProcessPlatform (platform dupes)    January 12
# afy    Ver  16.01  Add treeProcessSetup (missing platform)        January 12
# afy    Ver  16.02  Modify treeProcess (call ^)                    January 12
# afy    Ver  17.00  Use propertyExists (for platformDefined)       January 12
# afy    Ver  17.01  Rename *SiteIsLocal => *SiteHasLocalStorage    January 12
# afy    Ver  17.02  Modify treeProcessPlatform (checks, parsing)   January 12
# afy    Ver  17.03  Modify treeProcessDataSource (checks, parsing) January 12
# afy    Ver  17.04  Modify new (less one argument, site parts)     January 12
# afy    Ver  18.00  Modify treeProcessDataSource (bug fix)         January 12
# afy    Ver  19.00  Modify treeProcessPlatform (final dirs)        August 12
# ------------------------------------------------------------------------------
# Copyright (C) NOAA Geophysical Fluid Dynamics Laboratory, 2009-2012
# Designed and written by V. Balaji, Amy Langenhorst and Aleksey Yakovlev
#

package FREProperties;

use strict;

use File::Basename();
use File::Spec();

use FREDefaults();
use FREExternalProperties();
use FREMsg();
use FREPlatforms();
use FRETargets();
use FREUtil();

# //////////////////////////////////////////////////////////////////////////////
# /////////////////////////////////////////////////////////////// Inheritance //
# //////////////////////////////////////////////////////////////////////////////

our @ISA = ('FREExternalProperties');

# //////////////////////////////////////////////////////////////////////////////
# ////////////////////////////////////////////////////////// Global Constants //
# //////////////////////////////////////////////////////////////////////////////

use constant DIRECTORIES             => FREDefaults::ExperimentDirs();
use constant RESERVED_PROPERTY_NAMES => FREDefaults::ReservedPropertyNames();
use constant DEFERRED_PROPERTY_NAMES => FREDefaults::DeferredPropertyNames();
use constant PROPERTIES_FILENAME     => 'fre.properties';

# //////////////////////////////////////////////////////////////////////////////
# ///////////////////////////////////////////////////////////////// Utilities //
# //////////////////////////////////////////////////////////////////////////////

my $environmentVariablesExpand = sub($$)

    # ------ arguments: $object $string
    # ------ expand environment variables in the given $string
{
    my ( $r, $s ) = @_;
    foreach my $k ( 'ARCHIVE', 'HOME', 'USER', 'SCRATCH', 'DEV', 'PDATA', 'CDATA' ) {
        last if $s !~ m/\$/;
        my $v = '';
        if ( $r->{platformSiteHasLocalStorage} ) {
            $v = ( $k eq 'USER' ) ? $r->{xmlfileOwner} : ( $r->{"FRE.expand.$k"} || $ENV{$k} );
        }
        else {
            $v = ( $k eq 'USER' ) ? $r->{remoteUser} : $r->{"FRE.expand.$k"};
        }
        # remove trailing slash from environment variables, as the slash is readded later
        $v =~ s@/$@@;
        $s =~ s/\$(?:$k|\{$k\})/$v/g if $v;
    }
    return $s;
};

my $placeholdersExpand = sub($$)

    # ------ arguments: $object $string
    # ------ expand placeholders in the given $string
{
    my ( $r, $s ) = @_;
    if ( index( $s, '$' ) >= 0 ) {
        $s = $environmentVariablesExpand->( $r, $s );
        foreach my $k ( sort keys( %{$r} ) ) {
            last unless index( $s, '$' ) >= 0;
            my $v = $r->{$k};
            if ( $k eq 'root' ) {
                $s =~ s/\$(?:\(root\)|root)/$v/g;
            }
            else {
                $s =~ s/\$\($k\)/$v/g;
            }
        }
    }
    return $s;
};

my $placeholdersExpandAndCheck = sub($$)

# ------ arguments: $object $string
# ------ return status, expanded (as far as possible) $string and a list of non-found property names
{
    my ( $r, $s ) = @_;
    if ( index( $s, '$' ) >= 0 ) {
        $s = $placeholdersExpand->( $r, $s );
        if ( index( $s, '$' ) >= 0 ) {
            my @names = FREExternalProperties::propertyNamesExtract($s);
            if ( scalar(@names) > 0 ) {
                my @nonDeferredNames = grep {
                    my $name = $_;
                    scalar( grep( $_ eq $name, DEFERRED_PROPERTY_NAMES ) ) == 0;
                } @names;
                return ( 1, $s, @nonDeferredNames );
            }
            else {
                return ( 1, $s );
            }
        }
        else {
            return ( 1, $s );
        }
    }
    else {
        return 0;
    }
};

my $placeholdersOut = sub($$$@)

    # ------ arguments: $object $node $verbose @names
{
    my ( $r, $n, $v, @names ) = @_;
    my $line = $n->line_number();
    foreach my $name (@names) {
        FREMsg::out( $v, FREMsg::FATAL, "XML file line $line: the property '$name' is not found" );
    }
};

# //////////////////////////////////////////////////////////////////////////////
# //////////////////////////////////////////////////////////// Tree Traversal //
# //////////////////////////////////////////////////////////////////////////////

my $treeProcess;    # <------ forward declaration

my $treeProcessAllChildren = sub($$$)

    # ------ arguments: $object $node $verbose
{
    my ( $r, $n, $v ) = @_;
    foreach my $child ( $n->findnodes('*') ) {
        $r = $treeProcess->( $r, $child, $v );
        last unless $r;
    }
    return $r;
};

my $treeProcessAttribute = sub($$$)

    # ------ arguments: $object $attrNode $verbose
{
    my ( $r, $n, $v ) = @_;
    my ( $status, $value, @names ) = $placeholdersExpandAndCheck->( $r, $n->getValue() );
    if ( scalar(@names) == 0 ) {
        $n->setValue($value) if $status;
        return $r;
    }
    else {
        $placeholdersOut->( $r, $n, $v, @names );
        return undef;
    }
};

my $treeProcessAllAttributes = sub($$$)

    # ------ arguments: $object $node $verbose
{
    my ( $r, $n, $v ) = @_;
    foreach my $attrNode ( $n->attributes() ) {
        $r = $treeProcessAttribute->( $r, $attrNode, $v );
        last unless $r;
    }
    return $r;
};

my $treeProcessText = sub($$$)

    # ------ arguments: $object $textNode $verbose
{
    my ( $r, $n, $v ) = @_;
    my ( $status, $value, @names ) = $placeholdersExpandAndCheck->( $r, $n->data() );
    if ( scalar(@names) == 0 ) {
        $n->setData($value) if $status;
        return $r;
    }
    else {
        $placeholdersOut->( $r, $n, $v, @names );
        return undef;
    }
};

my $treeProcessAllTexts = sub($$$)

    # ------ arguments: $object $node $verbose
{
    my ( $r, $n, $v ) = @_;
    foreach my $textNode ( $n->findnodes('text()') ) {
        $r = $treeProcessText->( $r, $textNode, $v );
        last unless $r;
    }
    return $r;
};

my $treeProcessProperty = sub($$$)

    # ------ arguments: $object $node $verbose
    # ------ special processing for the <property> node
{
    my ( $r, $n, $v ) = @_;
    my $parentNodeName = $n->parentNode()->nodeName();
    if ( $parentNodeName eq 'experimentSuite' || $parentNodeName eq 'platform' ) {
        if ( $treeProcessAllAttributes->( $r, $n, $v ) && $treeProcessAllTexts->( $r, $n, $v ) ) {
            my $name = $n->getAttribute('name');
            if ( FREExternalProperties::propertyNameCheck($name) ) {
                if ( scalar( grep( $_ eq $name, FREProperties::RESERVED_PROPERTY_NAMES ) ) == 0 ) {
                    unless ( $r->propertyExists($name) ) {
                        my ( $valueAttr, $valueText )
                            = ( $n->getAttribute('value'), $n->findvalue('text()') );
                        if ( $valueAttr && !$valueText ) {
                            $r->propertyInsert( $name, $valueAttr );
                            return $r;
                        }
                        elsif ( !$valueAttr && $valueText ) {
                            $r->propertyInsert( $name, $valueText );
                            return $r;
                        }
                        elsif ( !$valueAttr && !$valueText ) {
                            $r->propertyInsert( $name, '' );
                            return $r;
                        }
                        else {
                            my $line = $n->line_number();
                            FREMsg::out( $v, FREMsg::FATAL,
                                "XML file line $line: the property '$name' is defined both as an attribute and as a text"
                            );
                            return undef;
                        }
                    } ## end unless ( $r->propertyExists...)
                    else {
                        my $line = $n->line_number();
                        FREMsg::out( $v, FREMsg::FATAL,
                            "XML file line $line: the property '$name' is already defined" );
                        return undef;
                    }
                } ## end if ( scalar( grep( $_ ...)))
                else {
                    my $line = $n->line_number();
                    FREMsg::out( $v, FREMsg::FATAL,
                        "XML file line $line: the property name '$name' is reserved" );
                    return undef;
                }
            } ## end if ( FREExternalProperties::propertyNameCheck...)
            else {
                my $line = $n->line_number();
                FREMsg::out( $v, FREMsg::FATAL,
                    "XML file line $line: the property name '$name' is not an identifier" );
                return undef;
            }
        } ## end if ( $treeProcessAllAttributes...)
        else {
            my $s    = $n->toString();
            my $line = $n->line_number();
            FREMsg::out( $v, FREMsg::FATAL,
                "XML file line $line: the property $s can't be parsed" );
            return undef;
        }
    } ## end if ( $parentNodeName eq...)
    else {
        my $s    = $n->toString();
        my $line = $n->line_number();
        FREMsg::out( $v, FREMsg::FATAL,
            "XML file line $line: the property $s can't descend from a '$parentNodeName' node" );
        return undef;
    }
};

my $treeProcessPlatform = sub($$$)

    # ------ arguments: $object $node $verbose
    # ------ special processing for the <platform> node
{
    my ( $r, $n, $v ) = @_;
    if ( $n->hasAttribute('name') ) {
        my $nameNode = $n->getAttributeNode('name');
        if ( $treeProcessAttribute->( $r, $nameNode, $v ) ) {
            my $platform = $nameNode->getValue();
            if ($platform) {
                my ( $platformSite, $plaformTail ) = FREPlatforms::parse($platform);
                if ($platformSite) {
                    if ( scalar( grep( $_ eq $platformSite, FREDefaults::Sites() ) ) > 0 ) {
                        my $platformStandardized = "$platformSite.$plaformTail";
                        if ( $platformStandardized eq $r->{platform} ) {
                            unless ( $r->propertyExists('platformDefined') ) {
                                $nameNode->setValue($platformStandardized)
                                    if $platformStandardized ne $platform;
                                my @stemNodes = $n->findnodes('directory/@stem');
                                if ( scalar(@stemNodes) <= 1 ) {
                                    my $value
                                        = ( scalar(@stemNodes) == 1 )
                                        ? $stemNodes[0]->findvalue('.')
                                        : $r->{'FRE.directory.stem.default'};
                                    unless ( $r->propertyExists('stem') ) {
                                        $r->propertyInsert( 'stem',
                                            $placeholdersExpand->( $r, $value ) );
                                    }
                                    else {
                                        my $line = $n->line_number();
                                        FREMsg::out( $v, FREMsg::FATAL,
                                            "XML file line $line: the directory stem is already defined"
                                        );
                                        return undef;
                                    }
                                }
                                else {
                                    my $line = $n->line_number();
                                    FREMsg::out( $v, FREMsg::FATAL,
                                        "XML file line $line: the 'stem' attribute is defined more than once"
                                    );
                                    return undef;
                                }
                                foreach my $t (FREProperties::DIRECTORIES) {
                                    my $dir   = $t . 'Dir';
                                    my $value = $r->{ 'FRE.directory.' . $t . '.default' };
                                    if ( my $valueCustomized
                                        = $n->findvalue( 'directory[@type="' . $t . '"]' )
                                        || $n->findvalue( 'directory/' . $t ) ) {
                                        unless ( $r->{ 'FRE.directory.' . $t . '.final' } ) {
                                            $value = $valueCustomized;
                                        }
                                        else {
                                            my $line = $n->line_number();
                                            FREMsg::out( $v, FREMsg::WARNING,
                                                "XML file line $line: the directory '$dir' can't be customized on this site"
                                            );
                                        }
                                    }
                                    unless ( $r->propertyExists($dir) ) {
                                        $value =~ s/\s*//g;
                                        $r->propertyInsert( $dir,
                                            $placeholdersExpand->( $r, $value ) );
                                        $r->propertyInsert( 'root', $r->{rootDir} ) if $t eq 'root';
                                    }
                                    else {
                                        my $line = $n->line_number();
                                        FREMsg::out( $v, FREMsg::FATAL,
                                            "XML file line $line: the directory '$dir' is already defined"
                                        );
                                        return undef;
                                    }
                                } ## end foreach my $t (FREProperties::DIRECTORIES)
                                if ( $treeProcessAllChildren->( $r, $n, $v ) ) {
                                    $r->propertyInsert( 'platformDefined', 1 );
                                    return $r;
                                }
                                else {
                                    my $line = $n->line_number();
                                    FREMsg::out( $v, FREMsg::FATAL,
                                        "XML file line $line: the platform '$platform' is defined incorrectly"
                                    );
                                    return undef;
                                }
                            } ## end unless ( $r->propertyExists...)
                            else {
                                my $line = $n->line_number();
                                FREMsg::out( $v, FREMsg::FATAL,
                                    "XML file line $line: the platform '$platform' is already defined"
                                );
                                return undef;
                            }
                        } ## end if ( $platformStandardized...)
                        else {
                            $n->unbindNode();
                            return $r;
                        }
                    } ## end if ( scalar( grep( $_ ...)))
                    else {
                        my $line = $n->line_number();
                        my $sites = join( "', '", FREDefaults::Sites() );
                        FREMsg::out(
                            $v, FREMsg::WARNING,
                            "XML file line $line: the site '$platformSite' is unknown",
                            "Known sites are '$sites'"
                        );
                        $n->unbindNode();
                        return $r;
                    }
                } ## end if ($platformSite)
                else {
                    my $line = $n->line_number();
                    FREMsg::out( $v, FREMsg::FATAL,
                        "XML file line $line: the 'name' attribute value '$platform' is invalid" );
                    return undef;
                }
            } ## end if ($platform)
            else {
                my $line = $n->line_number();
                FREMsg::out( $v, FREMsg::FATAL,
                    "XML file line $line: the 'name' attribute has empty value" );
                return undef;
            }
        } ## end if ( $treeProcessAttribute...)
        else {
            my $line = $n->line_number();
            FREMsg::out( $v, FREMsg::FATAL,
                "XML file line $line: the 'name' attribute can't be parsed" );
            return undef;
        }
    } ## end if ( $n->hasAttribute(...))
    else {
        my $line = $n->line_number();
        FREMsg::out( $v, FREMsg::FATAL, "XML file line $line: the 'name' attribute is missed" );
        return undef;
    }
};

my $treeProcessDataSource = sub($$$)

    # ------ arguments: $object $node $verbose
    # ------ special processing for the <dataSource> node
{
    my ( $r, $n, $v ) = @_;
    if ( $n->hasAttribute('site') ) {
        my $siteNode = $n->getAttributeNode('site');
        if ( $treeProcessAttribute->( $r, $siteNode, $v ) ) {
            my $site = $siteNode->getValue();
            if ($site) {
                if ( scalar( grep( $_ eq $site, FREDefaults::Sites() ) ) > 0 ) {
                    if ( $site eq $r->{platformSite} || $site eq $r->{platformSiteRoot} ) {
                        return $treeProcessAllTexts->( $r, $n, $v );
                    }
                    else {
                        $n->unbindNode();
                        return $r;
                    }
                }
                else {
                    my $line = $n->line_number();
                    my $sites = join( "', '", FREDefaults::Sites() );
                    FREMsg::out(
                        $v, FREMsg::WARNING,
                        "XML file line $line: the site '$site' is unknown",
                        "Known sites are '$sites'"
                    );
                    $n->unbindNode();
                    return $r;
                }
            } ## end if ($site)
            else {
                my $line = $n->line_number();
                FREMsg::out( $v, FREMsg::FATAL,
                    "XML file line $line: the 'site' attribute has empty value" );
                return undef;
            }
        } ## end if ( $treeProcessAttribute...)
        else {
            my $line = $n->line_number();
            FREMsg::out( $v, FREMsg::FATAL,
                "XML file line $line: the 'site' attribute can't be parsed" );
            return undef;
        }
    } ## end if ( $n->hasAttribute(...))
    elsif ( $n->hasAttribute('platform') ) {
        my $platformNode = $n->getAttributeNode('platform');
        if ( $treeProcessAttribute->( $r, $platformNode, $v ) ) {
            my $platform = $platformNode->getValue();
            if ($platform) {
                my ( $platformSite, $platformTail ) = FREPlatforms::parse($platform);
                if ($platformSite) {
                    if ( scalar( grep( $_ eq $platformSite, FREDefaults::Sites() ) ) > 0 ) {
                        if ((      $platformSite eq $r->{platformSite}
                                || $platformSite eq $r->{platformSiteRoot}
                            )
                            && $platformTail eq $r->{platformTail}
                            ) {
                            my $platformStandardized = "$platformSite.$platformTail";
                            $platformNode->setValue($platformStandardized)
                                if $platformStandardized ne $platform;
                            return $treeProcessAllTexts->( $r, $n, $v );
                        }
                        else {
                            $n->unbindNode();
                            return $r;
                        }
                    }
                    else {
                        my $line = $n->line_number();
                        my $sites = join( "', '", FREDefaults::Sites() );
                        FREMsg::out(
                            $v, FREMsg::WARNING,
                            "XML file line $line: the site '$platformSite' is unknown",
                            "Known sites are '$sites'"
                        );
                        $n->unbindNode();
                        return $r;
                    }
                } ## end if ($platformSite)
                else {
                    my $line = $n->line_number();
                    FREMsg::out( $v, FREMsg::FATAL,
                        "XML file line $line: the 'platform' attribute value '$platform' is invalid"
                    );
                    return undef;
                }
            } ## end if ($platform)
            else {
                my $line = $n->line_number();
                FREMsg::out( $v, FREMsg::FATAL,
                    "XML file line $line: the 'platform' attribute has empty value" );
                return undef;
            }
        } ## end if ( $treeProcessAttribute...)
        else {
            my $line = $n->line_number();
            FREMsg::out( $v, FREMsg::FATAL,
                "XML file line $line: the 'platform' attribute can't be parsed" );
            return undef;
        }
    } ## end elsif ( $n->hasAttribute(...))
    else {
        my $line = $n->line_number();
        FREMsg::out( $v, FREMsg::FATAL,
            "XML file line $line: both 'site' and 'platform' attributes are missed" );
        return undef;
    }
};

my $treeProcessCompile = sub($$$)

    # ------ arguments: $object $node $verbose
    # ------ special processing for the <compile> node
{
    my ( $r, $n, $v ) = @_;
    if ( $n->hasAttribute('target') ) {
        my $targetNode = $n->getAttributeNode('target');
        if ( $treeProcessAttribute->( $r, $targetNode, $v ) ) {
            my $target = $targetNode->getValue();
            if ( !$target or FRETargets::contains( $r->{target}, $target ) ) {
                return $treeProcessAllChildren->( $r, $n, $v );
            }
            else {
                $n->unbindNode();
                return $r;
            }
        }
        else {
            my $line = $n->line_number();
            FREMsg::out( $v, FREMsg::FATAL,
                "XML file line $line: the 'target' attribute can't be parsed" );
            return undef;
        }
    }
    else {
        return $treeProcessAllChildren->( $r, $n, $v );
    }
};

my $treeProcessSetup = sub($$$)

    # ------ arguments: $object $node $verbose
{
    my ( $r, $n, $v ) = @_;
    if ( $treeProcessAllChildren->( $r, $n, $v ) ) {
        if ( $r->propertyExists('platformDefined') ) {
            return $r;
        }
        else {
            my $line = $n->line_number();
            FREMsg::out( $v, FREMsg::FATAL,
                "XML file line $line: the platform '$r->{platform}' is missed" );
            return undef;
        }
    }
    else {
        return undef;
    }
};

my $treeProcessDefault = sub($$$)

    # ------ arguments: $object $node $verbose
{
    my ( $r, $n, $v ) = @_;
    return (   $treeProcessAllAttributes->( $r, $n, $v )
            && $treeProcessAllTexts->( $r, $n, $v )
            && $treeProcessAllChildren->( $r, $n, $v ) );
};

$treeProcess = sub($$$)

    # ------ arguments: $object $node $verbose
    # ------ traverse the tree with properties expansion and special processing for some nodes
{
    my ( $r, $n, $v ) = @_;
    my $nodeName = $n->nodeName();
    if ( $nodeName eq 'property' ) {
        return $treeProcessProperty->( $r, $n, $v );
    }
    elsif ( $nodeName eq 'setup' ) {
        return $treeProcessSetup->( $r, $n, $v );
    }
    elsif ( $nodeName eq 'platform' ) {
        return $treeProcessPlatform->( $r, $n, $v );
    }
    elsif ( $nodeName eq 'dataSource' ) {
        return $treeProcessDataSource->( $r, $n, $v );
    }
    elsif ( $nodeName eq 'compile' ) {
        return $treeProcessCompile->( $r, $n, $v );
    }
    else {
        return $treeProcessDefault->( $r, $n, $v );
    }
};

# //////////////////////////////////////////////////////////////////////////////
# ////////////////////////////////////////// Class initialization/termination //
# //////////////////////////////////////////////////////////////////////////////

sub new($$$%)

    # ------ arguments: $className $rootNode $siteDir %options
    # ------ called as class method
    # ------ create an object and populate it
{
    my ( $c, $n, $d, %o ) = @_;
    if ( my $r
        = FREExternalProperties->new( $d . '/' . FREProperties::PROPERTIES_FILENAME, $o{verbose} ) )
    {
        bless $r, $c;
        my ( $site, $siteRoot, $siteHead, $tail ) = FREPlatforms::parseAll( $o{platform} );
        $r->{site}                        = FREDefaults::Site();
        $r->{platformSite}                = $site;
        $r->{platformSiteRoot}            = $siteRoot;
        $r->{platformSiteHead}            = $siteHead;
        $r->{platformTail}                = $tail;
        $r->{platformSiteHasLocalStorage} = FREPlatforms::siteHasLocalStorage($site);
        $r->{xmlfileOwner}                = FREUtil::fileOwner( $o{xmlfile} );
        $r->{remoteUser}                  = $o{'remote-user'};
        $r->{siteDir}                     = $d;
        $r->{suite}    = File::Basename::fileparse( $o{xmlfile}, qr/\.xml(?:\.\S+)?/ );
        $r->{platform} = $o{platform};
        $r->{target}   = $o{target};
        $r->{xmlDir}   = File::Spec->rel2abs( File::Basename::dirname( $o{xmlfile} ) );
        return $treeProcess->( $r, $n, $o{verbose} );
    } ## end if ( my $r = FREExternalProperties...)
    else {
        return undef;
    }
} ## end sub new($$$%)

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

sub property($$)

    # ------ arguments: $object $propertyName
    # ------ called as object method
    # ------ return the property value
{
    my ( $r, $k ) = @_;
    return $placeholdersExpand->( $r, $r->SUPER::property($k) );
}

# //////////////////////////////////////////////////////////////////////////////
# //////////////////////////////////////////////////////////// Initialization //
# //////////////////////////////////////////////////////////////////////////////

return 1;
