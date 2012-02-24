#!/bin/csh -f
#
set CMD_IN = "$0 $argv"

set RTSTOOL = `which frerts.csh`

set AUTORTSDIR = $HOME/autorts
set CMDLOGS = $AUTORTSDIR/go_rts_batch.logs 


set target_list = "prod,openmp"
set platform_list = "ncrc.intel"
set xml_list = ()
set xinclude_list = ()
set xml_dir = ""
set xml_list = "mom4p1_cpld.xml"
set help = 0
set EXPLIST = ()
set myrelease = ""
set myfrestem = ""
set myfreversion = ""
set mydebuglevel = ""
set mom_rts_tag = ""
set mom_cvs_tag = ""
set GO_OPS = ""
set AUTOLOG = 1 

set argv = (`getopt -u -o hrd:x:p:t: -l frerts_ops: -l release:  -l fre_stem: -l fre_version: -l debuglevel: -l mom_rts_tag: -l mom_cvs_tag: -l xinclude --  $*`)


while ("$argv[1]" != "--")
    switch ($argv[1])
        case -h:
            set help   = 1;  breaksw
        case -r:
            set refresh   = 1;  breaksw
        case -d:
            set xml_dir   = $argv[2]; shift argv; breaksw
	case -x:
	    set xml_list =  $argv[2]; shift argv
	    set xml_list =  `echo $xml_list | awk  '{gsub(/,/," ");print}'`
            breaksw
	case -p:
	    set platform_list = $argv[2]; shift argv
	    set platform_list = `echo $platform_list | awk  '{gsub(/,/," ");print}'`
            breaksw
	case -t:
	    set target_list = $argv[2]; shift argv
	    set target_list = `echo $target_list | awk  '{gsub(/,/," ");print}'`
            breaksw
        case --release:
            set myrelease = $argv[2]; shift argv; breaksw
        case --fre_stem:
            set myfrestem = $argv[2]; shift argv; breaksw
        case --fre_version:
            set myfreversion = $argv[2]; shift argv; breaksw
        case --debuglevel:
            set mydebuglevel = $argv[2]; shift argv; breaksw
        case --mom_rts_tag:
            set mom_rts_tag = $argv[2]; shift argv; breaksw
        case --mom_cvs_tag:
            set mom_cvs_tag = $argv[2]; shift argv; breaksw
        case --frerts_ops:
            set GO_OPS = $argv[2]; shift argv; breaksw
	case --xinclude:
	    set xinclude_list =  $argv[2]; shift argv
	    set xinclude_list =  `echo $xinclude_list | awk  '{gsub(/,/," ");print}'`
            breaksw
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
Name:      frerts_batch.csh 

Synopsis:  Creates and runs frerts scripts for a list of xmls, platforms, targets, experiments

Usage:     frerts_batch.csh  
	   -d the path to directory that contains the xmls. Defaults to "." if not given
           -x "comma_separated_list_of_xmls" 
           -p "comma_separated_list_of_platforms"
           -t "comma_separated_list_of_targets" 
           --frerts_ops "comma_separated_list_of_options_for_frerts_engine" 
           space_separated_list_of_experiments	  

Examples:

/ncrc/home2/Niki.Zadeh/bin/frerts_batch_11.csh -d /ncrc/home2/Niki.Zadeh/xmls/siena_prerelease/xml/ -x "fv_am2.xml" -p "ncrc.default,ncrc.pgi" -t "prod-openmp,repro-openmp" --frerts_ops "--compile" m45_am2p14_1990 m45_am2p14

The above will compile 4 variations "ncrc.default,ncrc.pgi" X "prod-openmp,repro-openmp" then submit two experiments m45_am2p14_1990 m45_am2p14


/ncrc/home2/Niki.Zadeh/bin/frerts_batch_11.csh -d /ncrc/home2/Niki.Zadeh/xmls/siena_prerelease/xml/ -x "fv_am2.xml" -p "ncrc.default,ncrc.pgi" -t "prod-openmp,repro-openmp" --frerts_ops "--compile,--all"

The above will compile 4 variations "ncrc.default,ncrc.pgi" X "prod-openmp,repro-openmp" then submits ALL experiments  in the xml except experiments with names that contain keys "_noRTS" and "_compile" (this way you can avoid running unwanted exps in your xml by appending _noRTS to their name). 

