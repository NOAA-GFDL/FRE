#
# $Id: FRE.pm,v 18.0.2.9 2011/02/09 19:51:56 afy Exp $
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
# ------------------------------------------------------------------------------
# Copyright (C) NOAA Geophysical Fluid Dynamics Laboratory, 2000-2011
# Designed and written by V. Balaji, Amy Langenhorst and Aleksey Yakovlev
#

package FRE;

use strict;

use File::Spec();
use XML::LibXML();

use FREDefaults();
use FREExperiment();
use FREMsg();
use FREProperties();
use FRETargets();
use FRETrace();
use FREUtil();

# //////////////////////////////////////////////////////////////////////////////
# ////////////////////////////////////////////////////////// Global constants //
# //////////////////////////////////////////////////////////////////////////////

use constant VERSION_DEFAULT => 1;
use constant VERSION_CURRENT => 4;

use constant MAIL_MODE_VARIABLE => 'FRE_SYSTEM_MAIL_MODE';
use constant MAIL_MODE_DEFAULT => 'a';

# //////////////////////////////////////////////////////////////////////////////
# ///////////////////////////////////////////////////////// Private utilities //
# //////////////////////////////////////////////////////////////////////////////

my $xmlLoadAndValidate = sub($$$)
# ------ arguments: $xmlfile $validate $verbose
{
  my ($x, $s, $v) = @_;
  my $parser = XML::LibXML->new(line_numbers => 1, xinclude => 1);
  my $document = $parser->parse_file($x);
  if ($s)
  {
    my $schemaLocation = FRE::home() . '/etc/schema/fre.xsd';
    if (-f $schemaLocation and -r $schemaLocation)
    {
      my $schema = XML::LibXML::Schema->new(location => $schemaLocation);
      eval {$schema->validate($document)};
      if ($@)
      {
	my ($line, $message) = ($@->line(), $@->message());
	$message =~ s/\n$//s;
	FREMsg::out($v, FREMsg::FATAL, "The XML file '$x', line '$line' - $message"); 
	return '';
      }
      else
      {
	FREMsg::out($v, FREMsg::NOTE, "The XML file '$x' has been successfully validated"); 
	return $document->getDocumentElement();
      }
    }
    else
    {
      FREMsg::out($v, FREMsg::FATAL, "The XML schema file '$schemaLocation' doesn't exist or not readable");
      return '';
    }
  }
  else
  {
    return $document->getDocumentElement();
  }
};

my $versionGet = sub($$)
# ------ arguments: $rootNode $verbose
# ------ return the (modified) version number
{
  my ($r, $v) = @_;
  my $version = $r->findvalue('@rtsVersion');
  if (!$version)
  {
    my $versionDefault = VERSION_DEFAULT;
    FREMsg::out($v, FREMsg::WARNING, "rtsVersion information isn't found in your configuration file"); 
    FREMsg::out($v, FREMsg::WARNING, "Assuming the lowest rtsVersion=$versionDefault.  A newer version is available...");
    $version = $versionDefault; 
  }
  elsif ($version < VERSION_CURRENT)
  {
    FREMsg::out($v, FREMsg::WARNING, "You are using obsolete rtsVersion.  A newer version is available..."); 
  }
  elsif ($version == VERSION_CURRENT)
  {
    my $versionCurrent = VERSION_CURRENT;
    FREMsg::out($v, FREMsg::NOTE, "You are using rtsVersion=$versionCurrent"); 
  }
  else
  {
    my $versionCurrent = VERSION_CURRENT;
    FREMsg::out($v, FREMsg::WARNING, "rtsVersion $version is greater than latest default version $versionCurrent");
    FREMsg::out($v, FREMsg::WARNING, "Assuming the rtsVersion=$versionCurrent"); 
    $version = $versionCurrent;
  }
  return $version;
};

my $platformNodeGet = sub($)
# ------ arguments: $rootNode
# ------ return the platform node
{
  my $r = shift;
  my @nodes = $r->findnodes('setup/platform');
  return (scalar(@nodes) == 1) ? $nodes[0] : '';
};

