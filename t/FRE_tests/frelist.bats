# -*- mode: sh; eval: (sh-set-shell "sh"); -*-

# The output_good strings are configured with the exact number of spaces needed
# for the tests to pass.  DO NOT adjust unless needed, this includes removing
# whitespace.

load test_helpers

setup() {
    unique_string="date$(date +%s)pid$$"
}

@test "frelist is in PATH" {
    run which frelist
    echo "Got: \"$output\""
    echo "Exit status: $status"
    [ "$status" -eq 0 ]
}

@test "frelist print help message" {
    run frelist -h
    echo "Got: \"$output\""
    echo "Exit status: $status"
    [ "$status" -eq 0 ]
}

@test "frelist print version" {
    run frelist -V
    echo "Got: \"$output\""
    echo "Exit status: $status"
    [ "$status" -eq 0 ]
}

@test "No XML listed on frelist command line and no rts.xml file" {
    output_good="*FATAL*: The xmlfile 'rts.xml' doesn't exist or isn't readable"
    if [ -f rts.xml ]; then
        rm rts.xml
    fi

    run frelist
    echo "Expected: \"$output_good\""
    echo "Got:      \"$output\""
    echo "Exit status: $status"
    [ "$status" -eq 10 ]
    [[ "$output_good" =~ "$output" ]]
}

@test "No XML listed on command line, and rts.xml exists" {
    output_good="CM2.1U_Control-1990_E1.M_3A
CM2.1U_Control-1990_E1.M_3B_snowmelt INHERITS FROM CM2.1U_Control-1990_E1.M_3A
CM2.1U_Control-1990_E1.M_3B_snowmelt_static_ocn6x5 INHERITS FROM CM2.1U_Control-1990_E1.M_3B_snowmelt"

    cp CM2.1U.xml rts.xml
    run frelist
    echo "Expected: \"$output_good\""
    echo "Got: \"$output\""
    echo "Exit status: $status"
    [ "$status" -eq 0 ]
    [[ "$output_good" =~ "$output" ]]
    rm rts.xml
}

@test "Validate XML" {
    # Need more tests with bad XMLs to catch invalid XMLs
    run frelist -C -x CM2.1U.xml
    echo "Got: \"$output\""
    echo "Exit status: $status"
    [ "$status" -eq 0 ]
}

@test "Validate Curator tags when Curator tags don't exist" {
    output_good="*FATAL*: No CMIP Curator tags found; see CMIP metadata tag documentation at http://cobweb.gfdl.noaa.gov/~pcmdi/CMIP6_Curator/xml_documentation"

    run frelist -c -x CM2.1U.xml CM2.1U_Control-1990_E1.M_3A
    echo "Expected: \"$output_good\""
    echo "Got: \"$output\""
    echo "Exit status: $status"
    [ "$status" -eq 30 ]
    [ "$output" = "$output_good" ]
}

@test "Validate Curator tags" {
    skip "No curator tags in the CM2.1U.xml file"
    # Need more tests with bad XMLs to catch invalid XMLs
    run frelist -c -x CM2.1U.xml CM2.1U_Control-1990_E1.M_3A
    echo "Got: \"$output\""
    echo "Exit status: $status"
    [ "$status" -eq 0 ]
}

@test "List experiments no platform listed" {
    output_good="CM2.1U_Control-1990_E1.M_3A
CM2.1U_Control-1990_E1.M_3B_snowmelt INHERITS FROM CM2.1U_Control-1990_E1.M_3A
CM2.1U_Control-1990_E1.M_3B_snowmelt_static_ocn6x5 INHERITS FROM CM2.1U_Control-1990_E1.M_3B_snowmelt"

    run frelist -x CM2.1U.xml
    echo "Expected: \"$output_good\""
    echo "Got:      \"$output\""
    echo "Exit status: $status"
    [ "$status" -eq 0 ]
    [[ "$output_good" =~ "$output" ]]
}

@test "List experiments when --platform=${FRE_SYSTEM_SITE}.intel" {
    output_good="CM2.1U_Control-1990_E1.M_3A
CM2.1U_Control-1990_E1.M_3B_snowmelt INHERITS FROM CM2.1U_Control-1990_E1.M_3A
CM2.1U_Control-1990_E1.M_3B_snowmelt_static_ocn6x5 INHERITS FROM CM2.1U_Control-1990_E1.M_3B_snowmelt"

    run frelist -p ${FRE_SYSTEM_SITE}.intel -x CM2.1U.xml
    echo "Expected: \"$output_good\""
    echo "Got:      \"$output\""
    echo "Exit status: $status"
    [ "$status" -eq 0 ]
    [[ "$output_good" =~ "$output" ]]
}

