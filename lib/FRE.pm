#
# $Id: FRE.pm,v 18.0.2.21.4.2 2013/12/13 16:27:12 arl Exp $
# ------------------------------------------------------------------------------
# FMS/FRE Project: Main Library Module
# ------------------------------------------------------------------------------
# arl    Ver   1.00  Merged revision 17.0.2.23 onto trunk           March 10
# afy -------------- Branch 18.0.2 -------------------------------- March 10
# afy    Ver   1.00  Add xmlLoadAndValidate subroutine              March 10
# afy    Ver   1.01  Modify new (call ^)                            March 10
# afy    Ver   2.00  Modify xmlLoadAndValidate (no load_xml)        March 10
# afy    Ver   3.00  Add home subroutine (to get rid of FREROOT)    May 10
# afy    Ver   3.01  Add platformSite subroutine                    May 10
# afy    Ver   4.00  Modify new (no default for getFmsData)         June 10
# afy    Ver   5.00  Modify dataFiles (better messages)             September 10
# afy    Ver   5.01  Modify dataFilesMerged (better messages)       September 10
# afy    Ver   5.02  Modify platformSiteGet (add partition)         September 10
# afy    Ver   5.03  Modify new (process partition)                 September 10
# afy    Ver   5.04  Add platformPartition subroutine               September 10
# afy    Ver   6.00  Remove platformPartition subroutine            September 10
# afy    Ver   6.01  Modify platformSiteGet (remove partition)      September 10
# afy    Ver   6.02  Modify mkmfTemplateGet (weaken requirements)   September 10
# afy    Ver   6.03  Modify new (don't process partition)           September 10
# afy    Ver   7.00  Use new FREMsg module (symbolic level names)   December 10
# afy    Ver   7.01  Add mailMode subroutine                        December 10
# afy    Ver   8.00  Modify new (add the site locality test)        January 11
# afy    Ver   9.00  Modify home (use FRE_COMMANDS_HOME)            February 11
# afy    Ver  10.00  Use new FREUtil module (home)                  March 11
# afy    Ver  10.01  Use new FREDefaults module (Sites)             March 11
# afy    Ver  10.02  Use new FREPlatforms module                    March 11
# afy    Ver  10.03  Modify new (improve sites checking)            March 11
# afy    Ver  11.00  Add propertyParameterized subroutine           March 11
# afy    Ver  12.00  Replace 'xmlLoadAndValidate' => 'xmlLoad'      September 11
# afy    Ver  12.01  Add 'validate' class method                    September 11
# afy    Ver  12.02  Add 'init' initialization method               September 11
# afy    Ver  12.03  Modify 'new' (call 'init')                     September 11
# afy    Ver  13.00  Remove 'new' initialization method             October 11
# afy    Ver  13.01  Rename 'init' => 'new' (and roll it back)      October 11
# afy    Ver  14.00  Modify 'new' (FREPlatforms::equals*SiteRoot)   December 11
# afy    Ver  15.00  Modify 'new' (new FREProperties module)        December 11
# afy    Ver  16.00  Modify 'new' (more explanatory message)        January 12
# afy    Ver  17.00  Modify 'new' (FREPlatforms/FREProperties)      January 12
# afy    Ver  18.00  Modify 'new' (process option --project)        January 12
# afy    Ver  19.00  Modify 'propertyParameterized' subroutine      April 12
# afy    Ver  20.00  Modify 'new' (simplify uniqueness test)        July 12
# afy    Ver  20.01  Modify 'new' (don't use the FRETrace module)   July 12
# afy    Ver  21.00  Modify 'propertyParameterized' (add position)  February 13
# ------------------------------------------------------------------------------
# Copyright (C) NOAA Geophysical Fluid Dynamics Laboratory, 2000-2013
# Designed and written by V. Balaji, Amy Langenhorst and Aleksey Yakovlev
#

package FRE;

use strict;

use File::Spec();
use XML::LibXML();
use POSIX;
use Try::Tiny;

use FREDefaults();
use FREExperiment();
use FREMsg();
use FREPlatforms();
use FREProperties();
use FRETargets();
use FREUtil();

# //////////////////////////////////////////////////////////////////////////////
# ////////////////////////////////////////////////////////// Global constants //
# //////////////////////////////////////////////////////////////////////////////

use constant VERSION_DEFAULT => 1;
use constant VERSION_CURRENT => 4;

use constant MAIL_MODE_VARIABLE => 'FRE_SYSTEM_MAIL_MODE';
use constant MAIL_MODE_DEFAULT  => 'fail';

# //////////////////////////////////////////////////////////////////////////////
# ///////////////////////////////////////////////////////// Private utilities //
# //////////////////////////////////////////////////////////////////////////////

my $xmlLoad = sub($$)

    # ------ arguments: $xmlfile $verbose
    # ------ return the loaded document
{
    my ( $x, $v ) = @_;
    my $document = undef;
    my $parser = XML::LibXML->new( line_numbers => 1, xinclude => 1, expand_entities => 1 );
    eval { $document = $parser->parse_file($x) };
    if ( $@ eq '' ) {
        return $document;
    }
    else {
        FREMsg::out( $v, FREMsg::FATAL, $@ );
        return undef;
    }
};

