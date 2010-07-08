#
# $Id: FRE.pm,v 18.0.2.4 2010/06/22 22:31:51 afy Exp $
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
# ------------------------------------------------------------------------------
# Copyright (C) NOAA Geophysical Fluid Dynamics Laboratory, 2000-2010
# Designed and written by V. Balaji, Amy Langenhorst and Aleksey Yakovlev
#

package FRE;

use strict;

use File::Basename();
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
	FREMsg::out($v, 0, "The XML file '$x', line '$line' - $message"); 
	return '';
      }
      else
      {
	FREMsg::out($v, 2, "The XML file '$x' has been successfully validated"); 
	return $document->getDocumentElement();
      }
    }
    else
    {
      FREMsg::out($v, 0, "The XML schema file '$schemaLocation' doesn't exist or not readable");
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
    FREMsg::out($v, 1, "rtsVersion information isn't found in your configuration file"); 
    FREMsg::out($v, 1, "Assuming the lowest rtsVersion=$versionDefault.  A newer version is available...");
    $version = $versionDefault; 
  }
  elsif ($version < VERSION_CURRENT)
  {
    FREMsg::out($v, 1, "You are using obsolete rtsVersion.  A newer version is available..."); 
  }
  elsif ($version == VERSION_CURRENT)
  {
    my $versionCurrent = VERSION_CURRENT;
    FREMsg::out($v, 2, "You are using rtsVersion=$versionCurrent"); 
  }
  else
  {
    my $versionCurrent = VERSION_CURRENT;
    FREMsg::out($v, 1, "rtsVersion $version is greater than latest default version $versionCurrent");
    FREMsg::out($v, 1, "Assuming the rtsVersion=$versionCurrent"); 
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
# ------ return the platform site and prefixed (if needed) platform
{
  my $p = shift;
  if ($p =~ m/\./)
  {
    return ((split /\./, $p)[0], $p);
  }
  elsif ($p)
  {
    return (FREDefaults::Site(), FREDefaults::Site() . '.' . $p);
  }
  else
  {
    return (FREDefaults::Site(), FREDefaults::Platform());
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
    FREMsg::out($v, 1, "The '$x' path defines more than one data item - all the extra definitions are ignored") if scalar(@nodes) > 1;
    my $info = $fre->nodeValue($nodes[0], '.');
    $info =~ s/(?:^\s*|\s*$)//sg;
    my @infoList = split /\s+/, $info;
    if (scalar(@infoList) > 0)
    {
      FREMsg::out($v, 1, "The '$x' path defines the multi-piece data item '$info' - all the pieces besides the first one are ignored") if scalar(@infoList) > 1;
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

my $mkmfTemplateGet = sub($$)
# ------ arguments: $fre $platformNode
# ------ return the mkmfTemplate file, defined on the platform level 
{
  my ($fre, $n) = @_;
  my @mkmfTemplates = $fre->dataFilesMerged($n, 'mkmfTemplate', 'file');
  if (scalar(@mkmfTemplates) > 0)
  {
    $fre->out(1, "The platform mkmf template is defined more than once - all the extra definitions are ignored") if scalar(@mkmfTemplates) > 1;
    return $mkmfTemplates[0];
  }
  elsif (my $templatesMapping = $fre->property('FRE.tool.mkmf.template.mapping'))
  {
    my $mkFilename = FREUtil::strFindByPattern($templatesMapping, $fre->baseCsh());
    if ($mkFilename ne 'NULL')
    {
      return $fre->siteDir() . '/' . $mkFilename;
    }
    else
    {
      $fre->out(0, "The platform mkmf template can't be derived from the platform <csh>");
      return '';
    } 
  }
  else 
  {
    $fre->out(0, "The platform mkmf template isn't defined");
    return '';
  }
};

my $baseCshCompatibleWithTargets = sub($)
# ------ arguments: $fre
{
  my $fre = shift;
  my $versionsMapping = $fre->property('FRE.tool.make.override.netcdf.mapping');
  my $baseCshNetCDF4 = (FREUtil::strFindByPattern($versionsMapping, $fre->baseCsh()) == 4);
  my $targetListHdf5 = FRETargets::containsHDF5($fre->{target});
  if ($baseCshNetCDF4 or !$targetListHdf5)
  {
    return 1;
  }
  else
  {
    $fre->out(0, "Your platform <csh> is configured for netCDF3 - so you aren't allowed to have 'hdf5' in your targets");
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
  my $binDir = File::Basename::dirname($0);
  return ($binDir =~ m/(.*)\/bin$/) ? $1 : ($binDir . '/..');
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
    FREMsg::out($o{verbose}, 2, "The '$caller' begun using the XML file '$xmlfileAbsPath'...");
    # ----------------------------------------- load the (probably validated) configuration file
    my $rootNode = $xmlLoadAndValidate->($xmlfileAbsPath, $o{validate}, $o{verbose});
    if ($rootNode)
    {
      my $version = $versionGet->($rootNode, $o{verbose});
      # ------------------------------------ prefix platform (if needed), determine the site directory
      (my $platformSite, $o{platform}) = $platformSiteGet->($o{platform});
      my $siteDir = FRE::home() . '/site/' . $platformSite;
      # --------------------------------------------------------------------- standardize the target string
      ($o{target}, my $targetErrorMsg) = FRETargets::standardize($o{target});
      if ($o{target})
      {
	# -------------------------------------- initialize properties object (properties expansion happens here)
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
	    my $mkmfTemplate = $mkmfTemplateGet->($fre, $platformNode);
	    if ($mkmfTemplate)
	    {
	      $fre->{mkmfTemplate} = $mkmfTemplate;
	      # -------------------------------------------------------------------------- verify compatibility of base <csh> with targets
	      if ($baseCshCompatibleWithTargets->($fre))
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
		  FREMsg::out($o{verbose}, 0, "Experiment names aren't unique: $expNamesDuplicated");
		  return '';
		}
	      }
	      else
	      {
		FREMsg::out($o{verbose}, 0, "Mismatch between the platform <csh> and the target option value");
		return '';
	      }
            }
	    else
	    {
              FREMsg::out($o{verbose}, 0, "A problem with the mkmf template");
	      return '';
	    }
	  }
	  else
	  {
            FREMsg::out($o{verbose}, 0, "The platform with name '$o{platform}' isn't defined or defined more than once");
	    return '';
	  }
	}
	else
	{
          FREMsg::out($o{verbose}, 0, "A problem with FRE configuration files");
	  return '';
	}
      }
      else
      {
	FREMsg::out($o{verbose}, 0, $targetErrorMsg);
	return '';
      }
    }
    else
    {
      FREMsg::out($o{verbose}, 0, "The XML file '$xmlfileAbsPath' hasn't been validated");
      return '';
    }
  }
  else
  {
    FREMsg::out($o{verbose}, 0, "The XML file '$xmlfileAbsPath' doesn't exist or isn't readable");
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
	  $fre->out(1, "The filename '$fileName' isn't accessible or doesn't exist");
	}
      }
      else
      {
        $fre->out(1, "The filename '$fileName' is defined more than once - all the extra definitions are ignored");
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
	$fre->out(1, "The filename '$fileName' isn't accessible or doesn't exist");
      }
    }
    else
    {
      $fre->out(1, "The filename '$fileName' is defined more than once - all the extra definitions are ignored");
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
# ------ return the platform
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
