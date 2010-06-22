#!/bin/csh -f
# 
# $Id: prepare_dir.csh,v 1.1.2.1 2010/04/14 18:00:38 afy Exp $
# ------------------------------------------------------------------------------
# FMS/FRE Project: Script to Make a Clean Directory
# ------------------------------------------------------------------------------
# afy    Ver   1.00  Initial version                                April 10
# ------------------------------------------------------------------------------
# Copyright (C) NOAA Geophysical Fluid Dynamics Laboratory, 2000-2010
# Designed and written by V. Balaji, Amy Langenhorst and Aleksey Yakovlev
# 

if ( $1 == "" ) then
  echo "Usage: $0 argument"
  exit 1
else if ( $1 =~ /* ) then
  set -r dir = $1
else
  set -r dir = `pwd`/$1
endif

if ( -e $dir ) then
  if ( -d $dir ) then
    if ( -w $dir ) then
      rm -rf $dir/* >& /dev/null
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
  if ( $status != '0' ) then
    echo "ERROR: The directory '$dir' can't be created"
    exit 1
  else
    exit 0
  endif
endif
