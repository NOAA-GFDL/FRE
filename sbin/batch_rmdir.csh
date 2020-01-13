#!/bin/csh -f
#
# $Id: batch_rmdir.csh,v 1.1.2.1 2012/03/26 15:36:06 afy Exp $
# ------------------------------------------------------------------------------
# FMS/FRE Project: Batch Directory Remover
# ------------------------------------------------------------------------------
# afy    Ver   1.00  Initial version                                March 12
# ------------------------------------------------------------------------------
# Copyright (C) NOAA Geophysical Fluid Dynamics Laboratory, 2000-2012
# Designed and written by V. Balaji, Amy Langenhorst and Aleksey Yakovlev
#

  set -r echoOn = $?echo

  if ( $echoOn ) unset echo
  echo "<NOTE> : ====== FRE BATCH DIRECTORY REMOVER ======"
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
    if ( $?dir ) then
      if ( $dir != "" ) then
        set -r dir = $dir
      else
	if ( $echoOn ) unset echo
	echo "*ERROR*: The argument 'dir' value is empty"
	if ( $echoOn ) set echo
	exit 1
      endif
    else
      if ( $echoOn ) unset echo
      echo "*ERROR*: The argument 'dir' is not defined"
      if ( $echoOn ) set echo
      exit 1
    endif
  else if ( $# == 1 ) then
    if ( $1 =~ /* ) then
      set -r dir = $1
    else if ( $1 != "" ) then
      set -r dir = `pwd`/$1
    else
      if ( $echoOn ) unset echo
      echo "*ERROR*: The argument value is empty"
      if ( $echoOn ) set echo
      exit 1
    endif
  else
    if ( $echoOn ) unset echo
    echo "Usage: $0:t dirPath"
    if ( $echoOn ) set echo
    exit 1
  endif

################################################################################
#----------------------------- directory removing ------------------------------
################################################################################

  if ( -e $dir ) then
    if ( -d $dir ) then
      rm --force --recursive $dir
      if ( $status == 0 ) then
        if ( $echoOn ) unset echo
	echo "<NOTE> : The directory '$dir' has been removed successfully"
        if ( $echoOn ) set echo
      else
        if ( $echoOn ) unset echo
	echo "*ERROR*: The directory '$dir' can't be removed"
        if ( $echoOn ) set echo
	exit 1
      endif
    else
      if ( $echoOn ) unset echo
      echo "*ERROR*: The pathname '$dir' isn't a directory"
      if ( $echoOn ) set echo
      exit 1
    endif
  else
    if ( $echoOn ) unset echo
    echo "*ERROR*: The pathname '$dir' doesn't exist"
    if ( $echoOn ) set echo
    exit 1
  endif

################################################################################
#----------------------------- normal end of script ----------------------------
################################################################################

  if ( $echoOn ) unset echo
  echo "<NOTE> : Finishing on `date`"
  echo "<NOTE> : Natural end of batch directory remover"
  if ( $echoOn ) set echo

  exit 0
