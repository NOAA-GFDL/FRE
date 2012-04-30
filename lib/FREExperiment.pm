#
# $Id: FREExperiment.pm,v 18.1.2.13 2012/03/08 19:32:35 afy Exp $
# ------------------------------------------------------------------------------
# FMS/FRE Project: Experiment Management Module
# ------------------------------------------------------------------------------
# arl    Ver   18.1  Merged revision 18.0.2.1 onto trunk            March 10
# afy -------------- Branch 18.1.2 -------------------------------- March 10
# afy    Ver   1.00  Modify extractCheckoutInfo (add line numbers)  March 10
# afy    Ver   1.01  Modify createCheckoutScript (keep order)       March 10
# afy    Ver   2.00  Remove createCheckoutScript subroutine         May 10
# afy    Ver   2.01  Remove createCompileScript subroutine          May 10
# afy    Ver   3.00  Remove executable subroutine                   May 10
# arl    Ver   4.00  Modify extractCheckoutInfo (read property)     August 10
# afy    Ver   5.00  Modify extractCheckoutInfo (no CVSROOT)        August 10
# afy    Ver   6.00  Use new module FREMsg (symbolic levels)        January 11
# afy    Ver   6.01  Modify extractNodes (no 'required')            January 11
# afy    Ver   6.02  Modify extractValue (no 'required')            January 11
# afy    Ver   6.03  Modify extractComponentValue (no 'required')   January 11
# afy    Ver   6.04  Modify extractSourceValue (no 'required')      January 11
# afy    Ver   6.05  Modify extractCompileValue (no 'required')     January 11
# afy    Ver   6.06  Modify extractCheckoutInfo (hashes, checks)    January 11
# afy    Ver   6.07  Modify extractCompileInfo (hashes, checks)     January 11
# afy    Ver   6.08  Modify extractCompileInfo (make overrides)     January 11
# afy    Ver   6.09  Modify extractCompileInfo (libraries order)    January 11
# afy    Ver   7.00  Modify placeholdersExpand (check '$' presence) April 11
# afy    Ver   7.01  Add property subroutine (similar to FRE.pm)    April 11
# afy    Ver   7.02  Modify experimentDirsCreate (call property)    April 11
# afy    Ver   7.03  Modify experimentDirsVerify (call property)    April 11
# afy    Ver   7.04  Modify extractCheckoutInfo (call property)     April 11
# afy    Ver   7.05  Modify experimentCreate (don't pass '$fre')    April 11
# afy    Ver   8.00  Add dir subroutine                             May 11
# afy    Ver   8.01  Add stateDir subroutine                        May 11
# afy    Ver   8.02  Modify dir-returning subroutines (call dir)    May 11
# afy    Ver   9.00  Modify dir-returning subroutines (cosmetics)   May 11
# afy    Ver  10.00  Add extractRegressionRunInfo subroutine        November 11
# afy    Ver  10.01  Add extractProductionRunInfo subroutine        November 11
# afy    Ver  10.02  Add executable subroutine                      November 11
# afy    Ver  10.03  Add executableCanBeBuilt subroutine            November 11
# afy    Ver  10.04  Modify extractExecutable subroutine            November 11
# afy    Ver  11.00  Add extractRegressionLabels subroutine         January 12
# afy    Ver  12.00  Add sdtoutTmpDir subroutine                    February 12
# afy    Ver  13.00  Remove tmpDir subroutine                       March 12
# ------------------------------------------------------------------------------
# Copyright (C) NOAA Geophysical Fluid Dynamics Laboratory, 2009-2012
# Designed and written by V. Balaji, Amy Langenhorst and Aleksey Yakovlev
#

package FREExperiment;

use strict;

use List::Util();

use FREDefaults();
use FREMsg();
use FRETargets();
use FREUtil();

# //////////////////////////////////////////////////////////////////////////////
# ////////////////////////////////////////////////////////// Global Constants //
# //////////////////////////////////////////////////////////////////////////////

use constant DIRECTORIES => FREDefaults::ExperimentDirs();
use constant REGRESSION_SUITE => ('basic', 'restarts', 'scaling');

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
  return (exists($FREExperimentMap{$e})) ? $FREExperimentMap{$e} : '';
};

my $experimentDirsCreate = sub($)
# ------ arguments: $object
{
  my $r = shift;
  foreach my $t (FREExperiment::DIRECTORIES)
  {
    my $dirName = $t . 'Dir';
    $r->{$dirName} = $r->property($dirName);
  }
};