my $xmlValidateAndLoad = sub($$)

    # ------ arguments: $xmlfile $verbose
    # ------ return the loaded document
{
    my ( $x, $v ) = @_;
    if ( validate( { document => $x, verbosity => $v } ) ) {
        return $xmlLoad->( $x, $v );
    }
    else {
        return undef;
    }
};

my $versionGet = sub($$)

    # ------ arguments: $rootNode $verbose
    # ------ return the (modified) version number
{
    my ( $r, $v ) = @_;
    my $version = $r->findvalue('@rtsVersion');
    if ( !$version ) {
        my $versionDefault = VERSION_DEFAULT;
        FREMsg::out( $v, FREMsg::WARNING,
            "rtsVersion information isn't found in your configuration file" );
        FREMsg::out( $v, FREMsg::WARNING,
            "Assuming the lowest rtsVersion=$versionDefault.  A newer version is available..." );
        $version = $versionDefault;
    }
    elsif ( $version < VERSION_CURRENT ) {
        FREMsg::out( $v, FREMsg::WARNING,
            "You are using obsolete rtsVersion.  A newer version is available..." );
    }
    elsif ( $version == VERSION_CURRENT ) {
        my $versionCurrent = VERSION_CURRENT;
        FREMsg::out( $v, FREMsg::NOTE, "You are using rtsVersion=$versionCurrent" );
    }
    else {
        my $versionCurrent = VERSION_CURRENT;
        FREMsg::out( $v, FREMsg::WARNING,
            "rtsVersion $version is greater than latest default version $versionCurrent" );
        FREMsg::out( $v, FREMsg::WARNING, "Assuming the rtsVersion=$versionCurrent" );
        $version = $versionCurrent;
    }
    return $version;
};

my $platformNodeGet = sub($)

    # ------ arguments: $rootNode
    # ------ return the platform node
{
    my $r     = shift;
    my @nodes = $r->findnodes('setup/platform');
    return ( scalar(@nodes) == 1 ) ? $nodes[0] : '';
};

my $infoGet = sub($$$)

    # ------ arguments: $fre $xPath $verbose
    # ------ return a piece of info, starting from the root node
{
    my ( $fre, $x, $v ) = @_;
    my @nodes = $fre->{rootNode}->findnodes($x);
    if ( scalar(@nodes) > 0 ) {
        FREMsg::out( $v, FREMsg::WARNING,
            "The '$x' path defines more than one data item - all the extra definitions are ignored"
        ) if scalar(@nodes) > 1;
        my $info = $fre->nodeValue( $nodes[0], '.' );
        $info =~ s/(?:^\s*|\s*$)//sg;
        my @infoList = split /\s+/, $info;
        if ( scalar(@infoList) > 0 ) {
            FREMsg::out( $v, FREMsg::WARNING,
                "The '$x' path defines the multi-piece data item '$info' - all the pieces besides the first one are ignored"
            ) if scalar(@infoList) > 1;
            return $infoList[0];
        }
        else {
            return '';
        }
    }
    else {
        return '';
    }
};

my $mkmfTemplateGet = sub($$$$)

    # ------ arguments: $fre $caller $platformNode $verbose
    # ------ return the mkmfTemplate file, defined on the platform level
{
    my ( $fre, $c, $n, $v ) = @_;
    if ( $c eq 'fremake' ) {
        my @mkmfTemplates = $fre->dataFilesMerged( $n, 'mkmfTemplate', 'file' );
        if ( scalar(@mkmfTemplates) > 0 ) {
            FREMsg::out( $v, FREMsg::WARNING,
                "The platform mkmf template is defined more than once - all the extra definitions are ignored"
            ) if scalar(@mkmfTemplates) > 1;
            return $mkmfTemplates[0];
        }
        else {
            my $mkFilename = $fre->{compiler} . '.mk';
            if ( $mkFilename eq '.mk' ) {
                $mkFilename = $fre->property('FRE.tool.mkmf.template.default');
                FREMsg::out( $v, FREMsg::WARNING,
                    "The platform mkmf template can't be derived from the <compiler> tag - using the default template '$mkFilename'"
                );
            }
            return $fre->siteDir() . '/' . $mkFilename;
        }
    }
    else {
        return 'NULL';
    }
};

my $baseCshCompatibleWithTargets = sub($$)

    # ------ arguments: $fre $verbose
{
    my ( $fre, $v ) = @_;
    my $versionsMapping = $fre->property('FRE.tool.make.override.netcdf.mapping');
    my $baseCshNetCDF4  = ( FREUtil::strFindByPattern( $versionsMapping, $fre->baseCsh() ) == 4 );
    my $targetListHdf5  = FRETargets::containsHDF5( $fre->{target} );
    if ( $baseCshNetCDF4 or !$targetListHdf5 ) {
        return 1;
    }
    else {
        FREMsg::out( $v, FREMsg::FATAL,
            "Your platform <csh> is configured for netCDF3 - so you aren't allowed to have 'hdf5' in your targets"
        );
        return 0;
    }
};

