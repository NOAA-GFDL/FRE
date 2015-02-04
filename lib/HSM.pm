#
# $Id: HSM.pm,v 1.1.2.10 2012/09/02 02:57:20 afy Exp $
# ------------------------------------------------------------------------------
# FMS/FRE Project: HSM Main Library Module
# ------------------------------------------------------------------------------
# afy    Ver   1.00  Initial version                                October 11
# afy    Ver   2.00  Add 'pathIsMountable' subroutine               November 11
# afy    Ver   2.01  Add 'elements' utility                         November 11
# afy    Ver   2.02  Add 'directories' utility                      November 11
# afy    Ver   2.03  Add 'permissions' utility                      November 11
# afy    Ver   2.04  Add 'removeElement' utility                    November 11
# afy    Ver   2.05  Add 'scrub' subroutine                         November 11
# afy    Ver   3.00  Modify 'tryLock' (handling the EEXIST error)   December 11
# afy    Ver   3.01  Add 'alignAccessTime' subroutine               December 11
# afy    Ver   3.02  Rename 'scrub' => 'remove' subroutine          December 11
# afy    Ver   3.03  Modify 'tryLock' (return 0 in doubtful cases)  December 11
# afy    Ver   4.00  Add 'setAccessTime' utility                    December 11
# afy    Ver   4.01  Modify 'alignAccessTime' subroutine            December 11
# afy    Ver   5.00  Modify 'setAccessTime' utility (add check)     January 12
# afy    Ver   6.00  Modify 'unlock' (add flock(..., LOCK_UN))      March 12
# afy    Ver   7.00  Remove 'unlockHandle'                          May 12
# afy    Ver   7.01  Modify 'lockHandle' (write signature in file)  May 12
# afy    Ver   7.02  Modify 'tryLock' (return ref to hash)          May 12
# afy    Ver   7.03  Modify 'unlock' (accept ref to hash)           May 12
# afy    Ver   7.04  Modify 'remove' (pass ref to unlock)           May 12
# afy    Ver   8.00  Add locking via the 'File::NFSLock' module     May 12
# afy    Ver   8.01  Modify 'lock' (use time increase rate)         May 12
# afy    Ver   8.02  Add 'lockingInfo' subroutine                   May 12
# afy    Ver   9.00  Fix 'SITE_CURRENT' constant                    May 12
# afy    Ver  10.00  Add 'getCache' subroutine                      September 12
# afy    Ver  10.01  Enhanced globbing @ 'gfdl' site only           September 12
# ------------------------------------------------------------------------------
# Copyright (C) NOAA Geophysical Fluid Dynamics Laboratory, 2000-2012
# Designed and written by V. Balaji, Amy Langenhorst and Aleksey Yakovlev
#

package HSM;

use strict;

use Fcntl();
use File::Basename();
use File::NFSLock();
use File::Path();
use File::stat;
use POSIX();
use Sys::Hostname();

# //////////////////////////////////////////////////////////////////////////////
# ////////////////////////////////////////////////////////// Global Constants //
# //////////////////////////////////////////////////////////////////////////////

use constant SITE_CURRENT => $ENV{FRE_SYSTEM_SITE};
use constant SITES_NFSLOCK => ('gfdl');
use constant SITES_GLOBENHANCED => ('gfdl');

use constant HOSTNAME => Sys::Hostname::hostname();

use constant EXTENSION_LOCK => '.LOCK';
use constant EXTENSION_OK => '.ok';

use constant TIME_TO_WAIT_DEFAULT => 30;
use constant TIME_TO_WAIT_INCREASE_RATE => 1.25;

# //////////////////////////////////////////////////////////////////////////////
# ////////////////////////////////////////////////////////// Global Variables //
# //////////////////////////////////////////////////////////////////////////////

my ($HSMTryLock, $HSMUnlock, $HSMLockingInfo, $HSMGlob) = (undef, undef, undef, undef);

# //////////////////////////////////////////////////////////////////////////////
# ///////////////////////////////////////////// Locking/Unlocking Using flock //
# //////////////////////////////////////////////////////////////////////////////

