#!/bin/csh -f
# 
# $Id: memory_limit.csh,v 1.1.2.2 2012/02/08 15:40:26 afy Exp $
# ------------------------------------------------------------------------------
# FMS/FRE Project: Script to Define Memory Limit Depending on Model Size 
# ------------------------------------------------------------------------------
# afy    Ver   1.00  Initial version                                February 12
# afy    Ver   2.00  Apply max limitation after the loop end        February 12
# ------------------------------------------------------------------------------
# Copyright (C) NOAA Geophysical Fluid Dynamics Laboratory, 2000-2012
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

@ memMin = 1
@ memMax = 8 * 1024

set -r patternGrepTail = '\.[0-9]{4}$'

if ( -e $dir ) then
  if ( -d $dir ) then
    pushd $dir
    @ mem = $memMin
    set filesToCombine = ( `ls -1 | egrep ".*$patternGrepTail" | sed -r "s/$patternGrepTail//g" | sort -u` )
    if ( $#filesToCombine > 0 ) then
      foreach file ( $filesToCombine )
        @ size = `du --block-size=1M --total $file.* | tail -1 | cut --fields=1`
        if ( $mem < $size ) @ mem = $size
        unset size
      end
    endif
    unset filesToCombine
    if ( $mem > $memMax ) @ mem = $memMax 
    popd
    echo $mem
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