my $platformSiteGet = sub($)
# ------ arguments: $platform
# ------ return platform site and prefixed (if needed) platform
{
  my $p = FREDefaults::PlatformStandardized(shift);
  if ($p)
  {
    return ((split /\./, $p)[0], $p);
  }
  else
  {
    return '';
  }
};

my $infoGet = sub($$$)
# ------ arguments: $fre $xPath $verbose
# ------ return a piece of info, starting from the root node
{
  my ($fre, $x, $v) = @_;
  my @nodes = $fre->{rootNode}->findnodes($x);
  if (scalar(@nodes) > 0)
  {
    FREMsg::out($v, FREMsg::WARNING, "The '$x' path defines more than one data item - all the extra definitions are ignored") if scalar(@nodes) > 1;
    my $info = $fre->nodeValue($nodes[0], '.');
    $info =~ s/(?:^\s*|\s*$)//sg;
    my @infoList = split /\s+/, $info;
    if (scalar(@infoList) > 0)
    {
      FREMsg::out($v, FREMsg::WARNING, "The '$x' path defines the multi-piece data item '$info' - all the pieces besides the first one are ignored") if scalar(@infoList) > 1;
      return $infoList[0];
    }
    else
    {
      return '';
    }
  }
  else
  {
    return '';
  }
};

my $mkmfTemplateGet = sub($$$$)
# ------ arguments: $fre $caller $platformNode $verbose
# ------ return the mkmfTemplate file, defined on the platform level 
{
  my ($fre, $c, $n, $v) = @_;
  if ($c eq 'fremake')
  {
    my @mkmfTemplates = $fre->dataFilesMerged($n, 'mkmfTemplate', 'file');
    if (scalar(@mkmfTemplates) > 0)
    {
      FREMsg::out($v, FREMsg::WARNING, "The platform mkmf template is defined more than once - all the extra definitions are ignored") if scalar(@mkmfTemplates) > 1;
      return $mkmfTemplates[0];
    }
    else
    {
      my $templatesMapping = $fre->property('FRE.tool.mkmf.template.mapping');
      my $mkFilename = FREUtil::strFindByPattern($templatesMapping, $fre->baseCsh());
      if ($mkFilename eq 'NULL')
      {
	$mkFilename = $fre->property('FRE.tool.mkmf.template.default');
	FREMsg::out($v, FREMsg::WARNING, "The platform mkmf template can't be derived from the platform <csh> - using the default template '$mkFilename'");
      }    
      return $fre->siteDir() . '/' . $mkFilename;
    }
  }
  else
  {
    return 'NULL';
  }
};