/ncrc/home2/Niki.Zadeh/bin/frerts_batch_11.csh -x /ncrc/home2/Niki.Zadeh/xmls/siena_prerelease/xml_presiena_nnz/libraries.xml -p "ncrc.intel_t1,ncrc.pgi_t1" -t "prod-openmp" --frerts_ops "--use_libs,--build_only,-l,FMS_libs_compile" --release testing --fre_stem testing_20111115 --fre_version 'fre\\\/test' MOM_SIS_LAD_FV_compile_libs GOLD_SIS_LAD_FV_compile_libs MOM_SIS_LAD2_FV_compile_libs GOLD_SIS_LAD2_FV_compile_libs MOM_SIS_LAD2_CS_compile_libs

The above will make all the FMS components libraries and compiles executables for 5 models using those libs. This happens for both intel and pgi in production mode, so 10 executables.

/ncrc/home2/Niki.Zadeh/bin/frerts_batch_11.csh -x /ncrc/home2/Niki.Zadeh/xmls/siena_prerelease/xml_presiena_nnz/ESM2_Control.xml -p "ncrc.intel_t1,ncrc.pgi_t1" -t "prod-openmp" --frerts_ops "--all,--use_libs,--fre_ops,-o;-P=t1" --release testing --fre_stem testing_20111115 --fre_version 'fre\\\/test'

The above will run all RTS experiments in the xml using the executables made by the previous command. The jobs will be submitted to t1 partition.
 
/ncrc/home2/Niki.Zadeh/bin/frerts_batch_12.csh -x /ncrc/home2/Niki.Zadeh/xmls/siena_prerelease/siena_prebronx/xml/mom4p1_cpld.xml -p ncrc.intel -t prod-openmp --frerts_ops "--all,--compile,--no_stage" --release siena --mom_cvs_tag mom4p1_siena_07jan2012_smg --fre_stem siena_mom4p1_siena_07jan2012_smg --debuglevel _do_bitwise_exact_sum --fre_version 'fre\\\/test'


/ncrc/home2/Niki.Zadeh/bin/frerts_batch_12.csh -x /ncrc/home2/Niki.Zadeh/xmls/siena_prerelease/siena_prebronx/xml/ESM2_Control.xml -p ncrc.intel -t prod-openmp --frerts_ops "--compile,-l,ESM_libs_compile,--no_stage" --release siena --mom_cvs_tag mom4p1_siena_07jan2012_smg --fre_stem siena_mom4p1_siena_07jan2012_smg --debuglevel _do_bitwise_exact_sum --fre_version 'fre\\\/test' ESM2M_Control-1860_dec29IC ESM2M_Control-1860_dec29IC_production

/ncrc/home2/Niki.Zadeh/bin/frerts_batch_12.csh -x /ncrc/home2/Niki.Zadeh/xmls/siena_prerelease/siena_prebronx/xml/mom4p1_solo.xml -p ncrc.intel -t "prod-openmp,repro-openmp" --frerts_ops "--compile,--no_stage,--all" --release siena --mom_cvs_tag mom4p1_siena_27jan2012_smg --fre_stem siena_mom4p1_siena_27jan2012_smg --debuglevel _1 --fre_version 'fre\\\/test'


/ncrc/home2/Niki.Zadeh/bin/frerts_batch_12.csh -x /ncrc/home2/Niki.Zadeh/xmls/siena_prerelease/siena_prebronx/xml/mom4p1_cpld.xml -p ncrc.intel -t "prod-openmp,repro-openmp" --frerts_ops "--compile,--no_stage,--all" --release siena --mom_cvs_tag mom4p1_siena_27jan2012_smg --fre_stem siena_mom4p1_siena_27jan2012_smg --debuglevel _1 --fre_version 'fre\\\/test'

/ncrc/home2/Niki.Zadeh/bin/frerts_batch_12.csh -x /ncrc/home2/Niki.Zadeh/xmls/siena_prerelease/siena_prebronx/xml/libraries.xml -p "ncrc.intel" -t "prod-openmp" --frerts_ops "--build_only,-l,FMS_libs_compile" --release siena --fre_stem siena_libs --fre_version 'fre\\\/test' MOM_SIS_LAD_FV_compile_libs 


EOF


exit 1
endif