my $projectGet = sub($$)

    # ------ arguments: $fre $project
{
    my ( $fre, $p ) = @_;
    my $project = ( defined($p) ) ? $p : $fre->platformValue('project');
    if ( ! $project and $fre->property('FRE.project.required') ) {
        FREMsg::out( 1, FREMsg::FATAL,
            "Your project name is not specified and is required on this site; please correct your XML's platform section." );
        exit FREDefaults::STATUS_FRE_GENERIC_PROBLEM;
    }
    elsif (! $project) {
        return "";
    }
    else {
        return $project;
    }
};

# //////////////////////////////////////////////////////////////////////////////
# ///////////////////////////////////////////////////////////// Class methods //
# //////////////////////////////////////////////////////////////////////////////

sub home

    # ------ arguments: none
    # ------ called as class method
    # ------ return the FRE commands home
{
    return FREUtil::home();
}

sub curator($$$) {
    my ( $x, $expName, $v ) = @_;
    my $xmlOrigDoc = $xmlLoad->( $x, $v );
    my $root = $xmlOrigDoc->getDocumentElement;
    my $experimentNode
        = $root->findnodes("experiment[\@label='$expName' or \@name='$expName']")->get_node(1);
    my $publicMetadataNode = $experimentNode->findnodes("publicMetadata")->get_node(1);

    if ($publicMetadataNode) {
        my $document = XML::LibXML->load_xml( string => $publicMetadataNode->toString() );
        my $documentURI = "publicMetadata";
        $document->setURI($documentURI);

        my $return = validate(
            {   document => $document,
                verbose  => 1,
                curator  => 1
            }
        );

        if ($return) {
            return;
        }
        else {
            FREMsg::out( $v, FREMsg::FATAL,
                "CMIP Curator tags are not valid; see CMIP metadata tag documentation at http://cobweb.gfdl.noaa.gov/~pcmdi/CMIP6_Curator/xml_documentation"
            );
            exit FREDefaults::STATUS_FRE_GENERIC_PROBLEM;
        }
    } ## end if ($publicMetadataNode)
    else {
        FREMsg::out( $v, FREMsg::FATAL,
            "No CMIP Curator tags found; see CMIP metadata tag documentation at http://cobweb.gfdl.noaa.gov/~pcmdi/CMIP6_Curator/xml_documentation"
        );
        exit FREDefaults::STATUS_FRE_GENERIC_PROBLEM;
    }
} ## end sub curator($$$)

sub validate {
    my $args = shift;
    my ( $document, $validateWhat, $schemaName );
    if ( $args->{curator} ) {
        $validateWhat = 'publicMetadata';
        $schemaName   = 'curator.xsd';
        $document     = $args->{document};
    }
    else {
        $validateWhat = $args->{document};
        $schemaName   = 'fre.xsd';
        $document     = $xmlLoad->( $args->{document}, $args->{verbose} );
    }

    if ($document) {
        my $schemaLocation = FRE::home() . '/etc/schema/' . $schemaName;
        if ( -f $schemaLocation and -r $schemaLocation ) {
            my $schema = XML::LibXML::Schema->new( location => $schemaLocation );
            eval { $schema->validate($document) };
            if ( $@ eq '' ) {
                FREMsg::out( $args->{verbose}, FREMsg::NOTE,
                    "The XML file '$validateWhat' has been successfully validated" );
                return 1;
            }
            else {
                _print_validation_errors( $validateWhat, $schemaLocation );
                FREMsg::out( $args->{verbose}, FREMsg::FATAL,
                    "The XML file '$validateWhat' is not valid" );
                return undef;
            }
        }
        else {
            FREMsg::out( $args->{verbose}, FREMsg::FATAL,
                "The XML schema file '$schemaLocation' doesn't exist or not readable" );
            return undef;
        }
    } ## end if ($document)
    else {
        FREMsg::out( $args->{verbose}, FREMsg::FATAL,
            "The XML file '$validateWhat' can't be parsed" );
        return undef;
    }
} ## end sub validate

sub _print_validation_errors {

    # ------ arguments: XML filepath, XML schema filepath
    # ------ returns nothing, prints report
    my ( $xml, $schema ) = @_;

    # Run xmllint, which is in the libxml2 module which is loaded by FRE
    # the validation errors are in standard error
    my @xmllint_output = split "\n",
        `xmllint --xinclude --schema $schema --xinclude --noout $xml 2>&1`;

    # the last line just says "fails to validate" which we already know
    pop @xmllint_output;

    # Collect the errors
    my ( %xml_errors, %include_errors );
    for (@xmllint_output) {
        my ( $file, $line, undef, undef, $message ) = split ':', $_, 5;
        $message =~ s/^ +//;
        if ( $file eq $xml ) {
            $xml_errors{$line}{$message} = 1;
        }
        else {
            $include_errors{$file}{$line}{$message} = 1;
        }
    }

    # Print the report
    my $total_errors = scalar( keys %xml_errors ) + scalar keys %include_errors;
    my $message
        = $total_errors > 100
        ? "Many XML validation errors; first 100 shown below"
        : "$total_errors XML validation errors";
    my $x = 78 - length $message;
    printf "%s $message %s\n", '*' x int( $x / 2 ), '*' x ceil( $x / 2 );
    my $spacer = '';    # print a newline but not for the first file
    my $count  = 0;

    # print the XML errors
    if (%xml_errors) {
        $spacer = "\n";
        print "$xml:\n" if $count < 100;
        for my $line ( sort { $a <=> $b } keys %xml_errors ) {
            for my $message ( sort keys %{ $xml_errors{$line} } ) {
                print "    Line $line - $message\n" if $count < 100;
                ++$count;
            }
        }
    }

    # print the include errors
    for my $file ( keys %include_errors ) {
        print "$spacer$file:\n" if $count < 100;
        $spacer = "\n";
        for my $line ( sort { $a <=> $b } keys %{ $include_errors{$file} } ) {
            for my $message ( sort keys %{ $include_errors{$file}{$line} } ) {
                print "    Line $line - $message\n" if $count < 100;
            }
        }
    }

    print '*' x 80 . "\n";
} ## end sub _print_validation_errors

