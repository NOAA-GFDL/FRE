#
# $Id: FREProperties.pm,v 18.0.2.6 2010/11/07 23:08:37 afy Exp $
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
# ------------------------------------------------------------------------------
# Copyright (C) NOAA Geophysical Fluid Dynamics Laboratory, 2009-2010
# Designed and written by V. Balaji, Amy Langenhorst and Aleksey Yakovlev
#

package FREProperties;

use strict;

use File::Basename();

use FREDefaults();
use FREMsg();
use FRETargets();
use FREUtil();

# //////////////////////////////////////////////////////////////////////////////
# ////////////////////////////////////////////////////////// Global Constants //
# //////////////////////////////////////////////////////////////////////////////

use constant DIRECTORIES => FREDefaults::ExperimentDirs();
use constant RESERVED_PROPERTY_NAMES => FREDefaults::ReservedPropertyNames();
use constant DEFERRED_PROPERTY_NAMES => FREDefaults::DeferredPropertyNames(); 
use constant PROPERTY_NAME_PATTERN => qr/[a-zA-Z]+(?:\w|\.)*/o;
use constant PROPERTIES_FILENAME => 'fre.properties';

# //////////////////////////////////////////////////////////////////////////////
# ///////////////////////////////////////////////////////////////// Utilities //
# //////////////////////////////////////////////////////////////////////////////

my $propertyNameCheck = sub($)
# ------ arguments: $string
# ------ return 1 if the given $string matches the property name pattern 
{
  my ($s, $n) = (shift, PROPERTY_NAME_PATTERN);
  return ($s =~ m/^$n$/) ? 1 : 0;
};

my $propertyNamesExtract = sub($)
# ------ arguments: $string
# ------ return a list of substrings of the $string, matching a reference to the property name pattern 
{
  my ($s, $n, @r) = (shift, PROPERTY_NAME_PATTERN, ());
  while ($s =~ m/\$\(($n)\)/g) {push @r, $1;}
  return @r;
};

my $propertiesExpand = sub($$)
# ------ arguments: $object $string
# ------ expand all the property placeholders in the given $string
{
  my ($r, $s) = @_;
  foreach my $k (keys(%{$r}))
  {
    last unless index($s, '$') >= 0;
    my $v = $r->{$k};
    if ($k eq 'root')
    {
      $s =~ s/\$(?:\(root\)|root)/$v/g;
    }
    else
    {
      $s =~ s/\$\($k\)/$v/g;
    }
  }
  return $s;
};

my $placeholdersExpand = sub($$)
# ------ arguments: $object $string
# ------ expand placeholders in the given $string
{
  my ($r, $s) = @_;
  $s = FREUtil::environmentVariablesExpand($s) if index($s, '$') >= 0;
  $s = $propertiesExpand->($r, $s) if index($s, '$') >= 0;
  return $s;
};

my $placeholdersExpandAndCheck = sub($$)
# ------ arguments: $object $string
# ------ return status, expanded (as far as possible) $string and a list of non-found property names  
{
  my ($r, $s) = @_;
  if (index($s, '$') >= 0)
  {
    $s = $placeholdersExpand->($r, $s);
    if (index($s, '$') >= 0)
    {
      my @names = $propertyNamesExtract->($s);
      if (scalar(@names) > 0)
      {
        my @nonDeferredNames = grep {my $name = $_; scalar(grep($_ eq $name, DEFERRED_PROPERTY_NAMES)) == 0;} @names;
        return (1, $s, @nonDeferredNames);
      }
      else
      {
        return (1, $s);
      }
    }
    else
    {
      return (1, $s);
    }
  }
  else
  {
    return 0;
  }
};

my $placeholdersOut = sub($$@)
# ------ arguments: $node $verbose @names
{
  my ($n, $w, @names) = @_;
  my $line = $n->line_number();
  foreach my $name (@names)
  {
    FREMsg::out($w, 1, "XML file line $line: the property '$name' is not found");
  }
};

