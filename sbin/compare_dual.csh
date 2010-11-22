#!/bin/csh -f
# 
# $Id: compare_dual.csh,v 1.1.2.1 2010/11/10 22:07:58 afy Exp $
# ------------------------------------------------------------------------------
# FMS/FRE Project: Script to Compare the Dual Output with the Main Output
# ------------------------------------------------------------------------------
# afy    Ver   1.00  Initial version                                November 10
# ------------------------------------------------------------------------------
# Copyright (C) NOAA Geophysical Fluid Dynamics Laboratory, 2000-2010
# Designed and written by V. Balaji, Amy Langenhorst and Aleksey Yakovlev
# 

if ( $1 != "" &&  $2 != "" && $3 =~ /* ) then
  set -r expName = $1
  set -r jobId = $2 
  set -r archive = $3
else
  echo "Usage: $0 <expName> <jobId> <absolute filename>"
  exit 1
endif

set -r archiveMainProduction = `echo $archive | sed -r 's/\/[0-9]+(\/(history|restart)\/.+\.(cpio|tar))$/\1/'`
set -r archiveMainRegression = `echo $archive | sed -r 's/pe[0-9]+(\/(history|restart)\/.+\.(cpio|tar))$/pe\1/'`

if ( $archiveMainProduction != $archive ) then
  set -r archiveMain = $archiveMainProduction
else if ( $archiveMainRegression != $archive ) then
  set -r archiveMain = $archiveMainRegression
else
  echo "The archive '$archive' isn't a dual one"
  exit 1
endif

if ( -f $archive && -r $archive ) then

  @ retry = 0
  while ( 1 )
    if ( -f $archiveMain && -r $archiveMain ) then
      set -r archiveMainFound
      break
    else if ( $retry < 10 ) then
      sleep 30
      @ retry++
    else
      break
    endif
  end
  unset retry

  if ( $?archiveMainFound ) then
    ls -1 $archiveMain $archive | ardiff
    if ( $status ) then
      echo "WARNING: Archives '$archiveMain' and '$archive' don't match!"
      set msg = "Archives '$archiveMain' and '$archive' don't match!\n"
      echo $msg | Mail -s "Experiment '$expName', job '$jobId' - archives don't match!" $USER
      unset msg
    else
      echo "NOTE: Archives '$archiveMain' and '$archive' match..."
    endif
  else
    echo "WARNING: The archive '$archiveMain' doesn't exist or isn't readable"
  endif

else
  echo "WARNING: The archive '$archive' doesn't exist or isn't readable"
endif