# //////////////////////////////////////////////////////////////////////////////
# ////////////////////////////////////////// Class initialization/termination //
# //////////////////////////////////////////////////////////////////////////////

sub new($$%)

    # ------ arguments: $className $caller %options
    # ------ called as class method
    # ------ read a FRE XML tree from a file, check for basic errors, return the FRE object
{
    my ( $class, $caller, %o ) = @_;

    my $xmlfileAbsPath = File::Spec->rel2abs( $o{xmlfile} );
    if ( -f $xmlfileAbsPath and -r $xmlfileAbsPath ) {
        FREMsg::out( $o{verbose}, FREMsg::NOTE,
            "The '$caller' begun using the XML file '$xmlfileAbsPath'..." );

        # ----------------------------------------- validate and load the configuration file
        # --novalidate option is not advertised
        my $document
            = $o{novalidate}
            ? $xmlLoad->( $xmlfileAbsPath, $o{verbose} )
            : $xmlValidateAndLoad->( $xmlfileAbsPath, $o{verbose} );
        if ($document) {
            my $rootNode = $document->documentElement();

            # if platform isn't specified or contains default, print a descriptive message and exit.
            # let frelist go ahead, setting platform to first available, if no options are specified
            # so it can print experiments and if -d is used so it can list experiment descriptions
            if ( $caller eq 'frelist'
                and ( keys %o <= 3 or keys %o == 4 and exists $o{description} ) ) {
                $o{platform} = $rootNode->findnodes('setup/platform[@name]')->get_node(1)
                    ->getAttribute('name');
            }
            else {
                FREPlatforms::checkPlatform( $o{platform} );
            }

            my $version = $versionGet->( $rootNode, $o{verbose} );

   # ------------------------------------ standardize the platform string and verify its correctness
            my ( $platformSite, $platformTail ) = FREPlatforms::parse( $o{platform} );
            if ($platformSite) {
                $o{platform} = "$platformSite.$platformTail";

 # -------------------------------------------------------- verify availability of the platform site
                if ( scalar( grep( $_ eq $platformSite, FREDefaults::Sites() ) ) > 0 ) {

# -------------------------------------------------------------- verify locality of the platform site
                    if ( FREPlatforms::siteIsLocal($platformSite) || $caller eq 'frelist' ) {

# ----------------------------------------------------------------------- standardize the target string
                        ( $o{target}, my $targetErrorMsg ) = FRETargets::standardize( $o{target} );
                        if ( $o{target} ) {

# -------------------------------------- initialize properties object (properties expansion happens here)
                            my $siteDir = FREPlatforms::siteDir($platformSite);
                            my $properties = FREProperties->new( $rootNode, $siteDir, %o );
                            if ($properties) {
                                $properties->propertiesList( $o{verbose} );

# ----------------------------------------------- locate the platform node (no backward compatibility anymore)
                                my $platformNode = $platformNodeGet->($rootNode);
                                if ($platformNode) {

# --------------------------------------------------------------------------------------------- create the object
                                    my $fre = {};
                                    bless $fre, $class;

# --------------------------------------------------------------- save caller name and global options in the object
                                    $fre->{caller}       = $caller;
                                    $fre->{platformSite} = $platformSite;
                                    $fre->{platform}     = $o{platform};
                                    $fre->{target}       = $o{target};
                                    $fre->{verbose}      = $o{verbose};

# ------------------------------------------------------------------------ save calculated earlier values in the object
                                    $fre->{xmlfileAbsPath} = $xmlfileAbsPath;
                                    $fre->{rootNode}       = $rootNode;
                                    $fre->{version}        = $version;
                                    $fre->{siteDir}        = $siteDir;
                                    $fre->{properties}     = $properties;
                                    $fre->{platformNode}   = $platformNode;

# ---------------------------------------------------------------------------- calculate and save misc values in the object
                                    $fre->{project}    = $projectGet->( $fre, $o{project} );
                                    $fre->{freVersion} = $fre->platformValue('freVersion');
                                    $fre->{compiler}   = $fre->platformValue('compiler/@type');
                                    $fre->{baseCsh}
                                        = $fre->default_platform_csh . $fre->platformValue('csh');
                                    $fre->{mailList}   = $o{'mail-list'} || $fre->property('FRE.mailList.default') || do { FREMsg::out($o{verbose}, FREMsg::FATAL, "Required FRE property FRE.mailList.default doesn't exist; contact your local FRE support team"); return '' };

# -------------------------------------------------------------------------------------------------- derive the mkmf template
                                    my $mkmfTemplate = $mkmfTemplateGet->(
                                        $fre, $caller, $platformNode, $o{verbose}
                                    );
                                    if ($mkmfTemplate) {
                                        $fre->{mkmfTemplate} = $mkmfTemplate;

# -------------------------------------------------------------------------- verify compatibility of base <csh> with targets
                                        if ( $baseCshCompatibleWithTargets->( $fre, $o{verbose} ) )
                                        {

# -------------------------------------------------------------------------- read setup-based info (for compatibility only)
                                            $fre->{getFmsData}
                                                = $infoGet->( $fre, 'setup/getFmsData',
                                                $o{verbose} );
                                            $fre->{fmsRelease}
                                                = $infoGet->( $fre, 'setup/fmsRelease',
                                                $o{verbose} );

# -------------------------------------------------------------------------------- read experiment nodes and names
                                            my @expNodes = $rootNode->findnodes('experiment');
                                            my @expNames
                                                = map( $fre->nodeValue( $_, '@name' )
                                                    || $fre->nodeValue( $_, '@label' ),
                                                @expNodes );

# ------------------------------------------------------------------------- check experiment names uniqueness
                                            my @expNamesDuplicated
                                                = FREUtil::listDuplicates(@expNames);
                                            if ( scalar(@expNamesDuplicated) == 0 ) {

# ----------------------------------------------------- save experiment names and nodes in the object
                                                my %expNode = ();
                                                for ( my $i = 0; $i < scalar(@expNames); $i++ ) {
                                                    $expNode{ $expNames[$i] } = $expNodes[$i];
                                                }
                                                $fre->{expNodes} = \%expNode;
                                                $fre->{expNames} = join ' ', @expNames;

            # -------------------------------------------------------------------- print what we got
                                                $fre->out(
                                                    FREMsg::NOTE,
                                                    "siteDir        = $fre->{siteDir}",
                                                    "platform       = $fre->{platform}",
                                                    "target         = $fre->{target}",
                                                    "project        = $fre->{project}",
                                                    "mkmfTemplate   = $fre->{mkmfTemplate}",
                                                    "freVersion     = $fre->{freVersion}"
                                                );

                                   # ------------------------------------------------- normal return
                                                return $fre;
                                            } ## end if ( scalar(@expNamesDuplicated...))
                                            else {
                                                my $expNamesDuplicated = join ', ',
                                                    @expNamesDuplicated;
                                                FREMsg::out( $o{verbose}, FREMsg::FATAL,
                                                    "Experiment names aren't unique: '$expNamesDuplicated'"
                                                );
                                                return '';
                                            }
                                        } ## end if ( $baseCshCompatibleWithTargets...)
                                        else {
                                            FREMsg::out( $o{verbose}, FREMsg::FATAL,
                                                "Mismatch between the platform <csh> and the target option value"
                                            );
                                            return '';
                                        }
                                    } ## end if ($mkmfTemplate)
                                    else {
                                        FREMsg::out( $o{verbose}, FREMsg::FATAL,
                                            "A problem with the mkmf template" );
                                        return '';
                                    }
                                } ## end if ($platformNode)
                                else {
                                    FREMsg::out( $o{verbose}, FREMsg::FATAL,
                                        "The platform with name '$o{platform}' isn't defined" );
                                    return '';
                                }
                            } ## end if ($properties)
                            else {
                                FREMsg::out( $o{verbose}, FREMsg::FATAL,
                                    "A problem with the XML file '$xmlfileAbsPath'" );
                                return '';
                            }
                        } ## end if ( $o{target} )
                        else {
                            FREMsg::out( $o{verbose}, FREMsg::FATAL, $targetErrorMsg );
                            return '';
                        }
                    } ## end if ( FREPlatforms::siteIsLocal...)
                    else {
                        FREMsg::out( $o{verbose}, FREMsg::FATAL,
                            "You are not allowed to run the '$caller' tool with the '$o{platform}' platform on this site"
                        );
                        return '';
                    }
                } ## end if ( scalar( grep( $_ ...)))
                else {
                    my $sites = join( "', '", FREDefaults::Sites() );
                    FREMsg::out(
                        $o{verbose}, FREMsg::FATAL,
                        "The site '$platformSite' is unknown",
                        "Known sites are '$sites'"
                    );
                    return '';
                }
            } ## end if ($platformSite)
            else {
                FREMsg::out( $o{verbose}, FREMsg::FATAL,
                    "The --platform option value '$o{platform}' is not valid" );
                return '';
            }
        } ## end if ($document)
        else {
            FREMsg::out( $o{verbose}, FREMsg::FATAL,
                "The XML file '$xmlfileAbsPath' can't be parsed" );
            return '';
        }
    } ## end if ( -f $xmlfileAbsPath...)
    else {
        FREMsg::out( $o{verbose}, FREMsg::FATAL,
            "The XML file '$xmlfileAbsPath' doesn't exist or isn't readable" );
        return '';
    }
} ## end sub new($$%)