my $propertyInsert = sub($$$$)
# ------ arguments: $object $key $value $verbose
# ------ insert the property into the $object
# ------ doesn't overwrite a property with the same name
# ------ doesn't do any placeholder expansion
{
  my ($r, $k, $v, $w) = @_;
  unless (exists($r->{$k}))
  {
    $r->{$k} = $v;
  }
  elsif ($w)
  {
    FREMsg::out($w, 1, "Property '$k' is already defined - the property is ignored");
  }
};

my $externalPropertiesExtract = sub($$$)
# ------ arguments: $object $fileName $verbose
# ------ extract properties from the $fileName and save them in the $object
# ------ implement conditional parsing based on the hostname
{

  my ($r, $f, $w) = @_;
  my $res = open(FILE, $f);

  my $conditionCheck = sub($) {my $p = shift; return $ENV{HOST} =~ m/$p/;};

  if ($res)
  {

    my $ok = 1;
    my $conditionFlag = 1;
    my $conditionFlagGlobal = 0;
    my $command = '';

    while (<FILE>)
    {
      chomp(my $line = $_);
      if ($line =~ m/^\s*#if\s*\((.*)\)\s*$/)
      {
	if ($command eq '')
	{ 
	  $conditionFlag = $conditionCheck->($1);
	  $conditionFlagGlobal = 1 if $conditionFlag;
	  $command = 'if';
	}
	else
	{
	  FREMsg::out($w, 0, "External properties @ line $. - nested '#if' isn't allowed");
	  $ok = 0;
	  last;
	}
      }
      elsif ($line =~ m/^\s*#elsif\s*\((.*)\)\s*$/)
      {
	if ($command eq 'if' or $command eq 'elsif')
	{
          $conditionFlag = ($conditionFlagGlobal) ? 0 : $conditionCheck->($1);
	  $conditionFlagGlobal = 1 if $conditionFlag;
	  $command = 'elsif';
	}
	else
	{
	  FREMsg::out($w, 0, "External properties @ line $. - '#elsif' must follow '#if' or '#elsif'");
	  $ok = 0;
	  last;
	}
      }
      elsif ($line =~ m/^\s*#else\s*$/)
      {
	if ($command eq 'if' or $command eq 'elsif')
	{
	  $conditionFlag = !$conditionFlagGlobal;
	  $conditionFlagGlobal = 1 if $conditionFlag;
	  $command = 'else';
	}
	else
	{
	  FREMsg::out($w, 0, "External properties @ line $. - '#else' must follow '#if' or '#elsif'");
	  $ok = 0;
	  last;
	}
      }
      elsif ($line =~ m/^\s*#endif\s*$/)
      {
	if ($command eq 'if' or $command eq 'elsif' or $command eq 'else')
	{
	  $conditionFlag = 1;
	  $conditionFlagGlobal = 0;
	  $command = '';
	}
	else
	{
	  FREMsg::out($w, 0, "External properties @ line $. - '#endif' must follow '#if' or '#elsif' or '#else'");
	  $ok = 0;
	  last;
	}
      }	
      elsif ($line =~ m/^\s*$/ or $line =~ m/^\s*#/ or !$conditionFlag)
      {
	next;
      }
      elsif ($line =~ m/^\s*((?:\w|\.)+)\s*=\s*(.*)\s*$/)
      {
        my ($key, $value) = ($1, $2);
	if ($propertyNameCheck->($key))
	{
	  $propertyInsert->($r, $key, $placeholdersExpand->($r, $value), $w);
	}
	else
	{
          FREMsg::out($w, 0, "External property name '$key' is not an identifier");
	  $ok = 0;
	}
      }
      else
      {
        FREMsg::out($w, 0, "External property wrong syntax: $line");
	$ok = 0;
      }
    }

    close(FILE);
    
    return ($ok) ? $r : '';

  }
  else
  {
    FREMsg::out($w, 0, "File $f is not found");
    return '';
  }
  
};

# //////////////////////////////////////////////////////////////////////////////
# //////////////////////////////////////////////////////////// Tree Traversal //
# //////////////////////////////////////////////////////////////////////////////

my $treeProcess; # <------ forward declaration

my $treeProcessAllChildren = sub($$$)
# ------ arguments: $object $node $verbose
{
  my ($r, $n, $w) = @_;
  foreach my $child ($n->findnodes('*'))
  {
    $treeProcess->($r, $child, $w);
  }
};

my $treeProcessAttribute = sub($$$)
# ------ arguments: $object $attrNode $verbose
{
  my ($r, $n, $w) = @_;
  my ($status, $value, @names) = $placeholdersExpandAndCheck->($r, $n->getValue());
  $placeholdersOut->($n, $w, @names) if scalar(@names) > 0;
  $n->setValue($value) if $status;
};

my $treeProcessAllAttributes = sub($$$)
# ------ arguments: $object $node $verbose
{
  my ($r, $n, $w) = @_;
  foreach my $attrNode ($n->attributes())
  {
    $treeProcessAttribute->($r, $attrNode, $w);
  }
};

my $treeProcessText = sub($$$)
# ------ arguments: $object $textNode $verbose
{
  my ($r, $n, $w) = @_;
  my ($status, $value, @names) = $placeholdersExpandAndCheck->($r, $n->data());
  $placeholdersOut->($n, $w, @names) if scalar(@names) > 0;
  $n->setData($value) if $status;
};

my $treeProcessAllTexts = sub($$$)
# ------ arguments: $object $node $verbose
{
  my ($r, $n, $w) = @_;
  foreach my $textNode ($n->findnodes('text()'))
  {
    $treeProcessText->($r, $textNode, $w);
  }
};

my $treeProcessProperty = sub($$$)
# ------ arguments: $object $node $verbose
# ------ special processing for the <property> node
{
  my ($r, $n, $w) = @_;
  my $parentNodeName = $n->parentNode()->nodeName();
  if ($parentNodeName eq 'experimentSuite' || $parentNodeName eq 'platform')
  {
    $treeProcessAllAttributes->($r, $n, $w);
    $treeProcessAllTexts->($r, $n, $w);
    my $name = $n->getAttribute('name');
    if ($propertyNameCheck->($name))
    {
      if (scalar(grep($_ eq $name, FREProperties::RESERVED_PROPERTY_NAMES)) == 0)
      {
	my ($valueAttr, $valueText) = ($n->getAttribute('value'), $n->findvalue('text()'));
	if ($valueAttr && !$valueText)
	{
	  $propertyInsert->($r, $name, $valueAttr, $w);
	}
	elsif (!$valueAttr && $valueText)
	{
	  $propertyInsert->($r, $name, $valueText, $w);
	}
	elsif (!$valueAttr && !$valueText)
	{
	  $propertyInsert->($r, $name, '', $w);
	}
	else
	{
	  my $line = $n->line_number();
	  FREMsg::out($w, 1, "XML file line $line: the property '$name' is defined both as an attribute and as a text - the property is ignored");
	}
      }
      else
      {
        my $line = $n->line_number();
        FREMsg::out($w, 1, "XML file line $line: the property name '$name' is reserved - the property is ignored");
      }
    }
    else
    {
      my $line = $n->line_number();
      FREMsg::out($w, 1, "XML file line $line: the property name '$name' is not an identifier - the property is ignored");
    }
  }
  else
  {
    my $s = $n->toString();
    my $line = $n->line_number();
    FREMsg::out($w, 1, "XML file line $line: the property $s can't descend from a '$parentNodeName' node - the property is ignored");
  }
};

my $treeProcessPlatform = sub($$$)
# ------ arguments: $object $node $verbose
# ------ special processing for the <platform> node
{
  my ($r, $n, $w) = @_;
  if ($n->hasAttribute('name'))
  {
    my $nameNode = $n->getAttributeNode('name');
    $treeProcessAttribute->($r, $nameNode, $w);
    my $name = $nameNode->getValue();
    if ($name)
    {
      my $nameStandardized = FREDefaults::PlatformStandardized($name);
      if ($nameStandardized eq $r->{platform})
      {
	$nameNode->setValue($nameStandardized) if $nameStandardized ne $name;
	my @stemNodes = $n->findnodes('directory/@stem');
	if (scalar(@stemNodes) <= 1)
	{
	  my $value = (scalar(@stemNodes) == 1) ? $stemNodes[0]->findvalue('.') : $r->{'FRE.directory.stem.default'};
	  $propertyInsert->($r, 'stem', $placeholdersExpand->($r, $value), $w); 
	}
	else
	{
	  my $line = $n->line_number();
	  FREMsg::out($w, 1, "XML file line $line: the 'stem' attribute is defined more than once - it is ignored");
	}
	foreach my $t (FREProperties::DIRECTORIES)
	{
	  my $value =
	  (     
	    $n->findvalue('directory[@type="' . $t . '"]')
	    ||
	    $n->findvalue('directory/' . $t)
	    ||
	    $r->{'FRE.directory.' . $t . '.default'}
	  );
	  $value =~ s/\s*//g;
	  $propertyInsert->($r, $t . 'Dir', $placeholdersExpand->($r, $value), $w);
	  $propertyInsert->($r, 'root', $r->{rootDir}, $w) if $t eq 'root';
	}
        $treeProcessAllChildren->($r, $n, $w);
      }
      elsif (!$nameStandardized)
      {
	my $line = $n->line_number();
	FREMsg::out($w, 1, "XML file line $line: the 'name' attribute value '$name' is invalid - the platform is ignored");
	$n->unbindNode();
      }
      else
      {
	$n->unbindNode();
      }
    }
    else
    {
      my $line = $n->line_number();
      FREMsg::out($w, 1, "XML file line $line: the 'name' attribute has no value - the platform is ignored");
      $n->unbindNode();
    }
  }
  else
  {
    my $line = $n->line_number();
    FREMsg::out($w, 1, "XML file line $line: the 'name' attribute is missed - the platform is ignored");
    $n->unbindNode();
  }
};

my $treeProcessDataSource = sub($$$)
# ------ arguments: $object $node $verbose
# ------ special processing for the <dataSource> node
{
  my ($r, $n, $w) = @_;
  if ($n->hasAttribute('site'))
  {
    my $siteNode = $n->getAttributeNode('site');
    $treeProcessAttribute->($r, $siteNode, $w);
    my $site = $siteNode->getValue();
    if ($site)
    {
      if ($site eq $r->{platformSite})
      {
	$treeProcessAllTexts->($r, $n, $w);
      }
      else
      {
	$n->unbindNode();
      }
    }
    else
    {
      my $line = $n->line_number();
      FREMsg::out($w, 1, "XML file line $line: the 'site' attribute has no value - the data source is ignored");
      $n->unbindNode();
    }
  }
  elsif ($n->hasAttribute('platform'))
  {
    my $platformNode = $n->getAttributeNode('platform');
    $treeProcessAttribute->($r, $platformNode, $w);
    my $platform = $platformNode->getValue();
    if ($platform)
    {
      my $platformStandardized = FREDefaults::PlatformStandardized($platform);
      if ($platformStandardized eq $r->{platform})
      {
	$platformNode->setValue($platformStandardized) if $platformStandardized ne $platform;
	$treeProcessAllTexts->($r, $n, $w);
      }
      elsif (!$platformStandardized)
      {
	my $line = $n->line_number();
	FREMsg::out($w, 1, "XML file line $line: the 'platform' attribute value '$platform' is invalid - the data source is ignored");
	$n->unbindNode();
      }
      else
      {
	$n->unbindNode();
      }
    }
    else
    {
      my $line = $n->line_number();
      FREMsg::out($w, 1, "XML file line $line: the 'platform' attribute has no value - the data source is ignored");
      $n->unbindNode();
    }
  }
  else
  {
    my $line = $n->line_number();
    FREMsg::out($w, 1, "XML file line $line: both 'site' and 'platform' attributes are missed - the data source is ignored");
    $n->unbindNode();
  }
};

my $treeProcessCompile = sub($$$)
# ------ arguments: $object $node $verbose
# ------ special processing for the <compile> node
{
  my ($r, $n, $w) = @_;
  if ($n->hasAttribute('target'))
  {
    my $targetNode = $n->getAttributeNode('target');
    $treeProcessAttribute->($r, $targetNode, $w);
    my $target = $targetNode->getValue();
    if (!$target or FRETargets::contains($r->{target}, $target))
    {
      $treeProcessAllChildren->($r, $n, $w);
    }
    else
    {
      $n->unbindNode();
    }
  }
  else
  {
    $treeProcessAllChildren->($r, $n, $w);
  }
};

my $treeProcessDefault = sub($$$)
# ------ arguments: $object $node $verbose
{
  my ($r, $n, $w) = @_;
  $treeProcessAllAttributes->($r, $n, $w);
  $treeProcessAllTexts->($r, $n, $w);
  $treeProcessAllChildren->($r, $n, $w);
};

$treeProcess = sub($$$)
# ------ arguments: $object $node $verbose
# ------ traverse the tree with properties expansion and special processing for some nodes
{
  my ($r, $n, $w) = @_;
  my $nodeName = $n->nodeName();
  if ($nodeName eq 'property')
  {
    $treeProcessProperty->($r, $n, $w);
  }
  elsif ($nodeName eq 'platform')
  {
    $treeProcessPlatform->($r, $n, $w);
  }
  elsif ($nodeName eq 'dataSource')
  {
    $treeProcessDataSource->($r, $n, $w);
  }
  elsif ($nodeName eq 'compile')
  {
    $treeProcessCompile->($r, $n, $w);
  }
  else
  {
    $treeProcessDefault->($r, $n, $w);
  }
};

# //////////////////////////////////////////////////////////////////////////////
# ////////////////////////////////////////// Class initialization/termination //
# //////////////////////////////////////////////////////////////////////////////

sub new($$$$%)
# ------ arguments: $className $rootNode $platformSite $siteDir %options
# ------ called as class method
# ------ create an object and populate it 
{
  my ($c, $n, $s, $d, %o) = @_;
  my $r = {};
  bless $r, $c;
  $r->{site} = FREDefaults::Site();
  $r->{platformSite} = $s;
  $r->{siteDir} = $d;
  $r->{suite} = File::Basename::fileparse($o{xmlfile}, '.xml');
  $r->{platform} = $o{platform};
  $r->{target} = $o{target};
  $r = $externalPropertiesExtract->($r, $d . '/' . FREProperties::PROPERTIES_FILENAME, $o{verbose});
  $treeProcess->($r, $n, $o{verbose}) if $r;
  return $r;
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

sub property($$)
# ------ arguments: $object $propertyName
# ------ called as object method
# ------ return the property value
{
  my ($r, $k) = @_;
  return $r->{$k};
}

sub propertiesList($$)
# ------ arguments: $object $verbose
# ------ called as object method
# ------ list all the properties 
{
  my ($r, $w) = @_;
  foreach my $k (sort(keys(%{$r})))
  {
    my $level = ($k =~ m/^FRE/) ? 4 : 3;
    FREMsg::out($w, $level, "Property: name = '$k' value = '$r->{$k}'");
  }
}

# //////////////////////////////////////////////////////////////////////////////
# //////////////////////////////////////////////////////////// Initialization //
# //////////////////////////////////////////////////////////////////////////////

return 1;