my $experimentDirsVerify = sub($$)
# ------ arguments: $object $expName
{
  my ($r, $e) = @_;
  my $result = 1;
  my ($fre, @expNamed) = ($r->fre(), split(';', $r->property('FRE.directory.expNamed')));
  foreach my $t (FREExperiment::DIRECTORIES)
  {
    my $d = $r->{$t . 'Dir'};
    if ($d)
    {
      # --------------------------------------------- check presence of the experiment name in the directory
      if (scalar(grep($_ eq $t, @expNamed)) > 0)
      {
	unless (FREUtil::dirContains($d, $e) > 0)
	{
	  $fre->out(FREMsg::FATAL, "The '$t' directory ($d) doesn't contain the experiment name");
	  $result = 0;
	  last;
	}
      }
      # -------------------------------------------------------- check placement the directory on the filesystem
      my $pathsMapping = $r->property('FRE.directory.' . $t . '.paths.mapping');
      if ($pathsMapping)
      {
        chomp(my $groupName = qx(id -gn));
        my $paths = FREUtil::strFindByPattern($pathsMapping, $groupName);
	if ($paths)
	{
	  my $pathsForMatch = $paths;
	  $pathsForMatch =~ s/\$/\\\$/g;
	  if ($d !~ m/^$pathsForMatch$/)
	  {
	    my @paths = split('\|', $paths);
	    my $pathsForOut = join(', ', @paths);
            $fre->out(FREMsg::FATAL, "The '$t' directory ($d) can't be set up - it must be one of ($pathsForOut)");
	    $result = 0;
	    last;
	  }
        }
	else
	{
	  $fre->out(FREMsg::FATAL, "The external property 'directory.$t.paths.mapping' is defined as '$pathsMapping' - this syntax is invalid");
	  $result = 0;
	  last;
	}
      }
      else
      {
        my $roots = $r->property('FRE.directory.' . $t . '.roots');
	if ($roots)
	{
	  my $rootsForMatch = $roots;
	  $rootsForMatch =~ s/\$/\\\$/g;
	  if (scalar(grep("$d/" =~ m/^$_\//, split(';', $rootsForMatch))) == 0)
	  {
	    my @roots = split(';', $roots);
	    my $rootsForOut = join(', ',  @roots);
	    $fre->out(FREMsg::FATAL, "The '$t' directory ($d) can't be set up - it must be on one of ($rootsForOut) filesystems");
            $result = 0;
	    last;
	  }
	}
	else
	{
	  $fre->out(FREMsg::FATAL, "The '$t' directory isn't bound by external properties");
	  $result = 0;
	  last;
	}
      }
    }
    else
    {
      $fre->out(FREMsg::FATAL, "The '$t' directory is empty");
      $result = 0;
      last;
    }
  }
  return $result;
};

my $experimentCreate;
$experimentCreate = sub($$$)
# ------ arguments: $className $fre $expName
# ------ create the experiment chain up to the root
{
  my ($c, $fre, $e) = @_;
  my $exp = $experimentFind->($e);
  if (!$exp)
  {
    my @experiments = $fre->experimentNames($e);
    if (scalar(grep($_ eq $e, @experiments)) > 0)
    {
      my $r = {};
      bless $r, $c;
      # ---------------------------- populate object fields
      $r->{fre} = $fre;
      $r->{name} = $e;
      $r->{node} = $fre->experimentNode($e);
      # ------------------------------------------------------ create and verify directories
      $experimentDirsCreate->($r);
      unless ($experimentDirsVerify->($r, $e))
      {
	$fre->out(FREMsg::FATAL, "The experiment '$e' can't be set up because of a problem with directories");
	return '';
      }
      # ------------------------------------------------------------- find and create the parent if needed
      my $expParentName = $r->experimentValue('@inherit');
      if ($expParentName)
      {
	if (scalar(grep($_ eq $expParentName, @experiments)) > 0)
	{
          $r->{parent} = $experimentCreate->($c, $fre, $expParentName);
	}
	else
	{
	  $fre->out(FREMsg::FATAL, "The experiment '$e' inherits from non-existent experiment '$expParentName'");
	  return '';
	}
      }
      else
      {
        $r->{parent} = '';
      }
      # ----------------------------------------------------------------------- save the experiment
      $FREExperimentMap{$e} = $r;
      # ----------------------------------------- return the newly created object handle
      return $r;
    }
    else
    {
      # ------------------------------------- experiment doesn't exist
      $fre->out(FREMsg::FATAL, "The experiment '$e' doesn't exist");
      return '';
    }
  }
  else
  {
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
  my ($h, $c, $d) = @_;
  if ($d < scalar(keys %{$h}))
  {
    my @requires = split(' ', $c->{requires});
    if (scalar(@requires) > 0)
    {
      my $rank = 0; 
      foreach my $required (@requires)
      {
        my $refReq = $h->{$required};
	my $rankReq = (defined($refReq->{rank})) ? $refReq->{rank} : $rankSet->($h, $refReq, $d + 1);
        if ($rankReq < 0)
	{
	  return -1;
	}
	elsif ($rankReq > $rank)
	{
	  $rank = $rankReq;
	}
      }
      $rank++;
      $c->{rank} = $rank;
      return $rank;
    }
    else
    {
      $c->{rank} = 0;
      return 0;
    }
  }
  else
  {
    return -1;
  }
};
    
my $regressionRunNode = sub($$)
# ------ arguments: $object $label
{
  my ($r, $l) = @_;
  my @regNodes = $r->extractNodes('runtime', 'regression[@label="' . $l . '" or @name="' . $l . '"]');
  return (scalar(@regNodes) == 1) ? $regNodes[0] : undef;
};

my $productionRunNode = sub($)
# ------ arguments: $object
{
  my $r = shift;
  my @prdNodes = $r->extractNodes('runtime', 'production');
  return (scalar(@prdNodes) == 1) ? $prdNodes[0] : undef;
};

# //////////////////////////////////////////////////////////////////////////////
# ////////////////////////////////////////// Class initialization/termination //
# //////////////////////////////////////////////////////////////////////////////

sub new($$$)
# ------ arguments: $className $fre $expName
# ------ called as class method
# ------ creates an object and populates it 
{
  my ($c, $fre, $e) = @_;
  return $experimentCreate->($c, $fre, $e);
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
  my ($r, $t) = @_;
  return $r->{$t . 'Dir'};
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

sub placeholdersExpand($$)
# ------ arguments: $object $string
# ------ called as object method
# ------ expand all the experiment level placeholders in the given $string
{
  my ($r, $s) = @_;
  if (index($s, '$') >= 0)
  {
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
  my ($r, $k) = @_;
  return $r->placeholdersExpand($r->fre()->property($k));
};

sub nodeValue($$$)
# ------ arguments: $object $node $xPath
# ------ called as object method
# ------ return $xPath value relative to the given $node 
{
  my ($r, $n, $x) = @_;
  return $r->placeholdersExpand($r->fre()->nodeValue($n, $x));
}

sub experimentValue($$)
# ------ arguments: $object $xPath
# ------ called as object method
# ------ return $xPath value relative to the experiment node 
{
  my ($r, $x) = @_;
  return $r->nodeValue($r->node(), $x);
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
  my ($execDir, $name) = ($r->execDir(), $r->name());
  return "$execDir/fms_$name.x";
}

sub executableCanBeBuilt($)
# ------ arguments: $object
# ------ called as object method
# ------ return 1 if the executable for the given experiment can be built
{
  my $r = shift;
  return
  (
    $r->experimentValue('*/source/codeBase') ne ''
    ||
    $r->experimentValue('*/source/csh') ne ''
    ||
    $r->experimentValue('*/compile/cppDefs') ne ''
    ||
    $r->experimentValue('*/compile/srcList') ne ''
    ||
    $r->experimentValue('*/compile/pathNames') ne ''
    ||
    $r->experimentValue('*/compile/csh') ne ''
  );       
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
  my ($r, $x, $y) = @_;
  my ($exp, @results) = ($r, ());
  while ($exp and scalar(@results) == 0)
  {
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
  my ($r, $x) = @_;
  my ($exp, $value) = ($r, '');
  while ($exp and !$value)
  {
    $value = $exp->experimentValue($x);
    $exp = $exp->parent();
  }
  return $value;
}

sub extractComponentValue($$$)
# ------ arguments: $object $xPath $componentName
# ------ called as object method
# ------ return a value corresponding to the $xPath under the <component> node, following inherits
{
  my ($r, $x, $c) = @_;
  my ($exp, $value) = ($r, '');
  while ($exp and !$value)
  {
    $value = $exp->experimentValue('component[@name="' . $c . '"]/' . $x);
    $exp = $exp->parent();
  }
  return $value;
}

sub extractSourceValue($$$)
# ------ arguments: $object $xPath $componentName
# ------ called as object method
# ------ return a value corresponding to the $xPath under the <component/source> node, following inherits
{
  my ($r, $x, $c) = @_;
  my ($exp, $value) = ($r, '');
  while ($exp and !$value)
  {
    $value = $exp->experimentValue('component[@name="' . $c . '"]/source/' . $x);
    $exp = $exp->parent();
  }
  return $value;
}

sub extractCompileValue($$$)
# ------ arguments: $object $xPath $componentName
# ------ called as object method
# ------ return a value corresponding to the $xPath under the <component/compile> node, following inherits
{
  my ($r, $x, $c) = @_;
  my ($exp, $value) = ($r, '');
  while ($exp and !$value)
  {
    $value = $exp->experimentValue('component[@name="' . $c . '"]/compile/' . $x);
    $exp = $exp->parent();
  }
  return $value;
}

sub extractExecutable($)
# ------ arguments: $object
# ------ called as object method
# ------ return predefined executable name (if found) and experiment object, following inherits
{

  my $r = shift;
  my ($exp, $fre, $makeSenseToCompile, @results) = ($r, $r->fre(), undef, ());

  while ($exp)
  {
    $makeSenseToCompile = $exp->executableCanBeBuilt();
    @results = $fre->dataFilesMerged($exp->node(), 'executable', 'file');
    last if scalar(@results) > 0 || $makeSenseToCompile;
    $exp = $exp->parent();
  }

  if (scalar(@results) > 0)
  {
    $fre->out(FREMsg::WARNING, "The executable name is predefined more than once - all the extra definitions are ignored") if scalar(@results) > 1;
    return (@results[0], $exp);
  }
  elsif ($makeSenseToCompile)
  {
    return (undef, $exp);
  }
  else
  {
    return (undef, undef);
  }

}

sub extractMkmfTemplate($$)
# ------ arguments: $object $componentName
# ------ called as object method
# ------ extracts a mkmf template, following inherits
{

  my ($r, $c) = @_;
  my ($exp, $fre, @results) = ($r, $r->fre(), ());

  while ($exp and scalar(@results) == 0)
  {
    my @nodes = $exp->node()->findnodes('component[@name="' . $c . '"]/compile');
    foreach my $node (@nodes) {push @results, $fre->dataFilesMerged($node, 'mkmfTemplate', 'file');}
    $exp = $exp->parent();
  }
  
  $fre->out(FREMsg::WARNING, "The '$c' component mkmf template is defined more than once - all the extra definitions are ignored") if scalar(@results) > 1;
  return @results[0];

}

sub extractDatasets($)
# ------ arguments: $object
# ------ called as object method
# ------ extracts file pathnames together with their target names, following inherits
{

  my $r = shift;
  my ($exp, $fre, @results) = ($r, $r->fre(), ());

  while ($exp and scalar(@results) == 0)
  {
    # --------------------------------------------- get the input node
    my $inputNode = $exp->node()->findnodes('input')->get_node(1);
    # ------------------------------------------------ process the input node
    if ($inputNode)
    {
      # ----------------------------------------------------- get <dataFile> nodes
      push @results, $fre->dataFiles($inputNode, 'input');
      # ----------------------------------------------------- get nodes in the old format
      my @nodesForCompatibility = $inputNode->findnodes('fmsDataSets');
      foreach my $node (@nodesForCompatibility)
      {
	my $sources = $exp->nodeValue($node, 'text()');
	my @sources = split(/\s+/, $sources);
	foreach my $line (@sources)
	{
          next unless $line;
	  if (substr($line, 0, 1) eq '/')
	  {
	    my @lineParts = split('=', $line);
	    if (scalar(@lineParts) > 2)
	    {
	      $fre->out(FREMsg::WARNING, "Too many names for renaming are defined at '$line' - all the extra names are ignored");
	    }
	    my ($source, $target) = @lineParts;
	    if ($target)
	    {
	      $target = 'INPUT/' . $target;
	    }
	    else
	    {
	      $target = FREUtil::fileIsArchive($source) ? 'INPUT/' : 'INPUT/.';
            }
            push @results, $source;
	    push @results, $target;
	  }
	  else
	  {
	    push @results, $line;
	    push @results, '';
	  }
	}
      }
    }
    # ---------------------------- repeat for the parent
    $exp = $exp->parent();
  } 

  return @results;

}

sub extractNamelists($)
# ------ arguments: $object
# ------ called as object method
# ------ reads nmls from xml, puts into hash, i.e. $nml{'mpp_nml'}='$content'
# ------ reads and parse nmls from file(s), puts into hash, doesn't overwrite existing hash entries
# ------ following inherits, but doesn't overwrite existing hash entries
# ------ returns namelists hash
{

  my $r = shift;
  my ($exp, $fre, %res) = ($r, $r->fre(), ());

  $fre->out(FREMsg::NOTE, "Extracting namelists...");
  
  while ($exp)
  {
    # -------------------------------------------- get the input node
    my $inputNode = $exp->node()->findnodes('input')->get_node(1);
    # ------------------------------------------------ process the input node
    if ($inputNode)
    {
      # ----------------------------------- get inline namelists (they take precedence)
      my @inlineNmlNodes = $inputNode->findnodes('namelist[@name]');        
      foreach my $inlineNmlNode (@inlineNmlNodes)
      {
	my $name = FREUtil::cleanstr($exp->nodeValue($inlineNmlNode, '@name'));
	my $content = $exp->nodeValue($inlineNmlNode, 'text()');
	$content =~ s/^\s*$//mg;
	$content =~ s/^\n//;
	$content =~ s/\s*(?:\/\s*)?$//;
	if (exists($res{$name}))
	{
	  my $expName = $exp->name();
          $fre->out(FREMsg::NOTE, "Using secondary specification of '$name' rather than the original setting in '$expName'");
	}
	elsif ($name)
	{
          $res{$name} = defined($content) ? $content : "";
	}
      }
      # --------------------------------------------------------------- get namelists from files
      my @nmlFiles = $fre->dataFilesMerged($inputNode, 'namelist', 'file');
      foreach my $filePath (@nmlFiles)
      {
        if (-f $filePath and -r $filePath)
	{
	  my $fileContent = qx(cat $filePath);
	  $fileContent =~ s/^\s*$//mg;
	  $fileContent =~ s/^\s*#.*$//mg;
	  $fileContent = $fre->placeholdersExpand($fileContent);
	  $fileContent = $exp->placeholdersExpand($fileContent);
	  my @fileNmls = split(/\/\s*$/m, $fileContent);
	  foreach my $fileNml (@fileNmls)
	  {
            $fileNml =~ s/^\s*\&//;
            $fileNml =~ s/\s*(?:\/\s*)?$//;
            my ($name, $content) = split('\s', $fileNml, 2);
            if (exists($res{$name}))
	    {
              $fre->out(FREMsg::NOTE, "Using secondary specification of '$name' rather than the original setting in '$filePath'");
            }
	    elsif ($name)
	    {
              $res{$name} = defined($content) ? $content : "";
            }
	  }
        }
	else
	{
	  return (-1 => 0);
	}
      }
    }
    # ---------------------------- repeat for the parent
    $exp = $exp->parent();
  }

  return %res;

}

sub extractTable($$)
# ------ arguments: $object $label
# ------ called as object method
# ------ returns data, corresponding to the $label table, following inherits 
{

  my ($r, $l) = @_;
  my ($exp, $fre, $value) = ($r, $r->fre(), '');

  while ($exp and !$value)
  {
    # ------------------------------------------- get the input node
    my $inputNode = $exp->node()->findnodes('input')->get_node(1);
    # --------------------------------------------- process the input node
    if ($inputNode)
    {
      # ----------------- get inline tables (they must be before tables from files)
      my @inlineTableNodes = $inputNode->findnodes($l . '[not(@file)]');
      foreach my $inlineTableNode (@inlineTableNodes)
      {
	$value .= $exp->nodeValue($inlineTableNode, 'text()');
      }
      # --------------------------------------------------------------- get tables from files
      my @tableFiles = $fre->dataFilesMerged($inputNode, $l, 'file');
      foreach my $filePath (@tableFiles)
      {
        if (-f $filePath and -r $filePath)
	{
	  my $fileContent = qx(cat $filePath);
	  $fileContent = $fre->placeholdersExpand($fileContent);
	  $fileContent = $exp->placeholdersExpand($fileContent);
	  $value .= $fileContent;
	}
	else
	{
	  return -1;
	}
      }
    }
    # ---------------------------- repeat for the parent
    $exp = $exp->parent();
  }

  $value =~ s/\n\s*\n/\n/sg;
  $value =~ s/^\s*\n\s*//s;
  $value =~ s/\s*\n\s*$//s;
  
  return $value;

}

sub extractShellCommands($$%)
# ------ arguments: $object $xPath %adjustment
# ------ called as object method
# ------ returns shell commands, corresponding to the $xPath, following inherits
# ------ adjusts commands, depending on node types
{

  my ($r, $x, %a) = @_;
  my ($exp, $value) = ($r, '');

  while ($exp and !$value)
  {
    my @nodes = $exp->node()->findnodes($x);
    foreach my $node (@nodes)
    {
      my $type = $exp->nodeValue($node, '@type');
      my $content = $exp->nodeValue($node, 'text()');
      if (defined(%a) and exists($a{$type})) {$content = $a{$type}[0].$content.$a{$type}[1];}
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

  my ($r, $l) = @_;
  my ($exp, $fre, @results) = ($r, $r->fre(), ());

  while ($exp and scalar(@results) == 0)
  {
    my $inputNode = $exp->node()->findnodes('input')->get_node(1);
    push @results, $fre->dataFilesMerged($inputNode, $l, 'file') if $inputNode;
    $exp = $exp->parent();
  } 

  $fre->out(FREMsg::WARNING, "The variable '$l' is defined more than once - all the extra definitions are ignored") if scalar(@results) > 1;
  return @results[0];

}

sub extractReferenceFiles($)
# ------ arguments: $object
# ------ called as object method
# ------ return list of reference files, following inherits
{

  my $r = shift;
  my ($exp, $fre, @results) = ($r, $r->fre(), ());

  while ($exp and scalar(@results) == 0)
  {
    my $runTimeNode = $exp->node()->findnodes('runtime')->get_node(1);
    push @results, $fre->dataFilesMerged($runTimeNode, 'reference', 'restart') if $runTimeNode;
    $exp = $exp->parent();
  }
  
  return @results;

}

sub extractReferenceExperiments($)
# ------ arguments: $object
# ------ called as object method
# ------ return list of reference experiment names, following inherits
{
  my ($r, @results) = (shift, ());
  my @nodes = $r->extractNodes('runtime', 'reference/@experiment');
  foreach my $node (@nodes) {push @results, $r->nodeValue($node, '.');}
  return @results;
}

sub extractPPRefineDiagScripts($)
# ------ arguments: $object
# ------ called as object method
# ------ return list of postprocessing refine diagnostics scriptnames, following inherits 
{
  my ($r, @results) = (shift, ());
  my @nodes = $r->extractNodes('postProcess', 'refineDiag/@script');
  foreach my $node (@nodes) {push @results, $r->nodeValue($node, '.');}
  return @results;
}

sub extractCheckoutInfo($)
# ------ arguments: $object
# ------ called as object method
# ------ return a reference to checkout info, following inherits
{

  my $r = shift;
  my ($fre, $expName, @componentNodes) = ($r->fre(), $r->name(), $r->node()->findnodes('component'));
  
  if (scalar(@componentNodes) > 0)
  {
    my %components;
    foreach my $componentNode (@componentNodes)
    {
      my $name = $r->nodeValue($componentNode, '@name');
      if ($name)
      {
	$fre->out(FREMsg::NOTE, "COMPONENTLOOP ((($name)))");
	if (!exists($components{$name}))
	{
	  # ------------------------------------- get and check library data; skip the component if the library defined  
	  my $libraryPath = $r->extractComponentValue('library/@path', $name);
	  if ($libraryPath)
	  {
	    if (-f $libraryPath)
	    {
	      my $libraryHeaderDir = $r->extractComponentValue('library/@headerDir', $name);
	      if ($libraryHeaderDir)
	      {
		if (-d $libraryHeaderDir)
		{
        	  $fre->out(FREMsg::NOTE, "You have requested library '$libraryPath' for component '$name' - we will skip the component checkout");
        	  next;
		}
		else
		{
        	  $fre->out(FREMsg::FATAL, "Component '$name' specifies non-existent library header directory '$libraryHeaderDir'");
		  return 0;
		}
	      }
	      else
	      {
        	$fre->out(FREMsg::FATAL, "Component '$name' specifies library '$libraryPath' but no header directory");
        	return 0;
	      }
	    }
	    else
	    {
              $fre->out(FREMsg::FATAL, "Component '$name' specifies non-existent library '$libraryPath'");
	      return 0;
	    }	 
	  }
	  # ------------------------------------------------------------------------------- get and check component data for sources checkout
	  my $codeBase = $strMergeWS->($r->extractSourceValue('codeBase', $name));
	  if ($codeBase)
	  {
	    my $codeTag = $strRemoveWS->($r->extractSourceValue('codeBase/@version', $name));
	    if ($codeTag)
	    {
	      my $vcBrand = $strRemoveWS->($r->extractSourceValue('@versionControl', $name)) || 'cvs';
	      if ($vcBrand)
	      {
		my $vcRoot = $strRemoveWS->($r->extractSourceValue('@root', $name)) || $r->property('FRE.versioncontrol.cvs.root');
		if ($vcRoot =~ m/^:ext:/ or (-d $vcRoot and -r $vcRoot))
		{
		  # ------------------------------------------------------------------------------------------ save component data into the hash
        	  my %component = ();
		  $component{codeBase} = $codeBase;
		  $component{codeTag} = $codeTag;
		  $component{vcBrand} = $vcBrand;
		  $component{vcRoot} = $vcRoot;
		  $component{sourceCsh} = $r->extractSourceValue('csh', $name);
        	  $component{lineNumber} = $componentNode->line_number();
		  # ----------------------------------------------------------------------------------------------- print what we got
		  $fre->out
		  (
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
        	}
		else
		{
        	  $fre->out(FREMsg::FATAL, "Component '$name': the directory '$vcRoot' doesn't exist or not readable");
		  return 0;
		}
              }
	      else
	      {
        	$fre->out(FREMsg::FATAL, "Component '$name': element <source> doesn't specify a version control system");
		return 0;
	      }
	    }
	    else
	    {
              $fre->out(FREMsg::FATAL, "Component '$name': element <source> doesn't specify a version attribute for its code base");
	      return 0;
	    }
	  }
	  else
	  {
            $fre->out(FREMsg::FATAL, "Component '$name': element <source> doesn't specify a code base");
	    return 0;
	  }
	}
	else
	{
	  $fre->out(FREMsg::FATAL, "Component '$name' is defined more than once - make sure each component has a distinct name");
	  return 0;
	}
      }
      else
      {
	$fre->out(FREMsg::FATAL, "Components with empty names aren't allowed");
	return 0;
      }
    }
    return \%components;  
  }
  else
  {
    $fre->out(FREMsg::FATAL, "The experiment '$expName' doesn't contain any components");
    return 0;
  }

}

sub extractCompileInfo($)
# ------ arguments: $object
# ------ called as object method
# ------ return a reference to compile info
{

  my $r = shift;
  my ($fre, $expName, @componentNodes) = ($r->fre(), $r->name(), $r->node()->findnodes('component'));
  
  if (scalar(@componentNodes) > 0)
  {
    my %components;
    foreach my $componentNode (@componentNodes)
    {
      # ----------------------------------------- get and check the component name
      my $name = $r->nodeValue($componentNode, '@name');
      if ($name)
      {
	$fre->out(FREMsg::NOTE, "COMPONENTLOOP: ((($name)))");
	if (!exists($components{$name}))
	{
	  # ----------------------------------------------- get and check component data for compilation
	  my $paths = $strMergeWS->($r->nodeValue($componentNode, '@paths'));
	  if ($paths)
	  {
	    # -------------------------------------------------------------------- get and check include directories
	    my $includeDirs = $strMergeWS->($r->extractComponentValue('@includeDir', $name));
	    if ($includeDirs)
	    {
	      foreach my $includeDir (split(' ', $includeDirs))
	      {
        	if (! -d $includeDir)
        	{
        	  $fre->out(FREMsg::FATAL, "Component '$name' specifies non-existent include directory '$includeDir'");
  		  return 0;
		}
	      }
	    }
	    # --------------------------------------------- get and check library data; skip the component if the library defined  
	    my $libPath = $strRemoveWS->($r->extractComponentValue('library/@path', $name));
            my $libHeaderDir = $strRemoveWS->($r->extractComponentValue('library/@headerDir', $name));
	    if ($libPath)
	    {
	      if (-f $libPath)
	      {
		if ($libHeaderDir)
		{
		  if (-d $libHeaderDir)
		  {
        	    $fre->out(FREMsg::NOTE, "You have requested library '$libPath' for component '$name': we will skip the component compilation");
		  }
		  else
		  {
        	    $fre->out(FREMsg::FATAL, "Component '$name' specifies non-existent library header directory '$libHeaderDir'");
		    return 0;
		  }
		}
		else
		{
        	  $fre->out(FREMsg::FATAL, "Component '$name' specifies library '$libPath' but no header directory");
		  return 0;
		}
	      }
	      else
	      {
        	$fre->out(FREMsg::FATAL, "Component '$name' specifies non-existent library '$libPath'");
		return 0;
	      }	 
	    }
	    # ----------------------------------------------------------------------------------- save component data into the hash
            my %component = ();
	    $component{paths} = $paths;
	    $component{requires} = $strMergeWS->($r->nodeValue($componentNode, '@requires'));
	    $component{includeDirs} = $includeDirs;
            $component{libPath} = $libPath;
            $component{libHeaderDir} = $libHeaderDir;
	    $component{srcList} = $strMergeWS->($r->extractCompileValue('srcList', $name));
	    $component{pathNames} = $strMergeWS->($r->extractCompileValue('pathNames/@file', $name));
	    $component{cppDefs} = FREUtil::strStripPaired($strMergeWS->($r->extractCompileValue('cppDefs', $name)));
	    $component{makeOverrides} = $strMergeWS->($r->extractCompileValue('makeOverrides', $name));
	    $component{compileCsh} = $r->extractCompileValue('csh', $name);
	    $component{mkmfTemplate} = $strRemoveWS->($r->extractMkmfTemplate($name)) || $fre->mkmfTemplate();
            $component{lineNumber} = $componentNode->line_number();
	    $component{rank} = undef;
	    # ------------------------------------------------------------------------------------------- print what we got
	    $fre->out
	    (
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
	  }
	  else
	  {
	    $fre->out(FREMsg::FATAL, "Component '$name' doesn't specify the mandatory 'paths' attribute");
	    return 0; 
	  }
	}
	else
	{
	  $fre->out(FREMsg::FATAL, "Component '$name' is defined more than once - make sure each component has a distinct name");
	  return 0;
	}
      }
      else
      {
	$fre->out(FREMsg::FATAL, "Components with empty names aren't allowed");
	return 0;
      }
    }
    # ------------------------------------------------------------------ verify intercomponent references
    foreach my $name (keys %components)
    {
      my $ref = $components{$name};
      foreach my $required (split(' ', $ref->{requires}))
      {
        if (!exists($components{$required}))
	{
	  $fre->out(FREMsg::FATAL, "Component '$name' refers to a non-existent component '$required'");
	  return 0;
	}
      }
    }      
    # ------------------------------------------------------------------- compute components ranks      
    foreach my $name (keys %components)
    {
      my $ref = $components{$name};
      if (!defined($ref->{rank}))
      {
        if ($rankSet->(\%components, $ref, 0) < 0)
	{
	  $fre->out(FREMsg::FATAL, "Component '$name' refers to itself via a loop");
	  return 0;
	}
      }
    }
    # ------------------------------------------------------------------------ normal return
    return \%components;
  }
  else
  {
    $fre->out(FREMsg::FATAL, "The experiment '$expName' doesn't contain any components");
    return 0;
  }
     
}

sub extractRegressionLabels($)
# ------ arguments: $object
{
  my $r = shift;
  my @labels = ();
  foreach my $node ($r->extractNodes('runtime', 'regression'))
  {
    my $label = $r->nodeValue($node, '@label') || $r->nodeValue($node, '@name');
    push @labels, $label if $label;
  }
  return @labels;
}

sub extractRegressionRunInfo($$)
# ------ arguments: $object $label
# ------ called as object method
# ------ return a reference to the regression run info
{
  my ($r, $l) = @_;
  my ($fre, $expName) = ($r->fre(), $r->name()); 
  if ($l eq 'suite')
  {
    my ($ok, %runs) = (1, ());
    foreach my $label (REGRESSION_SUITE)
    {
      my $runsForLabel = $r->extractRegressionRunInfo($label);
      if ($runsForLabel)
      {
        foreach my $postfix (keys(%{$runsForLabel}))
	{
	  if (!exists($runs{$postfix}))
	  {
	    $runs{$postfix} = $runsForLabel->{$postfix};
	  }
	  else
	  {
	    my $i = $runsForLabel->{$postfix}->{number};
            $fre->out(FREMsg::FATAL, "The experiment '$expName', the regression test '$label', run '$i' - a run with these timing parameters already exists");
	    $ok = 0; 
	  }
	}
      }
      else
      {
        $ok = 0;
      }
    }
    return ($ok) ? \%runs : 0;
  }
  else
  {
    my $regNode = $regressionRunNode->($r, $l);
    if ($regNode)
    {
      my @runNodes = $regNode->findnodes('run');
      if (scalar(@runNodes) > 0)
      {
	my ($ok, %runs) = (1, ());
	for (my $i = 0; $i < scalar(@runNodes); $i++)
	{
	  my $nps = $r->nodeValue($runNodes[$i], '@npes');
	  my $msl = $r->nodeValue($runNodes[$i], '@months');
	  my $dsl = $r->nodeValue($runNodes[$i], '@days');
	  my $hsl = $r->nodeValue($runNodes[$i], '@hours');
	  my $srt = $r->nodeValue($runNodes[$i], '@runTimePerJob');
	  if ($nps > 0)
	  {
	    my $patternRunTime = qr/^\d\d:\d\d:\d\d$/;
	    if ($srt =~ m/$patternRunTime/)
	    {
	      if ($msl or $dsl or $hsl)
	      {
		my @msa = split(' ', $msl);
		my @dsa = split(' ', $dsl);
		my @hsa = split(' ', $hsl);
		my $spj = List::Util::max(scalar(@msa), scalar(@dsa), scalar(@hsa));
		while (scalar(@msa) < $spj) {push(@msa, '0');}
		while (scalar(@dsa) < $spj) {push(@dsa, '0');}
		while (scalar(@hsa) < $spj) {push(@hsa, '0');}
		my $postfix = ($hsl) ? "${spj}x$msa[0]m$dsa[0]d$hsa[0]h_${nps}pe" : "${spj}x$msa[0]m$dsa[0]d_${nps}pe";
		if (!exists($runs{$postfix}))
		{
        	  my %run = ();
		  $run{label} = $l;
		  $run{number} = $i;
		  $run{npes} = $nps;
		  $run{months} = join(' ', @msa);
		  $run{days} = join(' ', @dsa);
		  $run{hours} = join(' ', @hsa);
 		  $run{runTimeMinutes} = FREUtil::makeminutes($srt);
		  $runs{$postfix} = \%run;
		}
		else
		{
        	  $fre->out(FREMsg::FATAL, "The experiment '$expName', the regression test '$l', run '$i' - a run with these timing parameters already exists");
		  $ok = 0; 
		}
	      }
	      else
	      {
        	$fre->out(FREMsg::FATAL, "The experiment '$expName', the regression test '$l', run '$i' - timing parameters must be defined");
		$ok = 0; 
	      }
	    }
	    else
	    {
              $fre->out(FREMsg::FATAL, "The experiment '$expName', the regression test '$l', run '$i' - the running time '$srt' must be nonempty and have the HH:MM:SS format");
	      $ok = 0; 
	    }
	  }
	  else
	  {
	    $fre->out(FREMsg::FATAL, "The experiment '$expName', the regression test '$l', run '$i' - a positive number of cores to run on must be defined");
	    $ok = 0;
	  }
	}
	return ($ok) ? \%runs : 0;
      }
      else
      {
	$fre->out(FREMsg::FATAL, "The experiment '$expName' - the regression test '$l' doesn't have any runs");
	return 0;
      }
    }
    else
    {
      $fre->out(FREMsg::FATAL, "The experiment '$expName' - the regression test '$l' doesn't exist or defined more than once");
      return 0;
    }
  }
}

sub extractProductionRunInfo($)
# ------ arguments: $object
# ------ called as object method
# ------ return a reference to the production run info
{
  my $r = shift;
  my ($fre, $expName) = ($r->fre(), $r->name());
  my $prdNode = $productionRunNode->($r);
  if ($prdNode)
  {
    my $nps = $r->nodeValue($prdNode, '@npes');
    my $smt = $r->nodeValue($prdNode, '@simTime');
    my $smu = $r->nodeValue($prdNode, '@units');
    my $srt = $r->nodeValue($prdNode, '@runTime') || $fre->runTime($nps);
    my $gmt = $r->nodeValue($prdNode, 'segment/@simTime');
    my $gmu = $r->nodeValue($prdNode, 'segment/@units');
    my $grt = $r->nodeValue($prdNode, 'segment/@runTime');
    if ($nps > 0)
    {
      my $patternUnits = qr/^(?:years|year|months|month)$/;
      if (($smt > 0) and ($smu =~ m/$patternUnits/))
      {
        if (($gmt > 0) and ($gmu =~ m/$patternUnits/))
	{
	  my $patternYears = qr/^(?:years|year)$/;
	  $smt *= 12 if $smu =~ m/$patternYears/;
	  $gmt *= 12 if $gmu =~ m/$patternYears/;
	  if ($gmt <= $smt)
	  {
	    my $patternRunTime = qr/^\d\d:\d\d:\d\d$/;
	    if ($srt =~ m/$patternRunTime/)
	    {
	      if ($grt =~ m/$patternRunTime/)
	      {
		my ($srtMinutes, $grtMinutes) = (FREUtil::makeminutes($srt), FREUtil::makeminutes($grt));
		if ($grtMinutes <= $srtMinutes)
		{
		  my %run = ();
		  $run{npes} = $nps;
		  $run{simTimeMonths} = $smt;
		  $run{simRunTimeMinutes} = $srtMinutes;
		  $run{segTimeMonths} = $gmt;
		  $run{segRunTimeMinutes} = $grtMinutes;
		  return \%run;
		}
		else
		{
		  $fre->out(FREMsg::FATAL, "The experiment '$expName' - the segment running time '$grtMinutes' must not exceed the maximum job running time allowed '$srtMinutes'");
		  return 0; 
		}
	      }
	      else
	      {
        	$fre->out(FREMsg::FATAL, "The experiment '$expName' - the segment running time '$grt' must be nonempty and have the HH:MM:SS format");
		return 0; 
	      }
	    }
	    else
	    {
              $fre->out(FREMsg::FATAL, "The experiment '$expName' - the simulation running time '$srt' must be nonempty and have the HH:MM:SS format");
	      return 0; 
	    }
	  }
	  else
	  {
	    $fre->out(FREMsg::FATAL, "The experiment '$expName' - the segment model time '$gmt' must not exceed the simulation model time '$smt'");
	    return 0; 
	  }
	}
	else
	{
          $fre->out(FREMsg::FATAL, "The experiment '$expName' - the segment model time '$gmt' must be nonempty and have one of (years|year|months|month) units defined");
	  return 0; 
	}
      }
      else
      {
        $fre->out(FREMsg::FATAL, "The experiment '$expName' - the simulation model time '$smt' must be nonempty and have one of (years|year|months|month) units defined");
	return 0; 
      }
    }
    else
    {
      $fre->out(FREMsg::FATAL, "The experiment '$expName' - a positive number of cores to run on must be defined");
      return 0; 
    }
  }
  else
  {
    $fre->out(FREMsg::FATAL, "The experiment '$expName' - production timing parameters aren't defined or defined more than once");
    return 0;
  }
}

# //////////////////////////////////////////////////////////////////////////////
# //////////////////////////////////////////////////////////// Initialization //
# //////////////////////////////////////////////////////////////////////////////

return 1;