my $baseCshCompatibleWithTargets = sub($$)
# ------ arguments: $fre $verbose
{
  my ($fre, $v) = @_;
  my $versionsMapping = $fre->property('FRE.tool.make.override.netcdf.mapping');
  my $baseCshNetCDF4 = (FREUtil::strFindByPattern($versionsMapping, $fre->baseCsh()) == 4);
  my $targetListHdf5 = FRETargets::containsHDF5($fre->{target});
  if ($baseCshNetCDF4 or !$targetListHdf5)
  {
    return 1;
  }
  else
  {
    FREMsg::out($v, FREMsg::FATAL, "Your platform <csh> is configured for netCDF3 - so you aren't allowed to have 'hdf5' in your targets");
    return 0;
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
  return $ENV{FRE_COMMANDS_HOME};
}

# //////////////////////////////////////////////////////////////////////////////
# ////////////////////////////////////////// Class initialization/termination //
# //////////////////////////////////////////////////////////////////////////////

sub new
# ------ arguments: $className $caller %options
# ------ called as class method
# ------ read a FRE XML tree from a file, check for basic errors, return the FRE object 
{

  my ($class, $caller, %o) = @_;
  my $xmlfileAbsPath = File::Spec->rel2abs($o{xmlfile});

  if (-f $xmlfileAbsPath and -r $xmlfileAbsPath)
  {
    FREMsg::out($o{verbose}, FREMsg::NOTE, "The '$caller' begun using the XML file '$xmlfileAbsPath'...");
    # ----------------------------------------- load the (probably validated) configuration file
    my $rootNode = $xmlLoadAndValidate->($xmlfileAbsPath, $o{validate}, $o{verbose});
    if ($rootNode)
    {
      my $version = $versionGet->($rootNode, $o{verbose});
      # --------------------------------- prefix the platform (if needed) and determine the platform site
      (my $platformSite, $o{platform}) = $platformSiteGet->($o{platform});
      if ($platformSite)
      {
        # -------------------------------------------------------------- verify locality of the platform site
	if (($platformSite eq FREDefaults::Site()) or ($caller eq 'frelist'))
	{
	  # ----------------------------------------------------------------------- standardize the target string
	  ($o{target}, my $targetErrorMsg) = FRETargets::standardize($o{target});
	  if ($o{target})
	  {
	    # -------------------------------------- initialize properties object (properties expansion happens here)
 	    my $siteDir = FRE::home() . '/site/' . $platformSite;
	    my $properties = FREProperties->new($rootNode, $platformSite, $siteDir, %o);
	    if ($properties)
	    {
	      $properties->propertiesList($o{verbose});
	      # ----------------------------------------------- locate the platform node (no backward compatibility anymore)
	      my $platformNode = $platformNodeGet->($rootNode);
	      if ($platformNode)
	      {
        	# --------------------------------------------------------------------------------------------- create the object
		my $fre = {};
		bless $fre, $class;
		# --------------------------------------------------------------- save caller name and global options in the object
		$fre->{caller} = $caller;
		$fre->{platformSite} = $platformSite;
		$fre->{platform} = $o{platform};
		$fre->{target} = $o{target};
		$fre->{verbose} = $o{verbose};
        	# ------------------------------------------------------------------------ save calculated earlier values in the object
		$fre->{xmlfileAbsPath} = $xmlfileAbsPath;
        	$fre->{rootNode} = $rootNode;
		$fre->{version} = $version;
		$fre->{siteDir} = $siteDir;
		$fre->{properties} = $properties;
		$fre->{platformNode} = $platformNode;
		# ---------------------------------------------------------------------------- calculate and save misc values in the object 
		$fre->{project} = $fre->platformValue('project') || $fre->property('FRE.scheduler.project');
		$fre->{baseCsh} = $fre->platformValue('csh');
		# -------------------------------------------------------------------------------------------------- derive the mkmf template
		my $mkmfTemplate = $mkmfTemplateGet->($fre, $caller, $platformNode, $o{verbose});
		if ($mkmfTemplate)
		{
		  $fre->{mkmfTemplate} = $mkmfTemplate;
		  # -------------------------------------------------------------------------- verify compatibility of base <csh> with targets
		  if ($baseCshCompatibleWithTargets->($fre, $o{verbose}))
		  {
		    # -------------------------------------------------------------------------- read setup-based info (for compatibility only)
		    $fre->{getFmsData} = $infoGet->($fre, 'setup/getFmsData', $o{verbose});
		    $fre->{fmsRelease} = $infoGet->($fre, 'setup/fmsRelease', $o{verbose});
		    # -------------------------------------------------------------------- read experiment nodes, save their names and nodes
		    my (%counter, %expNode, $expNames);
		    foreach my $node ($rootNode->findnodes('experiment'))
		    {
		      my $name = $fre->nodeValue($node, '@name') || $fre->nodeValue($node, '@label');
		      $counter{$name}++;
		      $expNode{$name} = $node;
		      $expNames .= ' ' if $expNames;
		      $expNames .= $name;
		    }
		    # ----------------------------------------------------------------------- check experiment names uniqueness
		    my @expNamesDuplicated = grep($counter{$_} > 1, keys(%counter));
		    if (scalar(@expNamesDuplicated) == 0)
		    {
		      # ------------------------------------------------ save experiment names and nodes in the object
		      $fre->{expNodes} = \%expNode;
		      $fre->{expNames} = $expNames;
		      # -------------------------------------------------------------------- print what we got
		      $fre->out
		      (
			2,
			"siteDir        = $fre->{siteDir}", 
			"platform       = $fre->{platform}",
			"target         = $fre->{target}",
			"project        = $fre->{project}", 
			"mkmfTemplate   = $fre->{mkmfTemplate}"
		      );
		      # ----------------------------------------------------------- call tracing
		      if ($fre->property('FRE.call.trace'))
		      {
			FRETrace::insert($siteDir, $caller, $xmlfileAbsPath, \%o);
		      }
		      # ------------------------------------------------- normal return
		      return $fre;
		    }
		    else
		    {
		      my $expNamesDuplicated = join ' ', @expNamesDuplicated;
		      FREMsg::out($o{verbose}, FREMsg::FATAL, "Experiment names aren't unique: $expNamesDuplicated");
		      return '';
		    }
		  }
		  else
		  {
		    FREMsg::out($o{verbose}, FREMsg::FATAL, "Mismatch between the platform <csh> and the target option value");
		    return '';
		  }
        	}
		else
		{
        	  FREMsg::out($o{verbose}, FREMsg::FATAL, "A problem with the mkmf template");
		  return '';
		}
	      }
	      else
	      {
        	FREMsg::out($o{verbose}, FREMsg::FATAL, "The platform with name '$o{platform}' isn't defined or defined more than once");
		return '';
	      }
	    }
	    else
	    {
              FREMsg::out($o{verbose}, FREMsg::FATAL, "A problem with FRE configuration files");
	      return '';
	    }
	  }
	  else
	  {
	    FREMsg::out($o{verbose}, FREMsg::FATAL, $targetErrorMsg);
	    return '';
	  }
	}
	else
	{
	  FREMsg::out($o{verbose}, FREMsg::FATAL, "You are not allowed to run the '$caller' tool with the '$o{platform}' platform on this site");
	  return '';
	}
      }
      else
      {
	FREMsg::out($o{verbose}, FREMsg::FATAL, "The platform option is invalid");
	return '';
      }
    }
    else
    {
      FREMsg::out($o{verbose}, FREMsg::FATAL, "The XML file '$xmlfileAbsPath' hasn't been validated");
      return '';
    }
  }
  else
  {
    FREMsg::out($o{verbose}, FREMsg::FATAL, "The XML file '$xmlfileAbsPath' doesn't exist or isn't readable");
    return '';
  }

}

sub DESTROY
{
  my $fre = shift;
}

# //////////////////////////////////////////////////////////////////////////////
# //////////////////////////////////////////////////////////// Object methods //
# //////////////////////////////////////////////////////////////////////////////

sub setCurrentExperimentName($$)
# ------ arguments: $fre $expName
# ------ called as object method
{
  my ($fre, $e) = @_;
  $fre->{name} = $e;
}

sub unsetCurrentExperimentName($)
# ------ arguments: $fre
# ------ called as object method
{
  my $fre = shift;
  my $name = $fre->{name};
  delete($fre->{name});
  return $name;
}

sub currentExperimentName($)
# ------ arguments: $fre
# ------ called as object method
{
  my $fre = shift;
  return $fre->{name};
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
  my ($fre, $n) = @_;
  return $fre->{expNodes}->{$n};
}

sub dataFiles($$$)
# ------ arguments: $fre $node $label
# ------ called as object method
# ------ return a list of datafiles with targets
{

  my ($fre, $n, $l) = @_;
  my @results;

  my @nodes = $n->findnodes('dataFile[@label="' . $l . '"]');
  foreach my $node (@nodes)
  {
    my $sourcesCommon = $fre->nodeValue($node, 'text()');
    my $sourcesPlatform = $fre->nodeValue($node, 'dataSource/text()');
    my @sources = split(/\s+/, "$sourcesCommon\n$sourcesPlatform");
    my $target = $fre->nodeValue($node, '@target');
    foreach my $fileName (@sources)
    {
      next unless $fileName;
      if (scalar(grep($_ eq $fileName, @results)) == 0)
      {
        push @results, $fileName;
        push @results, $target;
	unless (-f $fileName and -r $fileName)
	{
          my $line = $node->line_number();
	  $fre->out(FREMsg::WARNING, "XML file line $line: the $l file '$fileName' isn't accessible or doesn't exist");
	}
      }
      else
      {
        my $line = $node->line_number();
        $fre->out(FREMsg::WARNING, "XML file line $line: the $l file '$fileName' is defined more than once - all the extra definitions are ignored");
      }
    }
  }
  
  return @results;
  
}

sub dataFilesMerged($$$$)
# ------ arguments: $fre $node $label $attrName
# ------ called as object method
# ------ return a list of datafiles, merged with list of files in the <$label/@$attrName> format, without targets
{

  my ($fre, $n, $l, $a) = @_;
  my @results;
  
  my @resultsFull = $fre->dataFiles($n, $l);
  for (my $i = 0; $i < scalar(@resultsFull); $i += 2) {push @results, $resultsFull[$i];}

  my @nodesForCompatibility = $n->findnodes($l . '/@' . $a);
  foreach my $node (@nodesForCompatibility)
  {
    my $fileName = $fre->nodeValue($node, '.');
    next unless $fileName;
    if (scalar(grep($_ eq $fileName, @results)) == 0)
    {
      push @results, $fileName;
      unless (-f $fileName and -r $fileName)
      {
        my $line = $node->line_number();
	$fre->out(FREMsg::WARNING, "XML file line $line: the $l $a '$fileName' isn't accessible or doesn't exist");
      }
    }
    else
    {
      my $line = $node->line_number();
      $fre->out(FREMsg::WARNING, "XML file line $line: the $l $a '$fileName' is defined more than once - all the extra definitions are ignored");
    }
  }
  
  return @results;
  
}

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
  my ($fre, $s) = @_;
  if (exists($fre->{name}))
  {
    my $v = $fre->{name};
    $s =~ s/\$(?:\(name\)|\{name\}|name)/$v/g;
  }
  return $s;
};