sub DESTROY() {
    my $fre = shift;
}

# //////////////////////////////////////////////////////////////////////////////
# //////////////////////////////////////////////////////////// Object methods //
# //////////////////////////////////////////////////////////////////////////////

sub setCurrentExperimentName($$)

    # ------ arguments: $fre $expName
    # ------ called as object method
{
    my ( $fre, $e ) = @_;
    $fre->{name} = $e;
}

sub unsetCurrentExperimentName($)

    # ------ arguments: $fre
    # ------ called as object method
{
    my $fre  = shift;
    my $name = $fre->{name};
    delete( $fre->{name} );
    return $name;
}

sub currentExperimentName($)

    # ------ arguments: $fre
    # ------ called as object method
{
    my $fre = shift;
    return $fre->{name};
}

sub setCurrentExperID($$)

    # ----- arguments: $fre $experID
    # ----- called as object method
{
    my ( $fre, $experID ) = @_;
    $fre->{experID} = $experID;
}

sub unsetCurrentExperId($)

    # ----- arguments: $fre
    # ----- called as object method
{
    my $fre     = shift;
    my $experID = $fre->{experID};
    delete( $fre->{experID} );
    return $experID;
}

sub setCurrentRealizID($$)

    # ----- arguments: $fre $realizID
    # ----- called as object method
{
    my ( $fre, $realizID ) = @_;
    $fre->{realizID} = $realizID;
}

