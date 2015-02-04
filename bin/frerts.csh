#!/bin/csh -x

echo ================
date
hostname
echo $0 $argv
echo MY_PID= $$
echo ================

######USER options##################################
set MY_FRE = 0
####################################################

set argv = (`getopt -u -o hp:t:x:l: -l suit: -l no_rts -l compile -l build_only -l use_libs  -l fre_version: -l fre_ops: -l dry_run -l no_wait -l no_stage -l all -l do_frecheck -l reference_tag: --  $*`)
 
set FRE_VERSION = fre/test
set frerts_check = `which frerts_status.csh`
set REFTAG = siena
set EXPLIST = () 
set DO_all = 0
set DO_compile = 0
set BUILD_ONLY = 0
set SUIT =""
set LIB =""
set DO_basic = 1
set DO_rts = 1
set DO_libs = 0
set FRE_OPS   = ""
set FREMAKE_OPS = ""
set NODRYRUN = 1 # set to 0 for a dry run
set NOWAIT = 0
set NOSTAGE = 0
set old_nember = 0
set MAXWARN = 20
set MAXTRY = 50
set DOFRECHECK = 0 
set help = 0

while ("$argv[1]" != "--")
    switch ($argv[1])
        case -h:
            set help   = 1;  breaksw
        case -p:
            set PLAT   = $argv[2]; shift argv; breaksw
        case -t:
            set TARGET = $argv[2]; shift argv; breaksw
        case -x:
            set XML    = $argv[2]; shift argv; breaksw
        case -l:
            set LIB    = $argv[2]; shift argv; breaksw
        case --all:
            set DO_all = 1;     breaksw
        case --do_frecheck:
            set DOFRECHECK = 1;     breaksw
        case --no_rts:
            set DO_rts = 0;     breaksw
        case --compile:
            set DO_compile = 1; breaksw
        case --build_only:
            set DO_compile = 1; 
            set BUILD_ONLY = 1; breaksw
        case --use_libs:
            set DO_libs = 1;    breaksw
        case --dry_run:
            set NODRYRUN = 0;   breaksw
        case --no_wait:
            set NOWAIT = 1;   breaksw
        case --no_stage:
            set NOSTAGE = 1;   breaksw
        case --suit:
            set SUIT   = $argv[2]; shift argv; breaksw
        case --fre_version:
            set FRE_VERSION = $argv[2]; shift argv; breaksw
        case --fre_ops:
            set FRE_OPS = $argv[2]; shift argv; breaksw
        case --reference_tag:
            set REFTAG = $argv[2]; shift argv; breaksw
    endsw
    shift argv
end
shift argv

foreach EXP ( $argv )    
    set EXPLIST = ($EXPLIST $EXP)
end
if ( $help ) then
HELP:
cat << EOF
Name:      frerts.csh 

Synopsis:  Creates and runs frerts scripts for one set of given  xml, platform, target, experiments list

Usage:     frerts.csh  
           -x path_to_xml 
           -p platform
           -t target 
           --compile  optionally compile if passed
	      -l lib_experiment_name  the experiment that contains required libs
	   --build_only optionally do only the compilation and exit   
	   --all      optionally run all the experiments in the xml that do not contain "noRTS" in their name
           --no_rts   optionally run only the "basic" regression and do not run the "rts" regression
	   --no_stage optionally do not stage the data and use "frerun -s" (assumes the data is pre-staged to ptmp)
	   --fre_version FRE_VERSION  specify the FRE version
	   --fre_ops "semicolon separated list of options passed to frerun"  optionally passes a list of options to frerun 
	   --dry_run  do not submit any jobs, just print the frerun commands
 
           space_separated_list_of_experiments	  

Examples:



EOF


exit 1
endif

#Load the required modules and set the necessary envs
source $MODULESHOME/init/tcsh
module use -a /ncrc/home2/fms/local/modulefiles
module rm fre
module load $FRE_VERSION
set myfreBin = /ncrc/home2/Niki.Zadeh/myfre/fre-commands/bin/


