#!/bin/csh -f
# 
# $Id: memory_limit.csh,v 1.1.2.4 2013/03/12 22:20:57 afy Exp $
# ------------------------------------------------------------------------------
# FMS/FRE Project: Script to Define Memory Limit Depending on Model Size 
# ------------------------------------------------------------------------------
# afy    Ver   1.00  Initial version                                February 12
# afy    Ver   2.00  Apply max limitation after the loop end        February 12
# afy    Ver   3.00  Don't apply max limitation                     March 13
# afy    Ver   4.00  Add scaling factor                             March 13
# ------------------------------------------------------------------------------
# Copyright (C) NOAA Geophysical Fluid Dynamics Laboratory, 2000-2013
# Designed and written by V. Balaji, Amy Langenhorst and Aleksey Yakovlev
# 

set -r echoOn = $?echo
set -r pushdsilent

if ( $# == 1 ) then
  if ( $1 =~ /* ) then
    set -r dir = $1
  else
    set -r dir = `pwd`/$1
  endif
else
  if ( $echoOn ) unset echo
  echo "Usage: $0:t dirPath"
  if ( $echoOn ) set echo
  exit 1
endif

set -r patternGrepTail = '\.[0-9]{4}$'
set -r factor = '1.25'

if ( -e $dir ) then
  if ( -d $dir ) then
    pushd $dir
    @ mem = 0
    set filesToCombine = ( `ls -1 | egrep ".*$patternGrepTail" | sed -r "s/$patternGrepTail//g" | sort -u` )
    if ( $#filesToCombine > 0 ) then
      foreach file ( $filesToCombine )
        @ size = `du --block-size=1M --total $file.* | tail -1 | cut --fields=1`
        if ( $mem < $size ) @ mem = $size
        unset size
      end
    endif
    unset filesToCombine
    popd
    printf %.0f `echo "$mem * $factor" | bc -l`
    exit 0
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
