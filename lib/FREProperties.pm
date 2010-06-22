#
# $Id: FREProperties.pm,v 18.0 2010/03/02 23:58:54 fms Exp $
# ------------------------------------------------------------------------------
# FMS/FRE Project: Properties Management Module
# ------------------------------------------------------------------------------
# afy -------------- Branch 1.1.4 --------------------------------- August 09
# afy    Ver   1.00  Initial version                                August 09
# afy    Ver   2.00  Cosmetics                                      August 09
# afy    Ver   3.00  Restrict location of internal properties       August 09
# afy    Ver   3.01  Add verbose global variable                    August 09
# afy    Ver   4.00  Module removed                                 September 09
# afy    Ver   5.00  Copied from the FREInternalProperties module   January 10
# afy    Ver   6.04  Modify treeProcess* (use new FREDefaults)      January 10
# afy    Ver   6.05  Don't store verbose flag in the object         January 10
# afy    Ver   7.00  Add extractExternalProperties subroutine       January 10
# afy    Ver   7.01  Integrate external and internal properties     January 10
# afy    Ver   7.02  Modify treeProcessPlatform (directories)       January 10
# afy    Ver   7.03  Modify new (add platformSite)                  January 10
# afy    Ver   7.04  Modify propertiesList (use level 3/4)          January 10
# afy    Ver   8.00  Modify treeProcessCompile (no "*" target)      January 10
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

use constant SITE => FREDefaults::Site();
use constant TARGET => FREDefaults::Target();
use constant DIRECTORIES => FREDefaults::ExperimentDirs();
use constant RESERVED_PROPERTY_NAMES => FREDefaults::ReservedPropertyNames();
use constant PROPERTIES_FILENAME => 'fre.properties';

# //////////////////////////////////////////////////////////////////////////////
# ///////////////////////////////////////////////////////////////// Utilities //
# //////////////////////////////////////////////////////////////////////////////

my $propertiesExpand = sub($$)
# ------ arguments: $object $string
# ------ expand all the property placeholders in the given $string
{
  my ($r, $s) = @_;
  foreach my $k (keys(%{$r}))
  {
    last if $s !~ m/\$/;
    my $v = $r->{$k};
    if ($k eq 'root')
    {
      $s =~ s/\$(?:\(root\)|\{root\}|root)/$v/g;
    }
    else
    {
      $s =~ s/\$(?:\($k\)|\{$k\})/$v/g;
    }
  }
  return $s;
};

my $placeholdersExpand = sub($$)
# ------ arguments: $object $string
# ------ expand placeholders in the given $string
{
  my ($r, $s) = @_;
  $s = FREUtil::environmentVariablesExpand($s) if $s =~ m/\$/;
  $s = $propertiesExpand->($r, $s) if $s =~ m/\$/;
  return $s;
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
      elsif ($line =~ m/^\s*((?:\w|\.)+)\s*=\s*([^=]*)\s*$/)
      {
        my ($key, $value) = ($1, $2);
	if (FREUtil::propertyNameCheck($key))
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

my $treeProcessProperty = sub($$$)
# ------ arguments: $object $node $verbose
# ------ special processing for the <property> node
{
  my ($r, $n, $w) = @_;
  my $parentNodeName = $n->parentNode()->nodeName();
  if ($parentNodeName eq 'experimentSuite' || $parentNodeName eq 'platform')
  {
    my $name = $n->getAttribute('name');
    if (FREUtil::propertyNameCheck($name))
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
	  FREMsg::out($w, 1, "Property '$name' is defined both as an attribute and as a text - the property is ignored");
	}
      }
      else
      {
        FREMsg::out($w, 1, "Property name '$name' is reserved - the property is ignored");
      }
    }
    else
    {
      FREMsg::out($w, 1, "Property name '$name' is not an identifier - the property is ignored");
    }
  }
  else
  {
    my $s = $n->toString();
    FREMsg::out($w, 1, "Property $s can't descend from a '$parentNodeName' node - the property is ignored");
  }
  return 0;
};

my $treeProcessPlatform = sub($$$)
# ------ arguments: $object $node $verbose
# ------ special processing for the <platform> node
{
  my ($r, $n, $w) = @_;
  my $name = $n->getAttribute('name');
  my $namePrefixed = ($name =~ m/\./) ? $name : FREProperties::SITE . '.' . $name;
  if ($namePrefixed eq $r->{platform})
  {
    $n->setAttribute('name', $namePrefixed) if $namePrefixed ne $name;
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
    return 1;
  }
  else
  {
    $n->unbindNode();
    return 0;
  }
};

my $treeProcessDataSource = sub($$$)
# ------ arguments: $object $node $verbose
# ------ special processing for the <dataSource> node
{
  my ($r, $n, $w) = @_;
  my $name = $n->getAttribute('platform');
  my $namePrefixed = ($name =~ m/\./) ? $name : FREProperties::SITE . '.' . $name;
  if ($namePrefixed eq $r->{platform})
  {
    $n->setAttribute('platform', $namePrefixed) if $namePrefixed ne $name;
    return 1;
  }
  else
  {
    $n->unbindNode();
    return 0;
  }
};

my $treeProcessCompile = sub($$$)
# ------ arguments: $object $node $verbose
# ------ special processing for the <compile> node
{
  my ($r, $n, $w) = @_;
  my $target = $n->getAttribute('target');
  if (!$target or FRETargets::contains($r->{target}, $target))
  {
    return 1;
  }
  else
  {
    $n->unbindNode();
    return 0;
  }
};

my $treeProcess;
$treeProcess = sub($$$)
# ------ arguments: $object $node $verbose
# ------ traverse the tree with properties expansion and special processing for some nodes
{
  my ($r, $n, $w) = @_;
  my $processChildrenFlag = 1;
  # -------------------------- expand properties in attributes values
  my @attrNodes = $n->attributes();
  foreach my $attrNode (@attrNodes)
  {
    my $value = $attrNode->getValue();
    $attrNode->setValue($placeholdersExpand->($r, $value)) if $value =~ m/\$/;
  }
  # ------------------------------------ expand properties in the text context
  my @textNodes = $n->findnodes('text()');
  foreach my $textNode (@textNodes)
  {
    my $data = $textNode->data();
    $textNode->setData($placeholdersExpand->($r, $data)) if $data =~ m/\$/;
  }
  # ------------------------------------------- special node processing
  my $nodeName = $n->nodeName();
  if ($nodeName eq 'property')
  {
    $processChildrenFlag = $treeProcessProperty->($r, $n, $w);
  }
  elsif ($nodeName eq 'platform')
  {
    $processChildrenFlag = $treeProcessPlatform->($r, $n, $w);
  }
  elsif ($nodeName eq 'dataSource')
  {
    $processChildrenFlag = $treeProcessDataSource->($r, $n, $w);
  }
  elsif ($nodeName eq 'compile')
  {
    $processChildrenFlag = $treeProcessCompile->($r, $n, $w);
  }
  # -------------------------------- process children
  if ($processChildrenFlag)
  {
    my @children = $n->findnodes('*');
    foreach my $child (@children)
    {
      $treeProcess->($r, $child, $w);
    }
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
  $r->{site} = FREProperties::SITE;
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