@test "List experiments without inherits" {
    output_good="CM2.1U_Control-1990_E1.M_3A
CM2.1U_Control-1990_E1.M_3B_snowmelt
CM2.1U_Control-1990_E1.M_3B_snowmelt_static_ocn6x5"

    run frelist --no-inherit -x CM2.1U.xml
    echo "Expected: \"$output_good\""
    echo "Got:      \"$output\""
    echo "Exit status: $status"
    [ "$status" -eq 0 ]
    [[ "$output_good" =~ "$output" ]]
}

@test "Capture bad project setting" {
    output_good="*FATAL*: Your project name 'gfdl_YOURGROUPLETTER' appears to be invalid, please correct your XML's platform section."

    # Skip if not on ncrc3 or ncrc4
    if [ "${FRE_SYSTEM_SITE}" != "ncrc3" -a "${FRE_SYSTEM_SITE}" != "ncrc4" ]; then
        skip "Test only valid on ncrc3 and ncrc4 sites"
    fi
    run frelist -p ${FRE_SYSTEM_SITE}.yourgroupletter -x CM2.1U.xml
    echo "Expected: \"$output_good\""
    echo "Got:      \"$output\""
    echo "Exit status: $status"
    [ "$status" -eq 30 ]
    [[ "$output_good" =~ "$output" ]]
}

@test "List experiment description" {
    output_good="CM2.1U_Control-1990_E1.M_3A
---------------------------------------------------------------------

      This experiment is same as the latest CM2.1U_Control-1860_D1 specified in
      /home/ccsp/fjz/ipcc_ar4_preK/CM2.1U_Control-1860_D1.xml, except for:
      1. running with year 1990 radiative forcing and 1990 land cover
      2. the executable is built with Khartoum code on sep 01, 2004 by
         this xml file:
         /home/fjz/cm2.1_K_20040901/CM2.1U_Control-1860_D1.xml
      3. the initCond is based on /archive/fjz/IC/CM3_ic_00010101.cpio
         but reformed to one time level by Matt.
      4. the diagTable has some addtions for energy balance terms
         suggested by Tony R.
      5. run 30 atmos and 20 ocean PEs
    
"

    run frelist -D -x CM2.1U.xml CM2.1U_Control-1990_E1.M_3A
    echo "Expected: \"$output_good\""
    echo "Got:      \"$output\""
    echo "Exit status: $status"
    [ "$status" -eq 0 ]
    [[ "$output_good" =~ "$output" ]]
}

@test "Get stdout directory for --platform=${FRE_SYSTEM_SITE}.intel" {
    output_good="/lustre/f1/$USER/.*/CM2.1U_Control-1990_E1.M_3A/${FRE_SYSTEM_SITE}.intel-prod/stdout"

    run frelist -p ${FRE_SYSTEM_SITE}.intel -d stdout -x CM2.1U.xml CM2.1U_Control-1990_E1.M_3A
    echo "Expected: \"$output_good\""
    echo "Got:      \"$output\""
    echo "Exit status: $status"
    [ "$status" -eq 0 ]
    string_matches_pattern "$output" "$output_good"
}

@test "Get analysis and archive directories for --platform=gfdl.${FRE_SYSTEM_SITE}-intel" {
    output_good="archive: /archive/\$USER/.*/CM2.1U_Control-1990_E1.M_3A/gfdl.${FRE_SYSTEM_SITE}-intel-prod
analysis: /archive/\$USER/.*/CM2.1U_Control-1990_E1.M_3A/gfdl.${FRE_SYSTEM_SITE}-intel-prod/analysis"

    run frelist -p gfdl.${FRE_SYSTEM_SITE}-intel -d analysis,archive -x CM2.1U.xml CM2.1U_Control-1990_E1.M_3A
    echo "Expected: \"$output_good\""
    echo "Got:      \"$output\""
    echo "Exit status: $status"
    [ "$status" -eq 0 ]
    string_matches_pattern "$output" "$output_good"
}

@test "List all directories for ${FRE_SYSTEM_SITE}.intel" {
    # Assume all directories are correct, if the ones above are
    # This is to only check that this specific command runs
    run frelist -d all -x CM2.1U.xml -p ${FRE_SYSTEM_SITE}.intel
    echo "Got: \"$output\""
    echo "Exit status: $status"
    [ "$status" -eq 0 ]
}

@test "Get the executable --platform=${FRE_SYSTEM_SITE}.intel" {
    output_good="/lustre/f1/unswept/.*/.*/CM2.1U_Control-1990_E1.M_3A/${FRE_SYSTEM_SITE}.intel-prod/exec/fms_CM2.1U_Control-1990_E1.M_3A.x CM2.1U_Control-1990_E1.M_3A"

    run frelist -p ${FRE_SYSTEM_SITE}.intel -E -x CM2.1U.xml CM2.1U_Control-1990_E1.M_3A
    echo "Expected: \"$output_good\""
    echo "Got:      \"$output\""
    echo "Exit status: $status"
    [ "$status" -eq 0 ]
    string_matches_pattern "$output" "$output_good"
}