my $flockLockHandle = sub($)
# ------ arguments: $filehandle
{
  my $fh = shift;
  if (my $locked = flock $fh, &Fcntl::LOCK_EX | &Fcntl::LOCK_NB)
  {
    my $signature = HSM::HOSTNAME . ':' . $$;
    syswrite $fh, $signature, length($signature);
    return 1;
  }
  else
  {
    close $fh;
    return 0;
  }
};

my $flockTryLock = sub($)
# ------ arguments: $path
{
  my $p = shift;
  my $lockfile = $p . &HSM::EXTENSION_LOCK;
  if (-f $lockfile)
  {
    if (sysopen my $fh, $lockfile, &Fcntl::O_WRONLY)
    {
      return ($flockLockHandle->($fh)) ? {file => $lockfile, handle => $fh} : 0;
    }
    elsif (POSIX::errno() == &POSIX::ENOENT)
    {
      return 0;
    }
    else
    {
      return undef;
    }
  }
  else
  {
    if (sysopen my $fh, $lockfile, &Fcntl::O_WRONLY | &Fcntl::O_CREAT | &Fcntl::O_EXCL)
    {
      return ($flockLockHandle->($fh)) ? {file => $lockfile, handle => $fh} : 0;
    }
    elsif (POSIX::errno() == &POSIX::EEXIST)
    {
      return 0;
    }
    else
    {
      return undef;
    }
  }
};

my $flockUnlock = sub($)
# ------ arguments: $refToHash
{
  my $r = shift;
  flock $r->{handle}, &Fcntl::LOCK_UN;
  close $r->{handle};
  unlink $r->{file};
};

my $flockLockingInfo = sub()
# ------ arguments: none
{
  return "flock";
};

# //////////////////////////////////////////////////////////////////////////////
# ///////////////////////////////////// Locking/Unlocking Using File::NFSLock //
# //////////////////////////////////////////////////////////////////////////////

my $NFSLockTryLock = sub($)
# ------ arguments: $path
{
  my $p = shift;
  my $r = new File::NFSLock($p, &Fcntl::LOCK_EX | &Fcntl::LOCK_NB);
  return (defined($r)) ? $r : 0;
};

my $NFSLockUnlock = sub($)
# ------ arguments: $handle
{
  my $r = shift;
  $r->unlock();
};

my $NFSLockLockingInfo = sub()
# ------ arguments: none
{
  if (defined($File::NFSLock::VERSION))
  {
    return "File::NFSLock Version $File::NFSLock::VERSION";
  }
  else
  {
    return "File::NFSLock";
  }
};

# //////////////////////////////////////////////////////////////////////////////
# ////////////////////////////////////////////////////////////////// Globbing //
# //////////////////////////////////////////////////////////////////////////////

