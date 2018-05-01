#!/bin/csh -f
######################################################################
#  The finite-volume cubed-sphere model should have the dry mass
#  adjusted at the initial model time only. This script determines
#  if the model is at the initial time by comparing model start time
#  and current time in the coupler.res file.
######################################################################

set initial_start = ".true."
if (-e INPUT/coupler.res) then
   set t1 = (`grep "Model start time"   INPUT/coupler.res | awk '{print $1,$2,$3,$4,$5,$6}'`)
   set t2 = (`grep "Current model time" INPUT/coupler.res | awk '{print $1,$2,$3,$4,$5,$6}'`)
   foreach i (1 2 3 4 5 6)
      if ( $t1[$i] != $t2[$i] ) then
         set initial_start = ".false."
         break   
      endif      
   end
endif

echo $initial_start

