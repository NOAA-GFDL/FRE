#!/usr/bin/env bats
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
    print_output_and_status
    [ "$status" -eq 0 ]
}

@test "frelist print help message" {
    run frelist -h
    print_output_and_status
    [ "$status" -eq 0 ]
}

@test "frelist print version" {
    run frelist -V
    print_output_and_status
    [ "$status" -eq 0 ]
}

@test "No XML listed on frelist command line and no rts.xml file" {
    output_good="*FATAL*: The xmlfile 'rts.xml' doesn't exist or isn't readable"
    if [ -f rts.xml ]; then
        rm rts.xml
    fi

    run frelist
    print_output_status_and_diff_expected
    [ "$status" -eq 10 ]
    [[ "$output_good" =~ "$output" ]]
}

@test "No XML listed on command line, and rts.xml exists" {
    output_good="CM2.1U_Control-1990_E1.M_3A
CM2.1U_Control-1990_E1.M_3B_snowmelt INHERITS FROM CM2.1U_Control-1990_E1.M_3A
CM2.1U_Control-1990_E1.M_3B_snowmelt_static_ocn6x5 INHERITS FROM CM2.1U_Control-1990_E1.M_3B_snowmelt"

    cp CM2.1U.xml rts.xml
    run frelist
    print_output_status_and_diff_expected
    [ "$status" -eq 0 ]
    [[ "$output_good" =~ "$output" ]]
    rm rts.xml
}

@test "Validate XML" {
    # Need more tests with bad XMLs to catch invalid XMLs
    run frelist -C -x CM2.1U.xml
    print_output_and_status
    [ "$status" -eq 0 ]
}

@test "Validate Curator tags when Curator tags don't exist" {
    output_good="*FATAL*: No CMIP Curator tags found; see CMIP metadata tag documentation at http://cobweb.gfdl.noaa.gov/~pcmdi/CMIP6_Curator/xml_documentation"

    run frelist -c -x CM2.1U.xml CM2.1U_Control-1990_E1.M_3A
    print_output_status_and_diff_expected
    [ "$status" -eq 30 ]
    [ "$output" = "$output_good" ]
}

@test "Validate Curator tags" {
    # Need more tests with bad XMLs to catch invalid XMLs
    output_good="<NOTE> : The XML file 'publicMetadata' has been successfully validated"
    run frelist -c -x CM2.1U.xml CM2.1U_Control-1990_E1.M_3B_snowmelt_static_ocn6x5
    print_output_status_and_diff_expected
    [ "$status" -eq 0 ]
    [ "$output" = "$output_good" ]
}

@test "List experiments no platform listed" {
    output_good="CM2.1U_Control-1990_E1.M_3A
CM2.1U_Control-1990_E1.M_3B_snowmelt INHERITS FROM CM2.1U_Control-1990_E1.M_3A
CM2.1U_Control-1990_E1.M_3B_snowmelt_static_ocn6x5 INHERITS FROM CM2.1U_Control-1990_E1.M_3B_snowmelt"

    run frelist -x CM2.1U.xml
    print_output_status_and_diff_expected
    [ "$status" -eq 0 ]
    [[ "$output_good" =~ "$output" ]]
}

@test "List experiments when --platform=${default_platform}" {
    output_good="CM2.1U_Control-1990_E1.M_3A
CM2.1U_Control-1990_E1.M_3B_snowmelt INHERITS FROM CM2.1U_Control-1990_E1.M_3A
CM2.1U_Control-1990_E1.M_3B_snowmelt_static_ocn6x5 INHERITS FROM CM2.1U_Control-1990_E1.M_3B_snowmelt"

    run frelist -p ${default_platform} -x CM2.1U.xml
    print_output_status_and_diff_expected
    [ "$status" -eq 0 ]
    [[ "$output_good" =~ "$output" ]]
}

@test "List experiments without inherits" {
    output_good="CM2.1U_Control-1990_E1.M_3A
CM2.1U_Control-1990_E1.M_3B_snowmelt
CM2.1U_Control-1990_E1.M_3B_snowmelt_static_ocn6x5"

    run frelist --no-inherit -x CM2.1U.xml
    print_output_status_and_diff_expected
    [ "$status" -eq 0 ]
    [[ "$output_good" =~ "$output" ]]
}

