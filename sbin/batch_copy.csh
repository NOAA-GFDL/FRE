#!/bin/csh -f
#
# $Id: batch_copy.csh,v 1.1.2.1 2012/03/26 15:36:06 afy Exp $
# ------------------------------------------------------------------------------
# FMS/FRE Project: Batch File Copier
# ------------------------------------------------------------------------------
# afy    Ver   1.00  Initial version                                March 12
# ------------------------------------------------------------------------------
# Copyright (C) NOAA Geophysical Fluid Dynamics Laboratory, 2000-2012
# Designed and written by V. Balaji, Amy Langenhorst and Aleksey Yakovlev
#

  set -r echoOn = $?echo

  if ( $echoOn ) unset echo
  echo '<NOTE> : ====== FRE BATCH FILE COPIER ======'
  echo "<NOTE> : Starting at $HOST on `date`"
  if ( $echoOn ) set echo

  unalias *

  # ---------------- define constants depending on the run type

  if ( $?SLURM_JOB_ID ) then
    tty -s >& /dev/null
    if ( $status ) then
      set -r batch
    endif
  endif

################################################################################
#------------------------ arguments initial assignment -------------------------
################################################################################

  if ( $?batch && $# == 0 ) then

    if ( $?src ) then
      if ( $src != "" ) then
        set -r src = $src
      else
	if ( $echoOn ) unset echo
	echo "*ERROR*: The argument 'src' value is empty"
	if ( $echoOn ) set echo
	exit 1
      endif
    else
      if ( $echoOn ) unset echo
      echo "*ERROR*: The argument 'src' is not defined"
      if ( $echoOn ) set echo
      exit 1
    endif

    if ( $?dstDir ) then
      if ( $dstDir != "" ) then
        set -r dstDir = $dstDir
      else
	if ( $echoOn ) unset echo
	echo "*ERROR*: The argument 'dstDir' value is empty"
	if ( $echoOn ) set echo
	exit 1
      endif
    else
      if ( $echoOn ) unset echo
      echo "*ERROR*: The argument 'dstDir' is not defined"
      if ( $echoOn ) set echo
      exit 1
    endif

  else if ( $# == 2 ) then

    if ( $1 =~ /* ) then
      set -r src = $1
    else if ( $1 != "" ) then
      set -r src = `pwd`/$1
    else
      if ( $echoOn ) unset echo
      echo "*ERROR*: The first argument value is empty"
      if ( $echoOn ) set echo
      exit 1
    endif

    if ( $2 =~ /* ) then
      set -r dstDir = $2
    else if ( $2 != "" ) then
      set -r dstDir = `pwd`/$2
    else
      if ( $echoOn ) unset echo
      echo "*ERROR*: The second argument value is empty"
      if ( $echoOn ) set echo
      exit 1
    endif

  else

    if ( $echoOn ) unset echo
    echo "Usage: $0:t sourceFile destinationDirectory"
    if ( $echoOn ) set echo
    exit 1

  endif

################################################################################
#----------------------------------- copying -----------------------------------
################################################################################

  if ( -e $src ) then
    if ( -f $src ) then
      if ( -r $src ) then
        if ( -e $dstDir ) then
          if ( -d $dstDir ) then
            if ( -r $dstDir ) then
              cp --force --preserve=mode,ownership,timestamps $src $dstDir
              if ( $status == 0 ) then
		if ( $echoOn ) unset echo
		echo "<NOTE> : The file '$src' has been successfully copied to the '$dstDir'"
		if ( $echoOn ) set echo
              else
		if ( $echoOn ) unset echo
		echo "*ERROR*: The file '$src' can't be copied to the '$dstDir'"
		if ( $echoOn ) set echo
                exit 1
              endif
            else
	      if ( $echoOn ) unset echo
	      echo "*ERROR*: The directory '$dstDir' isn't writeable"
	      if ( $echoOn ) set echo
	      exit 1
            endif
          else
	    if ( $echoOn ) unset echo
	    echo "*ERROR*: The pathname '$dstDir' exists, but it isn't a directory"
	    if ( $echoOn ) set echo
	    exit 1
          endif
        else
          mkdir -p $dstDir
          if ( $status == 0 ) then
            cp --force --preserve=mode,ownership,timestamps $src $dstDir
            if ( $status == 0 ) then
	      if ( $echoOn ) unset echo
	      echo "<NOTE> : Successful copying '$src' => '$dstDir'"
	      if ( $echoOn ) set echo
            else
	      if ( $echoOn ) unset echo
	      echo "*ERROR*: Unable to copy '$src' => '$dstDir'"
	      if ( $echoOn ) set echo
              exit 1
            endif
          else
	    if ( $echoOn ) unset echo
	    echo "*ERROR*: Unable to create the '$dstDir' directory"
	    if ( $echoOn ) set echo
	    exit 1
          endif
        endif
      else
	if ( $echoOn ) unset echo
	echo "*ERROR*: The file '$src' isn't readable"
	if ( $echoOn ) set echo
	exit 1
      endif
    else
      if ( $echoOn ) unset echo
      echo "*ERROR*: The pathname '$src' exists, but it isn't a file"
      if ( $echoOn ) set echo
      exit 1
    endif
  else
    if ( $echoOn ) unset echo
    echo "*ERROR*: The pathname '$src' doesn't exist"
    if ( $echoOn ) set echo
    exit 1
  endif

################################################################################
#----------------------------- normal end of script ----------------------------
################################################################################

  if ( $echoOn ) unset echo
  echo "<NOTE> : Finishing on `date`"
  echo "<NOTE> : Natural end of batch file copier"
  if ( $echoOn ) set echo

  exit 0