sub unsetCurrentRealizID($)

    # ----- arguments: $fre
    # ----- called as object method
{
    my $fre      = shift;
    my $realizID = $fre->{realizID};
    delete( $fre->{realizID} );
    return $realizID;
}

sub setCurrentRunID($$)

    # ----- arguments: $fre $runID
    # ----- called as object method
{
    my ( $fre, $runID ) = @_;
    $fre->{runID} = $runID;
}

sub unsetCurrentRunID($)

    # ----- arguments: $fre
    # ----- called as object method
{
    my $fre   = shift;
    my $runID = $fre->{runID};
    delete( $fre->{runID} );
    return $runID;
}

sub xmlAsString($)

    # ------ arguments: $fre
    # ------ called as object method
    # ------ return the XML file with entities expanded
{
    my $fre = shift;
    return '<?xml version="1.0"?>' . "\n" . $fre->{rootNode}->toString();
}

sub experimentNames($)

    # ------ arguments: $fre
    # ------ called as object method
    # ------ return list of experiment names
{
    my $fre = shift;
    return split ' ', $fre->{expNames};
}

sub experimentNode($$)

    # ------ arguments: $fre $expName
    # ------ called as object method
    # ------ return experiment node with the given name
{
    my ( $fre, $n ) = @_;
    return $fre->{expNodes}->{$n};
}

sub dataFiles($$$)

    # ------ arguments: $fre $node $label
    # ------ called as object method
    # ------ return a list of datafiles with targets
{

    my ( $fre, $n, $l ) = @_;
    my @results;

    my @nodes = $n->findnodes( 'dataFile[@label="' . $l . '"]' );
    foreach my $node (@nodes) {
        my $sourcesCommon   = $fre->nodeValue( $node, 'text()' );
        my $sourcesPlatform = $fre->nodeValue( $node, 'dataSource/text()' );
        my @sources = split( /\s+/, "$sourcesCommon\n$sourcesPlatform" );
        my $target = $fre->nodeValue( $node, '@target' );
        foreach my $fileName (@sources) {
            next unless $fileName;
            if ( scalar( grep( $_ eq $fileName, @results ) ) == 0 ) {
                push @results, $fileName;
                push @results, $target;
                unless ( -f $fileName and -r $fileName ) {
                    my $line = $node->line_number();
                    $fre->out( FREMsg::WARNING,
                        "XML file line $line: the $l file '$fileName' isn't accessible or doesn't exist"
                    );
                }
                if ( "$fileName" =~ /^\/lustre\/fs|^\/lustre\/ltfs/ ) {
                    my $line = $node->line_number();
                    $fre->out( FREMsg::WARNING,
                        "XML file line $line: the $l file '$fileName' is on a filesystem scheduled to be unmounted soon. Please move this data."
                    );
                }
            }
            else {
                my $line = $node->line_number();
                $fre->out( FREMsg::WARNING,
                    "XML file line $line: the $l file '$fileName' is defined more than once - all the extra definitions are ignored"
                );
            }
        } ## end foreach my $fileName (@sources)
    } ## end foreach my $node (@nodes)

    return @results;

} ## end sub dataFiles($$$)

sub dataFilesMerged($$$$)