@test "Capture missing project setting" {
    output_good="*FATAL*: Your project name is not specified and is required on this site; please correct your XML's platform section."

    # Skip if not on ncrc3 or ncrc4
    if [ "${FRE_SYSTEM_SITE}" != "ncrc" ]; then
       skip "Test only valid on ncrc3 and ncrc4 sites"
    else
       case "$(hostname)" in
          gaea9|gaea1[0-2] )
             ncrc_site="ncrc3"
             ;;
          * )
             ncrc_site="ncrc4"
             ;;
       esac
    fi

    run frelist -p ${ncrc_site}.nogroup -x CM2.1U.xml
    print_output_status_and_diff_expected
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
    print_output_status_and_diff_expected
    [ "$status" -eq 0 ]
    [[ "$output_good" =~ "$output" ]]
}

@test "Get stdout directory for --platform=${default_platform}" {
    case ${FRE_SYSTEM_SITE} in
        ncrc )
            stdoutRoot="/lustre/f2/scratch"
            ;;
        gfdl-ws )
            stdoutRoot="/home"
            ;;
        gfdl )
            stdoutRoot="/home"
            ;;
        theia )
            stdoutRoot="/scratch4/GFDL/gfdlscr"
            ;;
        * )
            skip "Unknown site '${FRE_SYSTEM_SITE}'."
            ;;
    esac

    output_good="${stdoutRoot}/$USER/[a-zA-Z0-9_]\+\?/CM2.1U_Control-1990_E1.M_3A/${default_platform}-prod/stdout"

    run frelist -p ${default_platform} -d stdout -x CM2.1U.xml CM2.1U_Control-1990_E1.M_3A
    print_output_status_and_diff_expected
    [ "$status" -eq 0 ]
    string_matches_pattern "$output" "$output_good"
}

@test "Get analysis and archive directories for --platform=gfdl.${default_platform/./-}" {
    case ${FRE_SYSTEM_SITE} in
        gfdl-ws )
            userStr=$USER
            platform=gfdl.${default_platform/./-}
            ;;
        gfdl )
            userStr=$USER
            platform=gfdl.intel
            ;;
        * )
            userStr=\$USER
            platform=gfdl.${default_platform/./-}
            ;;
    esac

    output_good="archive: /archive/$userStr/.*/CM2.1U_Control-1990_E1.M_3A/${platform}-prod
analysis: /archive/$userStr/.*/CM2.1U_Control-1990_E1.M_3A/${platform}-prod/analysis"

    run frelist -p ${platform} -d analysis,archive -x CM2.1U.xml CM2.1U_Control-1990_E1.M_3A
    print_output_status_and_diff_expected
    [ "$status" -eq 0 ]
    string_matches_pattern "$output" "$output_good"
}

@test "List all directories for ${FRE_SYSTEM_SITE}.intel" {
    # Assume all directories are correct, if the ones above are
    # This is to only check that this specific command runs
    run frelist -d all -x CM2.1U.xml -p ${default_platform}
    print_output_and_status
    [ "$status" -eq 0 ]
}

@test "Get the executable --platform=${default_platform}" {
    case ${FRE_SYSTEM_SITE} in
        ncrc )
            execRoot="/lustre/f2/dev"
            ;;
        gfdl-ws )
            execRoot="/home"
            ;;
        gfdl )
            execRoot="/home"
            ;;
        theia )
            execRoot="/scratch4/GFDL/gfdlscr"
            ;;
        * )
            skip "Unknown site '${FRE_SYSTEM_SITE}'."
            ;;
    esac

    output_good="$execRoot/$USER/.*/CM2.1U_Control-1990_E1.M_3A/${default_platform}-prod/exec/fms_CM2.1U_Control-1990_E1.M_3A.x CM2.1U_Control-1990_E1.M_3A"

    run frelist -p ${default_platform} -E -x CM2.1U.xml CM2.1U_Control-1990_E1.M_3A
    print_output_status_and_diff_expected
    [ "$status" -eq 0 ]
    string_matches_pattern "$output" "$output_good"
}