set GO_OPS = `echo $GO_OPS | awk  '{gsub(/,/," ");print}'`   


if(! $#xml_list ) then
    set xml_dir = "/ncrc/home2/Niki.Zadeh/xmls/siena_prerelease/xml/"
    set xml_list = "mom4p1_cpld.xml CM2M_Control-1900.xml ESM2_Control.xml ICCMp1.xml GOLD_SIS.xml"
endif

set DATE =  `date +%Y%m%d%H%M%S`

set mypartition = "c1"
foreach plat ( $platform_list)
    if( "$plat" =~ *"_t1"* ) then
	set mypartition = "t1"
	break
    endif
    if( "$plat" =~ *"_c2"* ) then
	set mypartition = "c2"
	break
    endif
    if( "$plat" =~ *"ncrc2"* ) then
	set mypartition = "c2"
	break
    endif
end  

foreach plat ( $platform_list) 
      if ( $mypartition != "c1" && "$plat" !~ *"$mypartition"* ) then
        echo Platform list:  $platform_list
	echo Mixing c1ms and t1ms platforms is not supported
	exit 1
     endif
end  


if( $myfrestem != "" ) set AUTORTSDIR = $AUTORTSDIR/$myfrestem/$mypartition
if( $mydebuglevel != "" ) set AUTORTSDIR = $AUTORTSDIR/$mydebuglevel

if( ! -d $AUTORTSDIR)  mkdir -p $AUTORTSDIR 

set STDOUT = $AUTORTSDIR/go_rts.out 
set STDERR = $AUTORTSDIR/go_rts.err


foreach  xml ( $xml_list )
    set xmlfile = $xml_dir$xml

    if( ! -e $xmlfile ) then
       echo xml file $xmlfile not found
       continue
    endif
    
    set xmlbase = `basename $xmlfile`
    set xmldir  = `dirname $xmlfile`

    \cp $xmldir/setup_*.xml  $AUTORTSDIR/
    cp $xmlfile   $AUTORTSDIR/$xmlbase.$DATE

    set xmlfile = $AUTORTSDIR/$xmlbase.$DATE

if( $myrelease != "" ) then
    sed 's/<property name.*"RELEASE.*value.*\/>/  <property name=\"RELEASE\"  value=\"somethingnoonewouldthinkofever\"\/>/g' -i $xmlfile
    sed  "s/somethingnoonewouldthinkofever/$myrelease/g" -i $xmlfile
endif    
if( $myfrestem != "" ) then
    sed 's/<property name.*FRE_STEM.*value.*\/>/  <property name=\"FRE_STEM\"  value=\"\somethingnoonewouldthinkofever\"\/>/g' -i $xmlfile
    sed  "s/somethingnoonewouldthinkofever/$myfrestem/g" -i $xmlfile
endif    
if( $myfreversion != "" ) then
    sed 's/<property name.*FRE_VERSION.*value.*\/>/  <property name=\"FRE_VERSION\"  value=\"somethingnoonewouldthinkofever\"\/>/g' -i $xmlfile
    sed  "s/somethingnoonewouldthinkofever/$myfreversion/g" -i $xmlfile
endif    
if( $mydebuglevel != "" ) then
    grep -q 'property\W*name\W*DEBUGLEVEL' $xmlfile
    if( $status ) then 
       sed '/<experimentSuite/ a\ <property name=\"DEBUGLEVEL\"   value=\"\"\/>/' -i $xmlfile 
    endif

    sed 's/<property name.*DEBUGLEVEL.*value.*\/>/  <property name=\"DEBUGLEVEL\"   value=\"somethingnoonewouldthinkofever\"\/>/g' -i $xmlfile
    sed  "s/somethingnoonewouldthinkofever/$mydebuglevel/g" -i $xmlfile
endif

if( "$GO_OPS"  =~ *"use_libs"* ) then
    sed 's/<property name.*MODIFIER.*value.*\/>/  <property name=\"MODIFIER\"  value=\"_libs\"\/>/g' -i $xmlfile
    sed 's/<property name.*GOLD_SRC.*value.*\/>/  <property name=\"GOLD_SRC\"  value=\"\$root\/FMS_libs_compile\/src\/GOLD\"\/>/g' -i $xmlfile
#Add links to libs at the end
    sed 's/<\/experimentSuite>/ <experiment name="MOM_SIS_compile_libs"> <component><compile><csh>#external lib component<\/csh><\/compile><\/component> <\/experiment> \n <experiment name="mom4p1_coupled_compile_libs" inherit="MOM_SIS_compile_libs"\/> \n <experiment name="GOLD_SIS_compile_libs"> <component><compile><csh>#external lib component<\/csh><\/compile><\/component> <\/experiment> \n  <experiment name="MOM_SIS_LAD_FV_compile_libs"> <component><compile><csh>#external lib component<\/csh><\/compile><\/component> <\/experiment> \n <experiment name="CM2M_compile_libs" inherit="MOM_SIS_LAD_FV_compile_libs"\/> \n   <experiment name="MOM_SIS_LAD2_FV_compile_libs"> <component><compile><csh>#external lib component<\/csh><\/compile><\/component> <\/experiment> \n <experiment name="ESM2M_compile_libs" inherit="MOM_SIS_LAD2_FV_compile_libs"\/> \n <\/experimentSuite> /g' -i $xmlfile
endif

if( $mom_rts_tag != "" ) then
    sed 's/<property name.*MOM_RTS_TAG.*value.*\/>/  <property name=\"MOM_RTS_TAG\"  value=\"somethingnoonewouldthinkofever\"\/>/g' -i $xmlfile
    sed  "s/somethingnoonewouldthinkofever/$mom_rts_tag/g" -i $xmlfile
endif

if( $mom_cvs_tag != "" ) then
    sed 's/<property name.*MOM_CVS_TAG.*value.*\/>/  <property name=\"MOM_CVS_TAG\"  value=\"somethingnoonewouldthinkofever\"\/>/g' -i $xmlfile
    sed  "s/somethingnoonewouldthinkofever/$mom_cvs_tag/g" -i $xmlfile

sed 's/"ocean_barotropic_nml">/"ocean_barotropic_nml"> \n do_bitwise_exact_sum=.true./g' -i $xmlfile
sed 's/"ocean_grids_nml">/"ocean_grids_nml"> \n do_bitwise_exact_sum=.true./g'           -i $xmlfile
sed 's/"ocean_rivermix_nml">/"ocean_rivermix_nml"> \n do_bitwise_exact_sum=.true./g'     -i $xmlfile
sed 's/"ocean_submesoscale_nml">/"ocean_submesoscale_nml"> \n use_psi_legacy=.true./g'   -i $xmlfile

endif



set static = ""
foreach EXP ( $EXPLIST )
    if( "$EXP" =~ *"9by10"* ) then
	sed 's/<property name.*STATIC.*value.*\/>/  <property name=\"STATIC\"  value=\"_9by10\"\/>/g' -i $xmlfile
	set static = "9by10"
	break
    endif
    if( "$EXP" =~ *"30by10"* ) then
	sed 's/<property name.*STATIC.*value.*\/>/  <property name=\"STATIC\"  value=\"_30by10\"\/>/g' -i $xmlfile
	set static = "30by10"
	break
    endif
    if( "$EXP" =~ *"12by10"* ) then
	sed 's/<property name.*STATIC.*value.*\/>/  <property name=\"STATIC\"  value=\"_12by10\"\/>/g' -i $xmlfile
	set static = "12by10"
	break
    endif
    if( "$EXP" =~ *"18by10"* ) then
	sed 's/<property name.*STATIC.*value.*\/>/  <property name=\"STATIC\"  value=\"_18by10\"\/>/g' -i $xmlfile
	set static = "18by10"
	break
    endif
    if( "$EXP" =~ *"10by5"* ) then
	sed 's/<property name.*STATIC.*value.*\/>/  <property name=\"STATIC\"  value=\"_10by5\"\/>/g' -i $xmlfile
	set static = "10by5"
	break
     endif
end  

foreach EXP ( $EXPLIST )
      if ( $static != "" && "$EXP" !~ *"$static"* ) then
        echo Experiment list:  $EXPLIST
	echo Mixing static and dynamic test cases is not supported
	exit 1
     endif
end  

if ( $static != "" ) then
    ln -f -s $xmlfile $AUTORTSDIR/$xmlbase.$static.latest
else
    ln -f -s $xmlfile $AUTORTSDIR/$xmlbase.latest
endif


set TODAY = `date`
set LOGS = "======================================</br>"
set LOGS = "$LOGS $TODAY </br> $CMD_IN </br>"

    foreach platform ( $platform_list )
	foreach target   ( $target_list ) 
	set STDOUTDATE = $STDOUT.$DATE.$xmlbase.$platform.$target
	set STDERRDATE = $STDERR.$DATE.$xmlbase.$platform.$target

        set CMD = "( $RTSTOOL -x $xmlfile -p $platform -t $target $GO_OPS $EXPLIST >> $STDOUTDATE & ) >> & $STDERRDATE"

	set LOGS = "$LOGS </br> (<a href=file://$RTSTOOL>$RTSTOOL</a> -x <a href=file://$xmlfile>$xmlfile</a>  -p $platform -t $target $GO_OPS $EXPLIST >> <a href=file://$STDOUTDATE>$STDOUTDATE</a> & ) >> & <a href=file://$STDERRDATE>$STDERRDATE</a></br></br>" 

 	echo $DATE > $STDOUTDATE
	( $RTSTOOL -x $xmlfile -p $platform -t $target $GO_OPS $EXPLIST >> $STDOUTDATE & ) >> & $STDERRDATE 

#       Delay so that the CVS check-out to the same directory won't happen 
	echo
#	echo "I did: $CMD"
	echo
        echo "To monitor the progress you can do:"  
        echo "tail -f $STDOUTDATE"
	echo
	if( "$GO_OPS"  =~ *"compile"* ) then 
	    echo "300s delay between starting the experiments that include checkout and compilation ..."
	    sleep 300
	else
	    echo "60s delay between starting the experiments ..."	  
  	    sleep 60
	endif
	end
    end

end

if( ! $AUTOLOG ) then
    echo "Do you want to add the above actions to the logs for future reference?"
    if ( $< =~ *"y"* ) set AUTOLOG = 1
endif

if( $AUTOLOG ) then
    echo "$LOGS" >> $CMDLOGS.html
    echo "Done! To monitor the batch progress you can view $CMDLOGS.html "    
endif
    
exit 



#EXAMPLES
#
#BUILD
#
#/ncrc/home2/Niki.Zadeh/bin/go_rts_ALL.csh -d /ncrc/home2/Niki.Zadeh/xmls/siena_prerelease/xml/ -x "libraries.xml" -p "ncrc.intel,ncrc.pgi" -t "repro-openmp,prod-openmp" --go_ops "--use_libs,--build_only,-l,FMS_libs_compile" mom4p1_solo_compile_libs MOM_SIS_compile_libs GOLD_SIS_compile_libs MOM_SIS_LAD_FV_compile_libs GOLD_SIS_LAD_FV_compile_libs MOM_SIS_LAD2_FV_compile_libs GOLD_SIS_LAD2_FV_compile_libs MOM_SIS_LAD2_CS_compile_libs MOM_SIS_LAD_BGR_compile_libs
#
#RUN
#
#/ncrc/home2/Niki.Zadeh/bin/go_rts_ALL.csh -d /ncrc/home2/Niki.Zadeh/xmls/siena_prerelease/xml/ -x "ESM2_Control.xml" -p "ncrc.intel,ncrc.pgi" -t "repro-openmp,prod-openmp" --go_ops "--use_libs" ESM2G_Control-1860_dec29IC ESM2G_Control-1860_dec29IC_3thread 
#
#RUNS
#
#/ncrc/home2/Niki.Zadeh/bin/go_rts_ALL.csh -d /ncrc/home2/Niki.Zadeh/xmls/siena_prerelease/xml/ -x "mom4p1_cpld.xml" -p "ncrc.pgi" -t "repro-openmp" --go_ops "--use_libs,--all,--fre_ops,-u"    
#
#/ncrc/home2/Niki.Zadeh/bin/go_rts_ALL.csh -d /ncrc/home2/Niki.Zadeh/xmls/siena_prerelease/xml/ -x "CM2M_Control-1900.xml" -p "ncrc.intel,ncrc.pgi" -t "prod-openmp,repro-openmp" --go_ops "--use_libs" CM2.1p1_static_9by10 CM2.1p1_ensemble_concurrent_static_9by10 CM2M_12feb2009_nphysC_3thread_static_9by10 CM2G_static_9by10 CM2G_3thread_static_9by10
#
#/ncrc/home2/Niki.Zadeh/bin/go_rts_ALL_6.csh -d /ncrc/home2/Niki.Zadeh/xmls/siena_prerelease/xml/ -x "ESM2_Control.xml" -p "ncrc.intel" -t "prod-openmp" --go_ops "--use_libs,--fre_ops,-u" ESM2G_Control-1860_dec29IC
#
#/ncrc/home2/Niki.Zadeh/bin/frerts_batch_7.csh -d /ncrc/home2/Niki.Zadeh/xmls/siena_prerelease/xml/ -x "CM2M_Control-1900.xml" -p "ncrc.intel,ncrc.pgi" -t "prod-openmp" --frerts_ops "--all" --release testing --fre_stem testing_20111026 --fre_version 'fre\\/test'
#
#/ncrc/home2/Niki.Zadeh/bin/frerts_batch_7.csh -d /ncrc/home2/Niki.Zadeh/xmls/siena_prerelease/xml/ -x "mom4p1_solo.xml" -p "ncrc.intel,ncrc.pgi" -t "prod" --frerts_ops "--compile,--all" --release testing --fre_stem testing_20111026 --fre_version 'fre\\/test'
#
#/ncrc/home2/Niki.Zadeh/bin/frerts_batch_7.csh -x /ncrc/home2/Niki.Zadeh/xmls/riga_201104/xml/mom4p1_cpld.xml -p "ncrc.intel" -t "prod-openmp,repro-openmp" --frerts_ops "--no_stage,--no_rts,--all"
#
# /ncrc/home2/Niki.Zadeh/bin/frerts_batch_7.csh -d /ncrc/home2/Niki.Zadeh/xmls/siena_prerelease/xml/ -x "GOLD_SIS.xml" -p "ncrc.pgi" -t "prod-openmp" --frerts_ops "--use_libs" --release siena_prerelease --fre_stem siena_prerelease_oct7 --fre_version 'fre\\/test' --debuglevel _autorts_oct7 GOLD_SIS_63L GOLD_SIS_TOPAZ_63L
#
#/ncrc/home2/Niki.Zadeh/bin/frerts_batch_8.csh -x /ncrc/home2/Niki.Zadeh/xmls/siena_prerelease/xml/CM2.1U.xml -p "ncrc.intel" -t repro-openmp --frerts_ops "--compile,--fre_ops,-u" --release testing --fre_stem testing_20111026 --fre_version 'fre\\/test' CM2.1U_Control-1990_E1.M_3A
#
#/ncrc/home2/Niki.Zadeh/bin/frerts_batch_8.csh -x /ncrc/home2/Niki.Zadeh/xmls/siena_prerelease/xml/SM2.1U-LM3V.xml -p "ncrc.intel,ncrc.pgi" -t prod-openmp --frerts_ops "--compile,--fre_ops,-u" --release testing --fre_stem testing_20111026 --fre_version 'fre\\/test' SM2.1U_Control-1990_lm3v_pot_A1 
#
# /ncrc/home2/Niki.Zadeh/bin/frerts_batch_8.csh -x /ncrc/home2/Niki.Zadeh/xmls/siena_prerelease/xml/CM2.5_A_Control-1990_C.xml -p "ncrc.intel,ncrc.pgi" -t prod-openmp --frerts_ops "--compile,--fre_ops,-u" --release testing --fre_stem testing_20111026 --fre_version 'fre\\/test' CM2.5_A_Control-1990_C05
#
#
#/ncrc/home2/Niki.Zadeh/bin/frerts_batch_8.csh -x /ncrc/home2/Niki.Zadeh/xmls/siena_prerelease/xml_presiena_nnz/CM2M_Control-1900.xml -p "ncrc.intel" -t "prod-openmp" --frerts_ops "--use_libs,--no_rts,--fre_ops,-r=year;-o" --release siena_prerelease --fre_stem siena_prerelease_oct7 --fre_version 'fre\\/test' --debuglevel _autorts_oct7 CM2M_12feb2009_nphysC_3threadsof30             
#
#/ncrc/home2/Niki.Zadeh/bin/frerts_batch_8.csh -x /ncrc/home2/Niki.Zadeh/xmls/siena_prerelease/xml_presiena_nnz/libraries.xml -p "ncrc.intel_t1" -t "prod-openmp" --frerts_ops "--use_libs,--build_only,-l,FMS_libs_compile" --release siena_prerelease --fre_stem siena_prerelease_oct7 --fre_version 'fre\\/test' --debuglevel _autorts_oct7 MOM_SIS_LAD_FV_compile_libs GOLD_SIS_LAD_FV_compile_libs
#
#/ncrc/home2/Niki.Zadeh/bin/frerts_batch_8.csh -x /ncrc/home2/Niki.Zadeh/xmls/siena_prerelease/xml_presiena_nnz/CM2M_Control-1900.xml -p "ncrc.intel_t1" -t "prod-openmp" --frerts_ops "--use_libs,--no_rts,--no_stage,--fre_ops,-P=t1;-r=year" --release siena_prerelease --fre_stem siena_prerelease_oct7 --fre_version 'fre\\/test' --debuglevel _autorts_oct7 CM2M_12feb2009_nphysC_3threadsof30
#
#/ncrc/home2/Niki.Zadeh/bin/frerts_batch_8.csh -x /ncrc/home2/Niki.Zadeh/xmls/siena_prerelease/xml_presiena_nnz/ESM2_Control.xml -p "ncrc.intel_t1,ncrc.pgi_t1" -t "prod-openmp" --frerts_ops "--all,--use_libs,--fre_ops,-o;-P=t1" --release siena_prerelease --fre_stem siena_prerelease_oct7 --fre_version 'fre\\/test' --debuglevel _autorts_oct7
#
#/ncrc/home2/Niki.Zadeh/bin/frerts_batch_8.csh -x /ncrc/home2/Niki.Zadeh/xmls/siena_prerelease/xml_presiena_nnz/libraries.xml -p "ncrc.intel,ncrc.pgi" -t "prod-openmp" --frerts_ops "--use_libs,--build_only,-l,FMS_libs_compile" --release testing --fre_stem testing_20111115 --fre_version 'fre\\/test' MOM_SIS_LAD_FV_compile_libs GOLD_SIS_LAD_FV_compile_libs MOM_SIS_LAD2_FV_compile_libs GOLD_SIS_LAD2_FV_compile_libs MOM_SIS_LAD2_CS_compile_libs
#
#/ncrc/home2/Niki.Zadeh/bin/frerts_batch_8.csh -x /ncrc/home2/Niki.Zadeh/xmls/siena_prerelease/xml_presiena_nnz/ESM2.5M_Control.xml  -p "ncrc.intel_t1" -t "prod-openmp" --frerts_ops "--no_stage,--compile,--fre_ops,-u;-P=t1" --release testing --fre_stem testing_20111122 --fre_version 'fre\\/test' ESM2.5M_Control-1990
#
#
#testing branch code
#First compile the branch code lib
#/ncrc/home2/Niki.Zadeh/bin/frerts_batch_10.csh -x /ncrc/home2/Niki.Zadeh/xmls/siena_prerelease/xml_presiena_nnz/libraries.xml -p "ncrc.intel,ncrc.pgi" -t "prod-openmp" --frerts_ops "--use_libs,--build_only,-l,FMS_libs_compile" --release siena_prerelease2 --fre_stem siena_prerelease2 --fre_version 'fre\\/test' --debuglevel _mom4p1_siena_08dec2011_smg --mom_rts_tag mom4p1_siena_08dec2011_smg compile_libs_mom4p1_siena_08dec2011_smg
#
#Then compile the coupler and link
#/ncrc/home2/Niki.Zadeh/bin/frerts_batch_10.csh -x /ncrc/home2/Niki.Zadeh/xmls/siena_prerelease/xml_presiena_nnz/libraries.xml -p "ncrc.intel,ncrc.pgi" -t "prod-openmp" --frerts_ops "--use_libs,--build_only,-l,compile_libs_mom4p1_siena_08dec2011_smg" --release siena_prerelease2 --fre_stem siena_prerelease2 --fre_version 'fre\\/test' --debuglevel _mom4p1_siena_08dec2011_smg --mom_rts_tag mom4p1_siena_08dec2011_smg MOM_SIS_compile_libs_mom4p1_siena_08dec2011_smg MOM_SIS_LAD_FV_compile_libs_mom4p1_siena_08dec2011_smg
#
#