# ------ arguments: $fre $node $label $attrName
# ------ called as object method
# ------ return a list of datafiles, merged with list of files in the <$label/@$attrName> format, without targets
{

    my ( $fre, $n, $l, $a ) = @_;
    my @results;

    my @resultsFull = $fre->dataFiles( $n, $l );
    for ( my $i = 0; $i < scalar(@resultsFull); $i += 2 ) { push @results, $resultsFull[$i]; }

    my @nodesForCompatibility = $n->findnodes( $l . '/@' . $a );
    foreach my $node (@nodesForCompatibility) {
        my $fileName = $fre->nodeValue( $node, '.' );
        next unless $fileName;
        if ( scalar( grep( $_ eq $fileName, @results ) ) == 0 ) {
            push @results, $fileName;
            unless ( -f $fileName and -r $fileName ) {
                my $line = $node->line_number();
                $fre->out( FREMsg::WARNING,
                    "XML file line $line: the $l $a '$fileName' isn't accessible or doesn't exist"
                );
            }
            if ( "$fileName" =~ /^\/lustre\/fs|^\/lustre\/ltfs/ ) {
                my $line = $node->line_number();
                $fre->out( FREMsg::WARNING,
                    "XML file line $line: the $l $a '$fileName' is on a filesystem scheduled to be unmounted soon. Please move this data."
                );
            }
        }
        else {
            my $line = $node->line_number();
            $fre->out( FREMsg::WARNING,
                "XML file line $line: the $l $a '$fileName' is defined more than once - all the extra definitions are ignored"
            );
        }
    } ## end foreach my $node (@nodesForCompatibility)

    return @results;

} ## end sub dataFilesMerged($$$$)

sub version($)

    # ------ arguments: $fre
    # ------ called as object method
    # ------ return the version from the XML configuration file
{
    my $fre = shift;
    return $fre->{version};
}

sub configFileAbsPathName($)

    # ------ arguments: $fre
    # ------ called as object method
    # ------ return the absolute pathname of the XML config file
{
    my $fre = shift;
    return $fre->{xmlfileAbsPath};
}

sub platformSite($)

    # ------ arguments: $fre
    # ------ called as object method
    # ------ return the platform site
{
    my $fre = shift;
    return $fre->{platformSite};
}

sub platform($)

    # ------ arguments: $fre
    # ------ called as object method
    # ------ return the platform
{
    my $fre = shift;
    return $fre->{platform};
}

sub target($)

    # ------ arguments: $fre
    # ------ called as object method
    # ------ return the target
{
    my $fre = shift;
    return $fre->{target};
}

sub siteDir($)

    # ------ arguments: $fre
    # ------ called as object method
    # ------ return the site directory
{
    my $fre = shift;
    return $fre->{siteDir};
}

sub project($)

    # ------ arguments: $fre
    # ------ called as object method
    # ------ return the project
{
    my $fre = shift;
    return $fre->{project};
}

sub mkmfTemplate($)

    # ------ arguments: $fre
    # ------ called as object method
    # ------ return the mkmfTemplate
{
    my $fre = shift;
    return $fre->{mkmfTemplate};
}

sub baseCsh($)

    # ------ arguments: $fre
    # ------ called as object method
    # ------ return the baseCsh
{
    my $fre = shift;
    return $fre->{baseCsh};
}

sub getFmsData($)

    # ------ arguments: $fre
{
    my $fre = shift;
    return $fre->{getFmsData};
}

sub fmsRelease($)

    # ------ arguments: $fre
{
    my $fre = shift;
    return $fre->{fmsRelease};
}

sub placeholdersExpand($$)

    # ------ arguments: $fre $string
    # ------ called as object method
    # ------ expand all the global level placeholders in the given $string
    # ------ the placeholder $name is expanded here after the setCurrentExperimentName call!!!
{
    my ( $fre, $s ) = @_;
    if ( exists( $fre->{name} ) ) {
        my $v = $fre->{name};
        $s =~ s/\$(?:\(name\)|\{name\}|name)/$v/g;
    }
    return $s;
}

sub property($$)

    # ------ arguments: $fre $propertyName
    # ------ called as object method
    # ------ return the external property value
{
    my ( $fre, $k ) = @_;
    return $fre->placeholdersExpand( $fre->{properties}->property($k) );
}

sub propertyParameterized($$;@)

    # ------ arguments: $fre $propertyName @values
    # ------ called as object method
    # ------ return the external property value, where all the '$' are replaced by @values
{
    my ( $fre, $k, @v ) = @_;
    my ( $s, $pos, $i ) = ( $fre->placeholdersExpand( $fre->{properties}->property($k) ), 0, 0 );
    while (1) {
        my $index = index( $s, '$', $pos );
        if ( $index < 0 ) {
            last;
        }
        elsif ( my $value = $v[$i] ) {
            substr( $s, $index, 1 ) = $value;
            $pos = $index + length($value);
            $i++;
        }
        else {
            $s = '';
        }
    }
    return $s;
}

sub nodeValue($$$)

    # ------ arguments: $fre $node $xPath
    # ------ called as object method
    # ------ return $xPath value relative to $node
{
    my ( $fre, $n, $x ) = @_;
    return $fre->placeholdersExpand( join( ' ', map( $_->findvalue('.'), $n->findnodes($x) ) ) );
}