@test "Get the executable from inherited experiment --platform=${default_platform}" {
    case ${FRE_SYSTEM_SITE} in
        ncrc )
            execRoot="/lustre/f2/dev"
            ;;
        gfdl-ws )
            execRoot="/home"
            ;;
        gfdl )
            execRoot="/home"
            ;;
        theia )
            execRoot="/scratch4/GFDL/gfdlscr"
            ;;
        * )
            skip "Unknown site '${FRE_SYSTEM_SITE}'."
            ;;
    esac

    output_good="$execRoot/$USER/.*/CM2.1U_Control-1990_E1.M_3A/${default_platform}-prod/exec/fms_CM2.1U_Control-1990_E1.M_3A.x CM2.1U_Control-1990_E1.M_3A"

    run frelist -p ${default_platform} -E -x CM2.1U.xml CM2.1U_Control-1990_E1.M_3B_snowmelt
    print_output_status_and_diff_expected
    [ "$status" -eq 0 ]
    string_matches_pattern "$output" "$output_good"
}

@test "Get the executable with a remote user" {
    # Pick a remote site
    case ${default_platform%%.*} in
        ncrc3 )
            REMOTE_SITE=gfdl-ws.intel
            ;;
        ncrc4 )
            REMOTE_SITE=gfdl.ncrc4-intel
            ;;
        gfdl | gfdl-ws )
            REMOTE_SITE=ncrc4.intel
            ;;
        * )
            skip "Unknown site '${FRE_SYSTEM_SITE}'."
            ;;
    esac
    case $REMOTE_SITE in
        ncrc4.intel )
            execRoot='$DEV'
            ;;
        gfdl-ws.intel )
            execRoot="/home"
            ;;
        gfdl.ncrc4-intel )
            execRoot="/home"
            ;;
    esac

    output_good="${execRoot}/REM_USER/.*/CM2.1U_Control-1990_E1.M_3A/${REMOTE_SITE}-prod/exec/fms_CM2.1U_Control-1990_E1.M_3A.x CM2.1U_Control-1990_E1.M_3A"

    run frelist -R REM_USER -p ${REMOTE_SITE} -E -x CM2.1U.xml CM2.1U_Control-1990_E1.M_3A
    print_output_status_and_diff_expected
    [ "$status" -eq 0 ]
    string_matches_pattern "$output" "$output_good"
}

@test "Get the executable for all experiments with --target=openmp,repro" {
    case ${FRE_SYSTEM_SITE} in
        ncrc )
            execRoot="/lustre/f2/dev"
            ;;
        gfdl-ws )
            execRoot="/home"
            ;;
        gfdl )
            execRoot="/home"
            ;;
        theia )
            execRoot="/scratch4/GFDL/gfdlscr"
            ;;
        * )
            skip "Unknown site '${FRE_SYSTEM_SITE}'."
            ;;
    esac

    output_good="CM2.1U_Control-1990_E1.M_3A $execRoot/$USER/.*/CM2.1U_Control-1990_E1.M_3A/${default_platform}-repro-openmp/exec/fms_CM2.1U_Control-1990_E1.M_3A.x CM2.1U_Control-1990_E1.M_3A
CM2.1U_Control-1990_E1.M_3B_snowmelt $execRoot/$USER/.*/CM2.1U_Control-1990_E1.M_3A/${default_platform}-repro-openmp/exec/fms_CM2.1U_Control-1990_E1.M_3A.x CM2.1U_Control-1990_E1.M_3A
CM2.1U_Control-1990_E1.M_3B_snowmelt_static_ocn6x5 $execRoot/$USER/.*/CM2.1U_Control-1990_E1.M_3B_snowmelt_static_ocn6x5/${default_platform}-repro-openmp/exec/fms_CM2.1U_Control-1990_E1.M_3B_snowmelt_static_ocn6x5.x CM2.1U_Control-1990_E1.M_3B_snowmelt_static_ocn6x5"

    run frelist -p ${default_platform} -t openmp,repro -E -R ${USER} -x CM2.1U.xml
    print_output_status_and_diff_expected
    [ "$status" -eq 0 ]
    string_matches_pattern "$output" "$output_good"
}