sub property($$)
# ------ arguments: $fre $propertyName
# ------ called as object method
# ------ return the external property value
{
  my ($fre, $k) = @_;
  return $fre->placeholdersExpand($fre->{properties}->property($k));
}

sub nodeValue($$$)
# ------ arguments: $fre $node $xPath
# ------ called as object method
# ------ return $xPath value relative to $node
{
  my ($fre, $n, $x) = @_;
  return $fre->placeholdersExpand(join(' ', map($_->findvalue('.'), $n->findnodes($x))));
}

sub platformValue($$)
# ------ arguments: $fre $xPath
# ------ called as object method
# ------ return $xPath value relative to <setup/platform> node
{
  my ($fre, $x) = @_;
  return $fre->nodeValue($fre->{platformNode}, $x);
}

sub runTime($$)
# ------ arguments: $fre $npes
# ------ called as object method
# ------ return maximum runtime for $npes
{
  my ($fre, $n) = @_;
  return FREUtil::strFindByInterval($fre->property('FRE.scheduler.runtime.max'), $n);
}

sub mailMode($)
# ------ arguments: $fre 
# ------ called as object method
# ------ return mail mode for the batch scheduler 
{
  my $fre = shift;
  my $m = $ENV{FRE::MAIL_MODE_VARIABLE};
  if ($m)
  {
    if ($m =~ m/^(?:n|a|b|e|ab|ae|be|abe)$/)
    {
      return $m;
    }
    else
    {
      my $v = FRE::MAIL_MODE_VARIABLE;
      $fre->out(FREMsg::WARNING, "The environment variable '$v' has wrong value '$m' - ignored...");
      return FRE::MAIL_MODE_DEFAULT;
    }
  }
  else
  {
    return FRE::MAIL_MODE_DEFAULT;
  }
}

sub out($$@)
# ------ arguments: $fre $level @strings
# ------ called as object method
# ------ output @strings provided that the 0 <= $level <= $verbose + 1
{
  my $fre = shift;
  FREMsg::out($fre->{verbose}, shift, @_);
}

# //////////////////////////////////////////////////////////////////////////////
# //////////////////////////////////////////////////////////// Initialization //
# //////////////////////////////////////////////////////////////////////////////

return 1;