my $globEnhanced = sub($)
# ------ arguments: $pattern
{
  my $p = shift;
  my @parts = split(/\//, $p);
  my ($search, @results) = (undef, ());
  $search = sub($$)
  {
    my ($n, $i) = @_;
    if (-d $n)
    {
      if (opendir my $dh, $n)
      {
	my $curDir = Cwd::getcwd();
	if (chdir $n)
	{
	  foreach my $name (glob(@parts[$i]))
	  {
	    my $fullName = ($n ne '/') ? "$n/$name" : "/$name";
	    if ($i < $#parts)
	    {
	      $search->($fullName, $i + 1);
	    }
	    else
	    {
	      push @results, $fullName;
	    }
	  }
	  chdir $curDir;
	}
	closedir $dh;
      }
    }
  };
  $search->("/", 1);
  return @results;
};

my $globRegular = sub($)
# ------ arguments: $pattern
{
  return glob(shift);
};

# //////////////////////////////////////////////////////////////////////////////
# /////////////////////////////////////////////////////////// Other Utilities //
# //////////////////////////////////////////////////////////////////////////////

my $elements = sub($)
# ------ arguments: $dirPath
{
  my $d = shift;
  my @result = ();
  if (opendir my $dh, $d)
  {
    readdir $dh;
    readdir $dh;
    my @paths = readdir $dh;
    foreach my $path (@paths)
    {
      my $okfile = $path . &HSM::EXTENSION_OK;
      push @result, "$d/$path" if scalar(grep($_ eq $okfile, @paths)) > 0;
    }
    closedir $dh;
  }
  return @result;
};

my $directories = sub($)
# ------ arguments: $dirPath
{
  my $d = shift;
  my @result = ();
  if (opendir my $dh, $d)
  {
    readdir $dh;
    readdir $dh;
    my @paths = readdir $dh;
    foreach my $dir (grep(-d "$d/$_", @paths))
    {
      my $okfile = $dir . &HSM::EXTENSION_OK;
      push @result, "$d/$dir" if scalar(grep($_ eq $okfile, @paths)) == 0;
    }
    closedir $dh;
  }
  return @result;
};

my $permissions = sub($)
# ------ arguments: $path
{
  my $p = shift;
  my $perms = stat($p)->mode & 07777;
  return ($perms, $perms | 0700);
};

my $removeElement = sub($)
# ------ arguments: $path
{
  my $p = shift;
  if (-d $p)
  {
    my ($perms, $permsToRemove) = $permissions->($p);
    if ((-r $p && -w $p && -x $p) || ($perms != $permsToRemove && chmod $permsToRemove, $p))
    {
      if (opendir my $dh, $p)
      {
        my $ok = 1;
        readdir $dh;
        readdir $dh;
        my @files = readdir $dh;
	foreach my $file (@files)
	{
	  my $absPath = "$p/$file";
	  my ($filePerms, $filePermsToRemove) = $permissions->($absPath);
	  if ((-r $absPath && -w $absPath) || ($filePerms != $filePermsToRemove && chmod $filePermsToRemove, $absPath))
	  {
	    unlink $absPath;
	  }
	  else
	  {
	    $ok = 0;
	    last;
	  }
	}
	closedir $dh;
	rmdir $p if $ok;
	return $ok;
      }
      else
      {
        chmod $perms, $p;
	return 0;
      }
    }
    else
    {
      return 0;
    }
  }
  elsif (-f $p)
  {
    my ($perms, $permsToRemove) = $permissions->($p);
    if ((-r $p && -w $p) || ($perms != $permsToRemove && chmod $permsToRemove, $p))
    {
      unlink $p;
      return 1;
    }
    else
    {
      return 0;
    }
  }
  else
  {
    return 0;
  }
};

my $setAccessTime = sub($$)
# ------ arguments: $path $timeStamp
{
  my ($p, $t) = @_;
  utime($t, stat($p)->mtime, $p) if -e $p;
};

# //////////////////////////////////////////////////////////////////////////////
# ////////////////////////////////////// Exported Functions - General Purpose //
# //////////////////////////////////////////////////////////////////////////////

sub createDir($)
# ------ arguments: $dirPath
# ------ create a (multilevel) directory, passed as an argument 
# ------ return the created directory or an empty value
{
  my $d = shift;
  my ($dirAbs, @dirs) = (File::Spec->rel2abs($d), ());
  eval {@dirs = File::Path::mkpath($dirAbs)};
  if ($@)
  {
    return '';
  }
  elsif (scalar(@dirs) > 0)
  {
    return $dirs[$#dirs];    
  }
  else
  {
    return $dirAbs;
  }
}

sub pathIsMountable($)
# ------ arguments: $pathname
# ------ returns 1 if the $pathname is mountable
{
  my $p = shift;
  $p = qx(readlink --canonicalize-missing --no-newline $p);
  if ($p ne '/')
  {
    qx(ls $p >& /dev/null);
    chomp(my @mounts = qx(cut --delimiter=' ' --fields=2 /proc/mounts | grep '/.' | sort --unique));
    my ($maximal, @maximals) = (pop @mounts, ());
    while (defined $maximal)
    {
      my $current = undef;
      do {$current = pop @mounts} while defined $current and $maximal =~ m/^$current\//;
      push @maximals, $maximal;
      $maximal = $current;
    }
    foreach $maximal (@maximals)
    {
      return 1 if $p eq $maximal or $p =~ m/^$maximal\//;
    }
    return 0;
  }
  else
  {
    return 1;
  }
}

sub getCache($)
# ------ arguments: $pattern
# ------ return list of existing files, satisfying the $pattern
{
  return $HSMGlob->(shift);
}

# //////////////////////////////////////////////////////////////////////////////
# ////////////////////////////////////////////// Exported Functions - Locking //
# //////////////////////////////////////////////////////////////////////////////

sub tryLock($)
# ------ arguments: $path
# ------ try to lock the $path (without blocking)
# ------ return a handle if succeeded, '0' if the $path is already locked, 'undef' otherwise 
{
  my $p = shift;
  my $dir = File::Basename::dirname($p);
  if (-d $dir or HSM::createDir($dir))
  {
    if (-w $dir)
    {
      my $r = $HSMTryLock->($p);
      print STDERR "HSM::tryLock - a lockfile for the '$p' can't be opened or created\n" unless defined($r);
      return $r;
    }
    else
    {
      print STDERR "HSM::tryLock - the directory '$dir' isn't writable\n";
      return undef;
    }
  }
  else
  {
    print STDERR "HSM::tryLock - the directory '$dir' can't be created\n";
    return undef;
  }
}

sub lock($$)
# ------ arguments: $path $timeToWait
# ------ lock the $path (with blocking), trying every $timeToWait seconds until success
# ------ return a handle if succeeded, 'undef' otherwise 
{
  my ($p, $t) = @_;
  $t = HSM::TIME_TO_WAIT_DEFAULT unless $t;
  while (1)
  {
    my $r = HSM::tryLock($p);
    if (defined($r))
    {
      if ($r)
      {
        return $r;
      }
      else
      {
        print STDERR "HSM::lock - the '$p' is locked by another process, trying again in $t seconds ...\n" and sleep $t;
        $t = int($t * HSM::TIME_TO_WAIT_INCREASE_RATE);
      }
    }
    else
    {
      print STDERR "HSM::lock - the '$p' can't be locked\n";
      return undef;
    }    
  }
}

sub unlock($)
# ------ arguments: $handle
# ------ unlock the previously locked path by its $handle
{
  my $r = shift;
  if ($r)
  {
    $HSMUnlock->($r);
  }
  else
  {
    print STDERR "HSM::unlock - invalid reference (system error)\n";
  }
}

sub lockingInfo()
# ------ arguments: none
{
  return $HSMLockingInfo->();
}

# //////////////////////////////////////////////////////////////////////////////
# ///////////////////////////////////// Exported Functions - Cache Management //
# //////////////////////////////////////////////////////////////////////////////

sub clean($)
# ------ arguments: $path
# ------ remove the $path and corresponding ok-file in abnormal cases
{
  my $p = shift;
  my $dir = File::Basename::dirname($p);
  if (-w $dir)
  {
    if (-d $p && <$p/*> eq '')
    {
      if (-w $p)
      {
        rmdir $p;
      }
      else
      {
	print STDERR "HSM::clean - the directory '$p' isn't writable\n";
      }
    }
    elsif (-f $p && -z $p)
    {
      if (-w $p)
      {
        unlink $p;
      }
      else
      {
	print STDERR "HSM::clean - the file '$p' isn't writable\n";
      }
    }
    my $okfile = $p . &HSM::EXTENSION_OK;
    unlink $okfile unless -e $p;
  }
  else
  {
    print STDERR "HSM::clean - the directory '$dir' isn't writable\n";
  }
}

sub alignAccessTime($)
# ------ arguments: $path
{
  my $p = shift;
  my ($okfile, $t) = ($p . &HSM::EXTENSION_OK, time());
  $setAccessTime->($okfile, $t);
  $setAccessTime->($p, $t);
  if (opendir my $dh, $p)
  {
    readdir $dh;
    readdir $dh;
    my @paths = readdir $dh;
    foreach my $path (@paths)
    {
      my $absPath = "$p/$path";
      $setAccessTime->($absPath, $t) if -f $absPath;
    }
    closedir $dh;
  }
}

sub remove($$$$)
# ------ arguments: $directory $timeStamp $pause $verbose
# ------ remove all the cache elements in the $directory and below it with atime less than $timeStamp
# ------ sleep for the $pause after each element removal 
{
  my ($d, $t, $p, $v) = @_;
  if (-d $d)
  {
    my ($perms, $permsToRemove) = $permissions->($d);
    if ((-r $d && -w $d && -x $d) || ($perms != $permsToRemove && chmod $permsToRemove, $d))
    {
      my $ok = 1;
      print "HSM::remove - entering '$d'\n" if $v;
      # -------------------------------------------------------------------- remove HSM elements
      foreach my $element ($elements->($d))
      {
	my $okfile = $element . &HSM::EXTENSION_OK;
	my $atime = stat($okfile)->atime;
	if (defined($atime))
	{
	  my $atimeFormatted = POSIX::strftime("%x %X %Z", localtime($atime));
	  print "HSM::remove - testing  '$okfile': atime = '$atimeFormatted'\n" if $v;
	  if ($atime <= $t)
	  {
            if (my $r = HSM::tryLock($element))
	    {
	      print "HSM::remove - removing '$element'\n" if $v;
	      if ($removeElement->($element))
	      {
		print "HSM::remove - removing '$okfile'\n" if $v;
		unlink $okfile;
	        HSM::unlock($r);
                sleep $p;
	      }
	      else
	      {
		print "HSM::remove - keeping  '$element' (problem with permissions during the removal)\n" if $v;
	        HSM::unlock($r);
		$ok = 0;
		last;
	      }
	    }
	    else
	    {
	      print "HSM::remove - keeping  '$element' (it's locked by another process)\n" if $v;
	    }
	  }
	}
	else
	{
          print STDERR "HSM::remove - the file '$okfile' acess time can't be determined (system error)\n";
	  $ok = 0;
	  last;
	}
      }
      # -------------------------------------------------------------------- process other directories
      if ($ok)
      {
	foreach my $directory ($directories->($d))
	{
          if (!HSM::remove($directory, $t, $p, $v))
	  {
	    $ok = 0;
	    last;
	  }
	}
	if (rmdir $d)
	{
	  print "HSM::remove - removing '$d'\n" if $v;
	}
	else
	{
	  print "HSM::remove - exiting  '$d'\n" if $v;
	}
	return $ok;
      }
      else
      {
        print STDERR "HSM::remove - the directory '$d' has been processed incompletely\n";
        return 0;
      }
    }
    else
    {
      print STDERR "HSM::remove - the directory '$d' has wrong permissions\n";
      return 0;
    }
  }
  else
  {
    print STDERR "HSM::remove - the directory '$d' doesn't exist\n";
    return 0;
  }
}

# //////////////////////////////////////////////////////////////////////////////
# //////////////////////////////////////////////////////////// Initialization //
# //////////////////////////////////////////////////////////////////////////////

{
  my ($site, @sites) = (HSM::SITE_CURRENT, HSM::SITES_NFSLOCK);
  if ($site && scalar(grep($_ eq $site, @sites)) > 0)
  {
    ($HSMTryLock, $HSMUnlock, $HSMLockingInfo) = ($NFSLockTryLock, $NFSLockUnlock, $NFSLockLockingInfo);
  }
  else
  {
    ($HSMTryLock, $HSMUnlock, $HSMLockingInfo) = ($flockTryLock, $flockUnlock, $flockLockingInfo);
  }
}

{
  my ($site, @sites) = (HSM::SITE_CURRENT, HSM::SITES_GLOBENHANCED);
  if ($site && scalar(grep($_ eq $site, @sites)) > 0)
  {
    $HSMGlob = $globEnhanced;
  }
  else
  {
    $HSMGlob = $globRegular;
  }
}

return 1;