@test "Get the namelist for an inherited experiment" {
    # The namelist is long, for now just checking the exit status
    # This test requires the platform to be able to run, which gfdl cannot.  Skip on gfdl
    case ${FRE_SYSTEM_SITE} in
        gfdl )
            skip "Don't test frelist on Analysis"
            ;;
    esac

    run frelist -p ${default_platform} -N -x CM2.1U.xml CM2.1U_Control-1990_E1.M_3B_snowmelt
    print_output_and_status
    [ "$status" -eq 0 ]
}

@test "Get the number of nodes that would be requested for an experiment production run" {
    case "${default_platform%%.*}" in
        ncrc? )
            num_nodes=7
            ;;
        theia )
            num_nodes=3
            ;;
        * )
            skip "--nodes not supported on site '${FRE_SYSTEM_SITE}'"
    esac

    output_good="CM2.1U_Control-1990_E1.M_3B_snowmelt production would request $num_nodes nodes.
CM2.1U_Control-1990_E1.M_3B_snowmelt INHERITS FROM CM2.1U_Control-1990_E1.M_3A"

    run frelist -p ${default_platform} -t prod,openmp -x CM2.1U.xml CM2.1U_Control-1990_E1.M_3B_snowmelt --nodes

    print_output_status_and_diff_expected
    [ "$output" = "$output_good" ]
    [ "$status" -eq 0 ]
}

@test "Get the number of nodes that would be requested for an experiment's regression runs" {
    case "${default_platform%%.*}" in
        ncrc? )
            num_nodes=2
            ;;
        theia )
            num_nodes=3
            ;;
        * )
            skip "--nodes not supported on site '${FRE_SYSTEM_SITE}'"
    esac

    output_good="CM2.1U_Control-1990_E1.M_3B_snowmelt regression/basic would request $num_nodes nodes.
CM2.1U_Control-1990_E1.M_3B_snowmelt regression/restarts would request $num_nodes nodes.
CM2.1U_Control-1990_E1.M_3B_snowmelt INHERITS FROM CM2.1U_Control-1990_E1.M_3A"

    run frelist -p ${default_platform} -t prod,openmp -x CM2.1U.xml CM2.1U_Control-1990_E1.M_3B_snowmelt -r basic,restarts --nodes

    print_output_status_and_diff_expected
    [ "$output" = "$output_good" ]
    [ "$status" -eq 0 ]
}

@test "Get the number of nodes that would be requested for all production runs" {
    case "${default_platform%%.*}" in
        ncrc? )
            num_nodes=7
            ;;
        theia )
            num_nodes=3
            ;;
        * )
            skip "--nodes not supported on site '${FRE_SYSTEM_SITE}'"
    esac

    output_good="CM2.1U_Control-1990_E1.M_3A is not configured for production run
CM2.1U_Control-1990_E1.M_3A
CM2.1U_Control-1990_E1.M_3B_snowmelt production would request $num_nodes nodes.
CM2.1U_Control-1990_E1.M_3B_snowmelt INHERITS FROM CM2.1U_Control-1990_E1.M_3A
CM2.1U_Control-1990_E1.M_3B_snowmelt_static_ocn6x5 production would request $num_nodes nodes.
CM2.1U_Control-1990_E1.M_3B_snowmelt_static_ocn6x5 INHERITS FROM CM2.1U_Control-1990_E1.M_3B_snowmelt"

    run frelist -p ${default_platform} -t prod,openmp -x CM2.1U.xml --nodes
    print_output_status_and_diff_expected
    [ "$output" = "$output_good" ]
    [ "$status" -eq 0 ]
}

@test "Get the number of nodes that would be requested for regression suite" {
    case "${default_platform%%.*}" in
        ncrc? )
            output_good="CM2.1U_Control-1990_E1.M_3A regression/basic would request 2 nodes.