@test "Get the executable from inherited experiment --platform=${FRE_SYSTEM_SITE}.intel" {
    output_good="/lustre/f1/unswept/.*/.*/CM2.1U_Control-1990_E1.M_3A/${FRE_SYSTEM_SITE}.intel-prod/exec/fms_CM2.1U_Control-1990_E1.M_3A.x CM2.1U_Control-1990_E1.M_3A"

    run frelist -p ${FRE_SYSTEM_SITE}.intel -E -x CM2.1U.xml CM2.1U_Control-1990_E1.M_3B_snowmelt
    echo "Expected: \"$output_good\""
    echo "Got:      \"$output\""
    echo "Exit status: $status"
    [ "$status" -eq 0 ]
    string_matches_pattern "$output" "$output_good"
}

@test "Get the executable with a remote user" {
    # Pick a remote site
    case $( hostname ) in
	an??? )
	    REMOTE_SITE=${FRE_SYSTEM_SITE}.intel
	    output_good="/lustre/f1/unswept/REM_USER/.*/CM2.1U_Control-1990_E1.M_3A/${REMOTE_SITE}-prod/exec/fms_CM2.1U_Control-1990_E1.M_3A.x CM2.1U_Control-1990_E1.M_3A"
	    ;;
	* )
	    REMOTE_SITE=gfdl.${FRE_SYSTEM_SITE}-intel
	    output_good="/home/REM_USER/.*/CM2.1U_Control-1990_E1.M_3A/${REMOTE_SITE}-prod/exec/fms_CM2.1U_Control-1990_E1.M_3A.x CM2.1U_Control-1990_E1.M_3A"
	    ;;
    esac

    run frelist -R REM_USER -p ${REMOTE_SITE} -E -x CM2.1U.xml CM2.1U_Control-1990_E1.M_3A
    echo "Expected \"$output_good\""
    echo "Got:     \"$output\""
    echo "Exit status: $status"
    [ "$status" -eq 0 ]
    string_matches_pattern "$output" "$output_good"
}

@test "Get the executable for all experiments with --target=openmp,repro" {
    output_good="CM2.1U_Control-1990_E1.M_3A /lustre/f1/unswept/$USER/.*/CM2.1U_Control-1990_E1.M_3A/${FRE_SYSTEM_SITE}.intel-repro-openmp/exec/fms_CM2.1U_Control-1990_E1.M_3A.x CM2.1U_Control-1990_E1.M_3A
CM2.1U_Control-1990_E1.M_3B_snowmelt /lustre/f1/unswept/$USER/.*/CM2.1U_Control-1990_E1.M_3A/${FRE_SYSTEM_SITE}.intel-repro-openmp/exec/fms_CM2.1U_Control-1990_E1.M_3A.x CM2.1U_Control-1990_E1.M_3A
CM2.1U_Control-1990_E1.M_3B_snowmelt_static_ocn6x5 /lustre/f1/unswept/$USER/.*/CM2.1U_Control-1990_E1.M_3B_snowmelt_static_ocn6x5/${FRE_SYSTEM_SITE}.intel-repro-openmp/exec/fms_CM2.1U_Control-1990_E1.M_3B_snowmelt_static_ocn6x5.x CM2.1U_Control-1990_E1.M_3B_snowmelt_static_ocn6x5"

    run frelist -p ${FRE_SYSTEM_SITE}.intel -t openmp,repro -E -R ${USER} -x CM2.1U.xml
    echo "Expected: \"$output_good\""
    echo "Got:      \"$output\""
    echo "Exit status: $status"
    [ "$status" -eq 0 ]
    string_matches_pattern "$output" "$output_good"
}

@test "Get the namelist for an inherited experiment" {
    # The namelist is long, for now just checking the exit status
    run frelist -p ${FRE_SYSTEM_SITE}.intel -N -x CM2.1U.xml CM2.1U_Control-1990_E1.M_3B_snowmelt
    echo "Got: \"$output\""
    echo "Exit status: $status"
    [ "$status" -eq 0 ]
}

@test "Extract platform csh section --platform=gfdl.${FRE_SYSTEM_SITE}-intel" {
    output_good="
# Platform environment defaults from ${FRE_COMMANDS_HOME}/site/gfdl/env.defaults
source \$MODULESHOME/init/csh
module use -a /home/fms/local/modulefiles
module purge
module load fre/$FRE_COMMANDS_VERSION
module load fre-analysis
module load git

# Platform environment overrides from XML"

    sed -e "s/\(^ *<property *name=\"FRE_VERSION\" *value=\"\).*\(\"\)/\1${FRE_COMMANDS_VERSION}\2/" CM2.1U.xml > ${unique_string}-temp.xml
    run frelist -p gfdl.${FRE_SYSTEM_SITE}-intel -S -x ${unique_string}-temp.xml
    echo "Expected: \"$output_good\""
    echo "Got:      \"$output\""
    echo "Exit status: $status"
    [ "$status" -eq 0 ]
    string_matches_pattern "$output" "$output_good"
    rm -f ${unique_string}-temp.xml
}