sub platformValue($$)

    # ------ arguments: $fre $xPath
    # ------ called as object method
    # ------ return $xPath value relative to <setup/platform> node
{
    my ( $fre, $x ) = @_;
    return $fre->nodeValue( $fre->{platformNode}, $x );
}

sub runTime($$)

    # ------ arguments: $fre $npes
    # ------ called as object method
    # ------ return maximum runtime for $npes
{
    my ( $fre, $n ) = @_;
    return FREUtil::strFindByInterval( $fre->property('FRE.scheduler.runtime.max'), $n );
}

sub mailMode($)

    # ------ arguments: $fre
    # ------ called as object method
    # ------ return mail mode for the batch scheduler
{
    my $fre = shift;
    my $m   = $ENV{FRE::MAIL_MODE_VARIABLE};
    if ($m) {
        if ( $m =~ m/^(?:none|begin|end|fail|requeue|all)$/i ) {
            return $m;
        }
        else {
            my $v = FRE::MAIL_MODE_VARIABLE;
            $fre->out( FREMsg::WARNING,
                "The environment variable '$v' has wrong value '$m' - ignored..." );
            return FRE::MAIL_MODE_DEFAULT;
        }
    }
    else {
        return FRE::MAIL_MODE_DEFAULT;
    }
}

sub out($$@)

    # ------ arguments: $fre $level @strings
    # ------ called as object method
    # ------ output @strings provided that the 0 <= $level <= $verbose + 1
{
    my $fre = shift;
    FREMsg::out( $fre->{verbose}, shift, @_ );
}

# Reads the site and compiler-specific default environment file,
# replaces compiler version and fre version
# Returns string containing default platform environment c-shell
sub default_platform_csh {
    my $self = shift;

    # get compiler type and version
    my %compiler = do {
        if ( $self->platformSite eq 'gfdl' ) {
            ();
        }
        else {
            my ($compiler_node) = $self->{platformNode}->getChildrenByTagName('compiler');
            unless ($compiler_node) {
                $self->out( FREMsg::FATAL,
                    "Compiler type and version must be specified in XML platform <compiler> tag" );
                exit FREDefaults::STATUS_FRE_GENERIC_PROBLEM;
            }
            my $type    = $compiler_node->getAttribute('type');
            my $version = $compiler_node->getAttribute('version');
            unless ( $type and $version ) {
                $self->out( FREMsg::FATAL,
                    "Compiler type and version must be specified in XML platform <compiler> tag" );
                exit FREDefaults::STATUS_FRE_GENERIC_PROBLEM;
            }
            ( type => $type, version => $version );
        }
    };

    # read platform environment site file
    my $env_defaults_file = File::Spec->catfile( $self->siteDir,
        "env.defaults" . ( $self->platformSite eq 'gfdl' ? '' : ".$compiler{type}" ) );
    open my $fh, $env_defaults_file or do {
        $self->out( FREMsg::FATAL,
            "Can't open platform environment defaults file $env_defaults_file" );
        exit FREDefaults::STATUS_FRE_GENERIC_PROBLEM;
    };
    my @env_default_lines = <$fh>;
    close $fh;

    # replace FRE version and compiler version into site lines
    for (@env_default_lines) {
        s/\$\(FRE_VERSION\)/$self->{freVersion}/g;
        s/\$\(COMPILER_VERSION\)/$compiler{version}/g;
    }

    # comments
    unshift @env_default_lines, "\n# Platform environment defaults from $env_defaults_file\n";
    push @env_default_lines, "\n# Platform environment overrides from XML\n";

    return join "", @env_default_lines;
} ## end sub default_platform_csh

# Checks for consistency between the fre version in the platform xml section and the
# current shell environment
# Exits with error if different, returns nothing
sub check_for_fre_version_mismatch {
    my $self = shift;

    my @loaded_fre_modules = grep s#fre/##, split ':', $ENV{LOADEDMODULES};
    if ( ( my $n = scalar @loaded_fre_modules ) != 1 ) {
        FREMsg::out( 1, FREMsg::FATAL, "$n FRE modules appear to be loaded; should be 1" );
        exit FREDefaults::STATUS_FRE_GENERIC_PROBLEM;
    }

    if ( $loaded_fre_modules[0] ne $self->{freVersion} ) {
        if ( $self->{freVersion} ) {
            FREMsg::out( 1, FREMsg::FATAL,
                "FRE version mismatch between shell ($loaded_fre_modules[0]) and XML ($self->{freVersion})"
            );
            exit FREDefaults::STATUS_FRE_GENERIC_PROBLEM;
        }
        else {
            FREMsg::out( 1, FREMsg::FATAL,
                "FRE version must be specified within <platform> in <freVersion> tag. See documentation at http://wiki.gfdl.noaa.gov/index.php/FRE_User_Documentation#Platforms_and_Sites"
            );
            exit FREDefaults::STATUS_FRE_GENERIC_PROBLEM;
        }
    }
} ## end sub check_for_fre_version_mismatch

# //////////////////////////////////////////////////////////////////////////////
# //////////////////////////////////////////////////////////// Initialization //
# //////////////////////////////////////////////////////////////////////////////

return 1;