CM2.1U_Control-1990_E1.M_3A regression/restarts would request 2 nodes.
CM2.1U_Control-1990_E1.M_3A regression/scaling #1 would request 2 nodes.
CM2.1U_Control-1990_E1.M_3A regression/scaling #2 would request 2 nodes.
CM2.1U_Control-1990_E1.M_3A regression/scaling #3 would request 3 nodes.
CM2.1U_Control-1990_E1.M_3A regression/scaling #4 would request 6 nodes.
CM2.1U_Control-1990_E1.M_3A
CM2.1U_Control-1990_E1.M_3B_snowmelt regression/basic would request 2 nodes.
CM2.1U_Control-1990_E1.M_3B_snowmelt regression/restarts would request 2 nodes.
CM2.1U_Control-1990_E1.M_3B_snowmelt regression/scaling #1 would request 2 nodes.
CM2.1U_Control-1990_E1.M_3B_snowmelt regression/scaling #2 would request 2 nodes.
CM2.1U_Control-1990_E1.M_3B_snowmelt regression/scaling #3 would request 3 nodes.
CM2.1U_Control-1990_E1.M_3B_snowmelt regression/scaling #4 would request 6 nodes.
CM2.1U_Control-1990_E1.M_3B_snowmelt INHERITS FROM CM2.1U_Control-1990_E1.M_3A
CM2.1U_Control-1990_E1.M_3B_snowmelt_static_ocn6x5 regression/basic would request 2 nodes.
CM2.1U_Control-1990_E1.M_3B_snowmelt_static_ocn6x5 regression/restarts would request 2 nodes.
CM2.1U_Control-1990_E1.M_3B_snowmelt_static_ocn6x5 regression/scaling #1 would request 2 nodes.
CM2.1U_Control-1990_E1.M_3B_snowmelt_static_ocn6x5 regression/scaling #2 would request 3 nodes.
CM2.1U_Control-1990_E1.M_3B_snowmelt_static_ocn6x5 INHERITS FROM CM2.1U_Control-1990_E1.M_3B_snowmelt"
            ;;
        theia )
            output_good="CM2.1U_Control-1990_E1.M_3A regression/basic would request 1 nodes.
CM2.1U_Control-1990_E1.M_3A regression/restarts would request 1 nodes.
CM2.1U_Control-1990_E1.M_3A regression/scaling #1 would request 1 nodes.
CM2.1U_Control-1990_E1.M_3A regression/scaling #2 would request 1 nodes.
CM2.1U_Control-1990_E1.M_3A regression/scaling #3 would request 1 nodes.
CM2.1U_Control-1990_E1.M_3A regression/scaling #4 would request 2 nodes.
CM2.1U_Control-1990_E1.M_3A
CM2.1U_Control-1990_E1.M_3B_snowmelt regression/basic would request 3 nodes.
CM2.1U_Control-1990_E1.M_3B_snowmelt regression/restarts would request 3 nodes.
CM2.1U_Control-1990_E1.M_3B_snowmelt regression/scaling #1 would request 3 nodes.
CM2.1U_Control-1990_E1.M_3B_snowmelt regression/scaling #2 would request 3 nodes.
CM2.1U_Control-1990_E1.M_3B_snowmelt regression/scaling #3 would request 3 nodes.
CM2.1U_Control-1990_E1.M_3B_snowmelt regression/scaling #4 would request 3 nodes.
CM2.1U_Control-1990_E1.M_3B_snowmelt INHERITS FROM CM2.1U_Control-1990_E1.M_3A
CM2.1U_Control-1990_E1.M_3B_snowmelt_static_ocn6x5 regression/basic would request 3 nodes.
CM2.1U_Control-1990_E1.M_3B_snowmelt_static_ocn6x5 regression/restarts would request 3 nodes.
CM2.1U_Control-1990_E1.M_3B_snowmelt_static_ocn6x5 regression/scaling #1 would request 3 nodes.
CM2.1U_Control-1990_E1.M_3B_snowmelt_static_ocn6x5 regression/scaling #2 would request 3 nodes.
CM2.1U_Control-1990_E1.M_3B_snowmelt_static_ocn6x5 INHERITS FROM CM2.1U_Control-1990_E1.M_3B_snowmelt"
            ;;
        * )
            skip "--nodes not supported on site '${FRE_SYSTEM_SITE}'"
    esac

    run frelist -p ${default_platform} -t prod,openmp -x CM2.1U.xml -r suite --nodes
    print_output_status_and_diff_expected
    [ "$output" = "$output_good" ]
    [ "$status" -eq 0 ]
}