@test "Accept regression option" {
    run frelist -r foo -x CM2.1U.xml -p ${FRE_SYSTEM_SITE}.intel
    echo "Got: \"$output\""
    echo "Exit status: $status"
    [ "$status" -eq 0 ]
}

@test "Print namelist for regression basic, inherited experiment" {
    run frelist -r basic -N -x CM2.1U.xml CM2.1U_Control-1990_E1.M_3B_snowmelt -p ${FRE_SYSTEM_SITE}.intel
    echo "Got: \"$output\""
    echo "Exit status: $status"
    [ "$status" -eq 0 ]
}

@test "Get regression postfix" {
    output_good="
/// CM2.1U_Control-1990_E1.M_3A
/////////////////////////////////////////////////////////////////////////////////////////////////////
LABEL      RUN#  DUPE  POSTFIX                                                                       
-----------------------------------------------------------------------------------------------------
basic         0        1x0m8d_30x1a_20x1o              
restarts      0        2x0m4d_30x1a_20x1o              
scaling       0        1x0m8d_30x1a_12x1o              
scaling       1        1x0m8d_30x1a_30x1o              
scaling       2        1x0m8d_30x1a_42x1o              
scaling       3        1x0m8d_30x2a_120x1o             
-----------------------------------------------------------------------------------------------------"

    run frelist -x CM2.1U.xml -p ${FRE_SYSTEM_SITE}.intel -t openmp -r suite --postfix CM2.1U_Control-1990_E1.M_3A
    echo "Expected: \"$output_good\""
    echo "Got:      \"$output\""
    echo "Exit status: $status"
    [ "$status" -eq 0 ]
    [[ "$output_good" =~ "$output" ]]
}

@test "Use --evaluate to extract data from XML" {
    output_good='
# specific humidity for moist runs

 "TRACER", "atmos_mod", "sphum"
           "longname",     "specific humidity"
           "units",        "kg/kg"
           "profile_type", "fixed", "surface_value=3.e-6" /

# required by ESM

  "TRACER", "land_mod", "sphum"
           "longname",     "specific humidity"
            "units",        "kg/kg" /

# prognotic cloud scheme tracers

  "TRACER", "atmos_mod", "liq_wat"
            "longname",     "cloud liquid specific humidity"
            "units",        "kg/kg" /
  "TRACER", "atmos_mod", "ice_wat"
            "longname",     "cloud ice water specific humidity"
            "units",        "kg/kg" /
  "TRACER", "atmos_mod", "cld_amt"
            "longname",     "cloud fraction"
            "units",        "none" /

# test tracer for radon

# "TRACER", "atmos_mod", "radon"
#           "longname",     "radon test tracer"
#           "units",        "kg/kg" /

      '

    run frelist -p ${FRE_SYSTEM_SITE}.intel -e 'input/fieldTable' -x CM2.1U.xml CM2.1U_Control-1990_E1.M_3A
    echo "Expected: \"$output_good\""
    echo "Got:      \"$output\""
    echo "Exit status: $status"
    [ "$status" -eq 0 ]
    [[ "$output_good" =~ "$output" ]]
}

@test "Test -Xml option" {
    run frelist -X -x CM2.1U.xml -p ${FRE_SYSTEM_SITE}.intel CM2.1U_Control-1990_E1.M_3B_snowmelt_static_ocn6x5
    echo "Got: \"$output\""
    echo "Exit status: $status"
    [ "$status" -eq 0 ]
}

@test "Test inherit of external XML file" {
    skip "MOM6 needs to be updated to bronx-11 first"
    output_good="
           source \$MODULESHOME/init/csh
           module purge
           module load fre/bronx-10

           module use -a /home/John.Krasting/local/modulefiles
           module load jpk-analysis/0.0.4
          #Some tricks to use the refineDiag and analysis scripts from a checkout of MOM6 at gfdl 
           setenv FREVERSION fre/bronx-10           
           setenv NBROOT /nbhome/${USER}/.*_mom6_2014.12.24/\$(name)/gfdl.ncrc2-intel-prod
           mkdir -p \$NBROOT
           cd \$NBROOT
           git clone /home/fms/git/ocean/mom6

         "

    run frelist -R ${USER} -p gfdl.ncrc2-intel -S -x MOM6_solo.xml
    echo "Expected: \"$output_good\""
    echo "Got:      \"$output\""
    echo "Exit status: $status"
    [ "$status" -eq 0 ]
    [[ "$output_good" =~ "$output" ]]
}
