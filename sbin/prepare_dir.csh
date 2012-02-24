#!/bin/csh -f
# 
# $Id: prepare_dir.csh,v 18.0.2.1 2011/05/11 20:52:59 afy Exp $
# ------------------------------------------------------------------------------
# FMS/FRE Project: Script to Make a Clean Directory
# ------------------------------------------------------------------------------
# afy    Ver   1.00  Initial version                                April 10
# afy -------------- Branch 18.0.2 -------------------------------- May 11
# afy    Ver   1.00  Add an argument to control cleaning            May 11
# ------------------------------------------------------------------------------
# Copyright (C) NOAA Geophysical Fluid Dynamics Laboratory, 2000-2011
# Designed and written by V. Balaji, Amy Langenhorst and Aleksey Yakovlev
# 

if ( 1 <= $# && $# <= 2 ) then
  if ( $1 =~ /* ) then
    set -r dir = $1
  else
    set -r dir = `pwd`/$1
  endif
  if ( $2 != "" ) then
    set -r flag = 1
  else
    set -r flag = 0
  endif
else
  echo "Usage: $0:t dirPath [flagToClean]"
  exit 1
endif

if ( -e $dir ) then
  if ( -d $dir ) then
    if ( -w $dir ) then
      if ( $flag ) rm -rf $dir/* >& /dev/null
      exit 0
    else
      echo "ERROR: The directory '$dir' exists, but is not writable"
      exit 1
    endif
  else
    echo "ERROR: The directory '$dir' can't be created - remove the file '$dir' at first"
    exit 1
  endif
else
  mkdir --mode=755 --parents --verbose $dir
  if ( $status == 0 ) then
    exit 0
  else
    echo "ERROR: The directory '$dir' can't be created"
    exit 1
  endif
endif