@test "Extract platform csh section --platform=gfdl.${default_platform/./-}" {
    output_good="
# Platform environment defaults from ${FRE_COMMANDS_HOME}/site/gfdl/env.defaults
source \$MODULESHOME/init/csh
module use -a /home/fms/local/modulefiles
module use /app/spack/v0.15/modulefiles/linux-rhel6-x86_64
module purge
module load fre/$FRE_COMMANDS_VERSION
module load git

setenv NC_BLKSZ 64K
set ncksopt = \"-a -h -F --header_pad 16384\"
set ncrcatopt = \"-h -O -t 2 --header_pad 16384\"

# Platform environment overrides from XML"

    sed -e "s/\(^ *<property *name=\"FRE_VERSION\" *value=\"\).*\(\"\)/\1${FRE_COMMANDS_VERSION}\2/" CM2.1U.xml > ${unique_string}-temp.xml
    run frelist -p gfdl.${default_platform/./-} -S -x ${unique_string}-temp.xml
    print_output_status_and_diff_expected
    [ "$status" -eq 0 ]
    string_matches_pattern "$output" "$output_good"
    rm -f ${unique_string}-temp.xml
}

@test "Accept regression option" {
    run frelist -r foo -x CM2.1U.xml -p ${default_platform}
    print_output_and_status
    [ "$status" -eq 0 ]
}

@test "Print namelist for regression basic, inherited experiment" {
    # This test requires the platform to be able to run, which gfdl cannot.  Skip on gfdl
    case ${FRE_SYSTEM_SITE} in
        gfdl )
            skip "Don't test frelist on Analysis"
            ;;
    esac

    run frelist -r basic -N -x CM2.1U.xml CM2.1U_Control-1990_E1.M_3B_snowmelt -p ${default_platform}
    print_output_and_status
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

    # This test requires the platform to be able to run, which gfdl cannot.  Skip on gfdl
    case ${FRE_SYSTEM_SITE} in
        gfdl )
            skip "Don't test frelist on Analysis"
            ;;
    esac

    run frelist -x CM2.1U.xml -p ${default_platform} -t openmp -r suite --postfix CM2.1U_Control-1990_E1.M_3A
    print_output_status_and_diff_expected
    [ "$status" -eq 0 ]
    [[ X"$(diff -b  <(printf '%s\n' "$output_good") <(printf '%s\n' "$output"))" = X ]]
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

    run frelist -p ${default_platform} -e 'input/fieldTable' -x CM2.1U.xml CM2.1U_Control-1990_E1.M_3A
    print_output_status_and_diff_expected
    [ "$status" -eq 0 ]
    [[ "$output_good" =~ "$output" ]]
}

@test "Test -Xml option" {
    run frelist -X -x CM2.1U.xml -p ${default_platform} CM2.1U_Control-1990_E1.M_3B_snowmelt_static_ocn6x5
    print_output_and_status
    [ "$status" -eq 0 ]
}

@test "Test inherit of external XML file" {
    output_good='
# Platform environment defaults from '"$FRE_COMMANDS_HOME"'/site/gfdl/env.defaults
source $MODULESHOME/init/csh
module use -a /home/fms/local/modulefiles
module use /app/spack/v0.15/modulefiles/linux-rhel6-x86_64
module purge
module load fre/bronx-12
module load git

setenv NC_BLKSZ 64K
set ncksopt = "-a -h -F --header_pad 16384"
set ncrcatopt = "-h -O -t 2 --header_pad 16384"

# Platform environment overrides from XML

           source $MODULESHOME/init/csh
           module purge
           module load fre/bronx-12

           module use -a /home/John.Krasting/local/modulefiles
           module load jpk-analysis/0.0.4
           #Some tricks to use the refineDiag and analysis scripts from a checkout of MOM6 at gfdl
           setenv FREVERSION fre/bronx-12
           setenv NBROOT /nbhome/'"$USER"'/fms/AM3/bronx-12/warsaw_201803/$(name)/gfdl.ncrc3-intel15-prod
           mkdir -p $NBROOT
           cd $NBROOT
           if ( -e mom6) then
           else
              git clone /home/fms/git/ocean/mom6
           endif

         '

    run frelist -R ${USER} -p gfdl.ncrc3-intel15 -S -x CM3Z.xml
    print_output_status_and_diff_expected
    [ "$status" -eq 0 ]
    [[ "$output_good" =~ "$output" ]]
}
