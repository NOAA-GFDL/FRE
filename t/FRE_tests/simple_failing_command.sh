#!/bin/csh -f
#INFO:component=BAR

set name = FOO
set oname = UNGA
set platform = BUNGA
set target = HALLE
set segment_months = LU


/usr/bin/time -f "     TIME for move:      real %e user %U sys %S" mv FILE_DNE FILE_STILL_DNE
if ( $status ) then
	# retry logic will run.
	exit 0
else
	# retry logic will not run
	exit 1
endif