set fremake = "fremake"
set frerun  = "frerun"
set frelist = "frelist"
set frecheck = "frecheck"

echo which fre
which fremake
which frerun
which frelist
which frecheck


set FRE_OPS = `echo $FRE_OPS | awk  '{gsub(/,/," ");print}'`   
set FRE_OPS = `echo $FRE_OPS | awk  '{gsub(/=/," ");print}'`   
set FRE_OPS = `echo $FRE_OPS | awk  '{gsub(/;/," ");print}'`   


set logit = "/sbin/logsave -a ~/frertslogs.txt "

set PLATAR = $PLAT-$TARGET

if(! $#EXPLIST ) then
    if( $DO_all ) then
	set EXPLIST = `$frelist -x $XML  -p $PLAT -t $TARGET --no-inherit | egrep -i -v "_base|_compile|_norts|_static"`
    else
	echo No experiments are specified , neither is --all option passed.
	exit
    endif	
endif

echo experiments to run: $EXPLIST


set ARCHIVE_ROOT = `$frelist -d archive -x $XML -p $PLAT -t $TARGET  $EXPLIST[1]`
set ARCHIVE_ROOT = $ARCHIVE_ROOT/../../
echo ARCHIVE_ROOT : $ARCHIVE_ROOT


set frecheckoutput = $ARCHIVE_ROOT/frecheck.out
set FRELOG  = $ARCHIVE_ROOT/frelog.txt

set TODOLIST = ( $EXPLIST )
set TODOLIST_basic = ( $EXPLIST )
set TODOLIST_rts = ( $EXPLIST )

set EXPDONE = ()

set b_regression = "basic"
set r_regression = "rts"
set required_restarts = 3

if( ! $DO_rts ) set required_restarts = 1

if( "$TARGET" =~ *"debug"* ) then
   set b_regression = "trapnan"
   set r_regression = "trapnan"
   set required_restarts = 1
endif

set CRASH = 0

#Build the libraries if requested  ( future: find out which library is required and build it)

if( $LIB != "" ) then
  echo "Compiling the libraries ..."
#  if( $DO_libs ) set FREMAKE_OPS = "--libs"
  set freCMD = "$fremake --execute --nolink -x $XML -p $PLAT -t $TARGET $LIB $FREMAKE_OPS"
  echo $freCMD
  echo
  sleep 5
  if( $NODRYRUN ) then
    $freCMD 
    #error check only valid with --nolink passed to fremake
    if( $status != 0 ) then
    echo "fremake failed!"
    exit
    endif
  endif
endif

#For each experiment build the executable

foreach EXP ( $TODOLIST )
   set EXE  =  `$frelist --executable    -x $XML  -p $PLAT -t $TARGET $EXP`
   set EXEC = $EXE[1]
   set SUIT = $EXE[2]

   if( $DO_compile && ! -e $EXEC) then
      echo "The executable $EXEC does not exist, building it, please wait ..."
      set freCMD = "$fremake --execute -x $XML -p $PLAT -t $TARGET $SUIT"
      echo $freCMD
      echo
      sleep 5
      if( $NODRYRUN ) then
	   $freCMD 
	   if( $status != 0 ) then
	      echo "fremake failed!"
	      exit
           endif
      endif
      sleep 5
  endif
#Stage the executable
  echo "Pre-stage the executable $EXEC"
  set exec_dir = `dirname $EXEC`
  mkdir -p $CSCRATCH/$USER/ptmp/$exec_dir
  chmod +w $CSCRATCH/$USER/ptmp/$exec_dir/*
  cp $EXEC $CSCRATCH/$USER/ptmp/$exec_dir/

end

if( $BUILD_ONLY ) then
    echo All built.
    exit
endif

 
set k=0
while( $#TODOLIST );

@ k = $k + 1

	set somebasicswaiting = 0
        if( $DO_basic ) then
	   set TODOLIST_basic_new = 
           foreach EXP ( $TODOLIST_basic ) 
	    set EXE  =  `$frelist --executable    -x $XML  -p $PLAT -t $TARGET $EXP`
	    set EXEC = $EXE[1]
	    set SUIT = $EXE[2]
	    if(! -e $EXEC)  then
	        if( $k <  $MAXWARN ) echo "DO_basic : $EXP is waiting for the executable $EXEC ..."
		set TODOLIST_basic_new = ( $TODOLIST_basic_new $EXP )
          	set somebasicswaiting = 1
	    else
                echo "DO_basic : $EXP executable $EXEC is ready"

		#Stage the executable
		echo "Pre-stage the executable $EXEC"
		set exec_dir = `dirname $EXEC`
		mkdir -p $CSCRATCH/$USER/ptmp/$exec_dir
		chmod +w $CSCRATCH/$USER/ptmp/$exec_dir/*
		cp $EXEC $CSCRATCH/$USER/ptmp/$exec_dir/


		set stageswitch = "-S" # "--submit-staged" or "-S"
                if( $NOSTAGE ) set stageswitch = "-s"
		set regressswitch = "-r $b_regression"
		if( "$FRE_OPS" =~ *"-r"* ) set regressswitch = ""
                set freCMD = "$frerun $stageswitch $regressswitch $FRE_OPS --no-transfer --nocombine-history -x $XML -p $PLAT -t $TARGET $EXP"

		echo $freCMD
		echo
		sleep 2
                set STDOUT = `$frelist --directory stdout -x $XML -p $PLAT -t $TARGET $EXP`/run
		if( $NODRYRUN ) then
		     set cmdout = `$logit $freCMD`
		     echo "$cmdout" 
#We don't want to wait here till we get a job number. How else can we find the job number?
#		     set jobID = `echo "$cmdout" | egrep -o "gaea.[0-9]*|moab02ncrc.[0-9]*" `
#		     echo "jobID: $jobID"
#		     sleep 10 #for moab to sync
#		     set runID = `checkjob -v $jobID | grep -o '(RM job.*[0-9]*' | grep -o '[0-9]*' | head -1`
#		     echo "runID: $runID"
#		     set STDOUT = "$STDOUT/$EXP*.o$runID"
		endif     
		echo "stdout: $STDOUT"
		     
		if( ! $DO_rts ) set EXPDONE = ( $EXPDONE $EXP )
		
	    endif
	   end
           if( ! $somebasicswaiting ) set DO_basic = 0
       
           echo "DO_basic : Wait 20 minutes before checking the results of $b_regression regression for ( $TODOLIST_basic ) ..."
	   if( $NODRYRUN ) sleep 1200
	   
	   set TODOLIST_basic = ( $TODOLIST_basic_new )
        endif

	set someoneswaiting = 0

	if( $DO_rts) then
             foreach EXP ( $TODOLIST ) 
		set alreadydone = 0
		foreach DONE ( $EXPDONE ) 
		   if( $DONE == $EXP) then
			set alreadydone = 1
		   endif
		end
		if( $alreadydone ) continue 
		#Ensure the basic regression was successful before submitting the rts
	        set freCMD = "$frecheck -l -x $XML -p $PLAT -t $TARGET  $EXP"
		if( $k <  $MAXWARN) echo $freCMD
#		$freCMD
#                set MYFRECHECKSTATUS =  $status

		set FRECHECKOUTPUT = `$freCMD`
		echo $FRECHECKOUTPUT | egrep "crash"
		if( ! $status ) then
		    set MYFRECHECKSTATUS = 255
		else		    
		    set MYFRECHECKSTATUS =  `$frecheck -l -x $XML -p $PLAT -t $TARGET  $EXP | wc -l`
		endif    

		if(  $MYFRECHECKSTATUS == 255 ) then
   		    echo "$EXP : _crash directory found!"
#		   add $EXP to crashed list and extract it from $TODOLIST
		    set EXPDONE = ( $EXPDONE $EXP )		
		else
		    if( $MYFRECHECKSTATUS == 0 ) then
		    if( $k < $MAXWARN ) echo "DO_rts : $EXP is waiting for the $b_regression regression to end ..."
		    set someoneswaiting = 1		
		    else
		    set freCMD = "$frerun -s $FRE_OPS  --no-transfer --nocombine-history -r $r_regression  -x $XML -p $PLAT -t $TARGET $EXP"
		    echo $freCMD
		    echo
		    sleep 2
		    if( $NODRYRUN ) $logit $freCMD
		    set EXPDONE = ( $EXPDONE $EXP )
		    endif
		endif
	     end		    
             if( ! $someoneswaiting ) set DO_rts = 0
	   echo "DO_rts : Wait 20 minutes before checking the results of $r_regression regression for ( $TODOLIST )..."
	   if( $NODRYRUN ) sleep 1200
        endif


set EXPDONE_1 = ( $EXPDONE ) 
set EXPDONE = ()
set crashed_exp = 
set CRASH = 0

foreach DONE ( $EXPDONE_1 ) 
   set freCMD = "$frecheck -l -x $XML -p $PLAT -t $TARGET  $DONE"
   if( $k <  $MAXWARN) echo $freCMD
   $freCMD
#   set MYFRECHECKSTATUS =  $status

    set FRECHECKOUTPUT = `$freCMD`
    echo $FRECHECKOUTPUT | egrep "crash"
    if( ! $status ) then
	set MYFRECHECKSTATUS = 255
    else		    
	set MYFRECHECKSTATUS =  `$frecheck -l -x $XML -p $PLAT -t $TARGET  $DONE | wc -l`
    endif    
 
    if( $MYFRECHECKSTATUS == 255 ) then
       echo "$DONE : Crashed!"
       set CRASH = 1
       set crashed_exp = ( $crashed_exp $DONE )

	set TODOLIST_1 = ( $TODOLIST )
	set TODOLIST = ()
 	foreach EXP ( $TODOLIST_1 )
	    if( $DONE != $EXP) then
		set TODOLIST = ( $TODOLIST $EXP )	
	    endif
	end
    else		
      if( $MYFRECHECKSTATUS >= $required_restarts ) then
	echo "Finished the runs for $DONE" 

	if( $DOFRECHECK ) then
	    `$frerts_check -r --reference_tag $REFTAG -x $XML -p $PLAT -t $TARGET $DONE`
	endif

	set TODOLIST_1 = ( $TODOLIST )
	set TODOLIST = ()
 	foreach EXP ( $TODOLIST_1 )
	    if( $DONE != $EXP) then
		set TODOLIST = ( $TODOLIST $EXP )	
	    endif
	end

      else
	if( $k < $MAXWARN) echo "$DONE : Waiting for the $r_regression regression to end ..."
	set EXPDONE = ( $EXPDONE $DONE )
      endif
    endif
end


if( $#TODOLIST == 0 ) then
    echo "All Done." 
    if( $DOFRECHECK ) echo "Please view $frecheckoutput"
    exit
endif

if( $CRASH ) echo "Crash detected for $crashed_exp"


set old_nember = $#TODOLIST

if( $k > $MAXTRY ) then
  echo Giving up! 
  exit
endif

#	if( ! $NODRYRUN )  exit
if( $NOWAIT ) exit 

if( $k <  $MAXWARN || $#TODOLIST != $old_nember ) echo "Sleeping 20 minutes for  $#TODOLIST experiments ( $TODOLIST ) to be done ..."
sleep 1200

end



exit

#EXAMPLES
#
#BUILD
#
#/ncrc/home2/Niki.Zadeh/bin/go_rts.csh --build_only --use_libs -x /ncrc/home2/Niki.Zadeh/xmls/siena_prerelease/xml/libraries.xml -p ncrc.intel -t prod,openmp -l FMS_libs_compile mom4p1_solo_compile_libs MOM_SIS_compile_libs GOLD_SIS_compile_libs MOM_SIS_LAD_FV_compile_libs GOLD_SIS_LAD_FV_compile_libs MOM_SIS_LAD2_FV_compile_libs GOLD_SIS_LAD2_FV_compile_libs MOM_SIS_LAD2_CS_compile_libs MOM_SIS_LAD_BGR_compile_libs
#
#

