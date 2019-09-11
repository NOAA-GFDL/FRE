#!/usr/bin/env bats
# -*- mode: sh; eval: (sh-set-shell "sh"); -*-

# The output_good strings are configured with the exact number of spaces needed
# for the tests to pass.  DO NOT adjust unless needed, this includes removing
# whitespace.

load test_helpers

remote_site=ncrc3
default_platform=gfdl.${remote_site}-intel

setup() {
    unique_string="date$(date +%s)pid$$-temp"
    unique_xml_name="${unique_string}.xml"
    unique_string="FRE_tests-${unique_string}"
}

@test "frepp is in PATH" {
    run which frepp
    print_output_and_status
    [ "$status" -eq 0 ]
}

@test "frepp print help message" {
    run frepp -h
    print_output_and_status
    [ "$status" -eq 1 ]
}

@test "No XML listed on frepp command line and no rts.xml file" {
    output_good="ERROR: XML file does not exist: rts.xml"
    if [ -f rts.xml ]; then
        rm rts.xml
    fi

    run frepp CM2.1U_Control-1990_E1.M_3B_snowmelt
    print_output_status_and_diff_expected
    [ "$status" -eq 2 ]
    [ "$output" = "$output_good" ]
}

@test "No XML listed on frepp command line and rts.xml exists" {
    output_good="WARNING: You did not specify a model date
NOTE: adding '-c split'; frepp will do each component in a separate batch job
ERROR: Non-positive years are not supported.
ERROR: The date passed in via the '-t' option ('') is not a valid date."

    cp CM2.1U.xml rts.xml
    run frepp CM2.1U_Control-1990_E1.M_3B_snowmelt
    print_output_status_and_diff_expected
    [ "$status" -eq 1 ]
    [ "$output" = "$output_good" ]
    rm rts.xml
}

@test "Invalid date specified" {
    output_good="NOTE: adding '-c split'; frepp will do each component in a separate batch job
ERROR: Non-positive years are not supported.
ERROR: The date passed in via the '-t' option ('invalid.date') is not a valid date."

    run frepp -x CM2.1U.xml CM2.1U_Control-1990_E1.M_3B_snowmelt -t invalid.date
    print_output_status_and_diff_expected
    [ "$status" -eq 1 ]
    [ "$output" = "$output_good" ]
}

@test "No platform specified" {
    output_good="NOTE: adding '-c split'; frepp will do each component in a separate batch job
*FATAL*: Default platforms are no longer supported.
Define platforms in experiment XML and use with -p|--platform site.compiler (e.g. -p ncrc3.intel15).
At GFDL, use -p gfdl.<remote_site>-<compiler> (e.g. gfdl.ncrc3-intel15).
See documentation at http://wiki.gfdl.noaa.gov/index.php/FRE_User_Documentation#Platforms_and_Sites."

    run frepp -x CM2.1U.xml CM2.1U_Control-1990_E1.M_3B_snowmelt -t 1
    print_output_status_and_diff_expected
    [ "$status" -eq 12 ]
    [ "$output" = "$output_good" ]
}

@test "Generate frepp scripts when date out of range" {
    # 9/10/2019 chris skipping this for now. the formatting is slightly different
    skip
    case "$FRE_SYSTEM_SITE" in
        gfdl )
            output_good="NOTE: adding '-c split'; frepp will do each component in a separate batch job
NOTE: No calculations necessary for year 99990101 for atmos.

NOTE: No calculations necessary for year 99990101 for ocean.

NOTE: No calculations necessary for year 99990101 for land.

NOTE: No calculations necessary for year 99990101 for ice.

WARNING: The simulation time calculated from the basedate in your diag_table (101,1,1,0,0,0) and the simulation length from the xml (20 years) ends before this year of postprocessing (99990101).
WARNING: The simulation time calculated from the basedate in your diag_table (101,1,1,0,0,0) and the simulation length from the xml (20 years) ends before this year of postprocessing (99990101).
WARNING: The simulation time calculated from the basedate in your diag_table (101,1,1,0,0,0) and the simulation length from the xml (20 years) ends before this year of postprocessing (99990101).
WARNING: The simulation time calculated from the basedate in your diag_table (101,1,1,0,0,0) and the simulation length from the xml (20 years) ends before this year of postprocessing (99990101)."
            exit_status=0
            ;;
        * )
            output_good="NOTE: adding '-c split'; frepp will do each component in a separate batch job
*FATAL*: You are not allowed to run the 'frepp' tool with the '${default_platform}' platform on this site"
            exit_status=1
    esac

    run frepp -x CM2.1U.xml CM2.1U_Control-1990_E1.M_3B_snowmelt -t 9999 -p $default_platform
    print_output_status_and_diff_expected
    [ "$status" -eq "$exit_status" ]
    [ "$output" = "$output_good" ]
}

@test "Generate frepp scripts when no history data exists" {
    case "$FRE_SYSTEM_SITE" in
        gfdl )
            output_good="NOTE: adding '-c split'; frepp will do each component in a separate batch job
ERROR: No history data found for year 0101 in /work/$USER/$unique_string/.*/CM2.1U_Control-1990_E1.M_3B_snowmelt/${default_platform}-prod/archive/history"
            ;;
        * )
            output_good="NOTE: adding '-c split'; frepp will do each component in a separate batch job
\*FATAL\*: You are not allowed to run the 'frepp' tool with the '${default_platform}' platform on this site"
    esac

    platform=gfdl \
    default_platform=gfdl.all \
    unique_dir_xml CM2.1U.xml >"$unique_xml_name"

    run frepp -x "$unique_xml_name" CM2.1U_Control-1990_E1.M_3B_snowmelt -t 105 -p $default_platform
    print_output_status_and_diff_expected
    [ "$status" -eq 1 ]
    string_matches_pattern "$output" "$output_good"
    rm "$unique_xml_name"
}

@test "Generate frepp scripts" {
    case "$FRE_SYSTEM_SITE" in
        gfdl )
            output_good="NOTE: adding '-c split'; frepp will do each component in a separate batch job

TO SUBMIT: sbatch  /work/$USER/$unique_string/.*/CM2.1U_Control-1990_E1.M_3B_snowmelt/${default_platform}-prod/scripts/postProcess/CM2.1U_Control-1990_E1.M_3B_snowmelt_atmos_01050101

TO SUBMIT: sbatch  /work/$USER/$unique_string/.*/CM2.1U_Control-1990_E1.M_3B_snowmelt/${default_platform}-prod/scripts/postProcess/CM2.1U_Control-1990_E1.M_3B_snowmelt_ocean_01050101

TO SUBMIT: sbatch  /work/$USER/$unique_string/.*/CM2.1U_Control-1990_E1.M_3B_snowmelt/${default_platform}-prod/scripts/postProcess/CM2.1U_Control-1990_E1.M_3B_snowmelt_land_01050101

TO SUBMIT: sbatch  /work/$USER/$unique_string/.*/CM2.1U_Control-1990_E1.M_3B_snowmelt/${default_platform}-prod/scripts/postProcess/CM2.1U_Control-1990_E1.M_3B_snowmelt_ice_01050101"
            exit_status=0
            ;;
        * )
            output_good="NOTE: adding '-c split'; frepp will do each component in a separate batch job
\*FATAL\*: You are not allowed to run the 'frepp' tool with the '${default_platform}' platform on this site"
            exit_status=1
    esac

    platform=gfdl \
    default_platform=gfdl.all \
    unique_dir_xml CM2.1U.xml >"$unique_xml_name"

    archdir=$(frelist -x "$unique_xml_name" -p $default_platform CM2.1U_Control-1990_E1.M_3B_snowmelt -d archive)/history
    mkdir -p $archdir && touch $archdir/010{1,2,3,4,5}0101.nc.tar
    run frepp -x "$unique_xml_name" CM2.1U_Control-1990_E1.M_3B_snowmelt -t 105 -p $default_platform
    print_output_status_and_diff_expected
    [ "$status" -eq "$exit_status" ]
    string_matches_pattern "$output" "$output_good"
    rm "$unique_xml_name"
}

@test "Generate frepp scripts with --target=prod,openmp" {
    case "$FRE_SYSTEM_SITE" in
        gfdl )
            output_good="NOTE: adding '-c split'; frepp will do each component in a separate batch job

TO SUBMIT: sbatch  /work/$USER/$unique_string/.*/CM2.1U_Control-1990_E1.M_3B_snowmelt/${default_platform}-prod-openmp/scripts/postProcess/CM2.1U_Control-1990_E1.M_3B_snowmelt_atmos_01050101

TO SUBMIT: sbatch  /work/$USER/$unique_string/.*/CM2.1U_Control-1990_E1.M_3B_snowmelt/${default_platform}-prod-openmp/scripts/postProcess/CM2.1U_Control-1990_E1.M_3B_snowmelt_ocean_01050101

TO SUBMIT: sbatch  /work/$USER/$unique_string/.*/CM2.1U_Control-1990_E1.M_3B_snowmelt/${default_platform}-prod-openmp/scripts/postProcess/CM2.1U_Control-1990_E1.M_3B_snowmelt_land_01050101

TO SUBMIT: sbatch  /work/$USER/$unique_string/.*/CM2.1U_Control-1990_E1.M_3B_snowmelt/${default_platform}-prod-openmp/scripts/postProcess/CM2.1U_Control-1990_E1.M_3B_snowmelt_ice_01050101"
            exit_status=0
            ;;
        * )
            output_good="NOTE: adding '-c split'; frepp will do each component in a separate batch job
\*FATAL\*: You are not allowed to run the 'frepp' tool with the '${default_platform}' platform on this site"
            exit_status=1
    esac

    platform=gfdl \
    default_platform=gfdl.all \
    unique_dir_xml CM2.1U.xml >"$unique_xml_name"

    target=prod,openmp
    archdir=$(frelist -x "$unique_xml_name" -p $default_platform -t $target CM2.1U_Control-1990_E1.M_3B_snowmelt -d archive)/history
    mkdir -p $archdir && touch $archdir/010{1,2,3,4,5}0101.nc.tar
    run frepp -x "$unique_xml_name" CM2.1U_Control-1990_E1.M_3B_snowmelt -t 105 -p $default_platform -T $target
    print_output_status_and_diff_expected
    [ "$status" -eq "$exit_status" ]
    string_matches_pattern "$output" "$output_good"
    rm "$unique_xml_name"
}

@test "Generate frepp script and verify default email address" {
    case "$FRE_SYSTEM_SITE" in
        gfdl )
            ;;
        * )
            skip "No test for current platform"
            ;;
    esac

    platform=gfdl \
    default_platform=gfdl.all \
    unique_dir_xml CM2.1U.xml >"$unique_xml_name"

    target=prod,openmp
    archdir=$(frelist -x "$unique_xml_name" -p $default_platform -t $target CM2.1U_Control-1990_E1.M_3B_snowmelt -d archive)/history
    mkdir -p $archdir && touch $archdir/010{1,2,3,4,5}0101.nc.tar
    run frepp -x "$unique_xml_name" CM2.1U_Control-1990_E1.M_3B_snowmelt -t 105 -p $default_platform -T $target -c atmos
    [ "$status" -eq 0 ]

    script="/work/$USER/$unique_string/*/CM2.1U_Control-1990_E1.M_3B_snowmelt/${default_platform}-prod-openmp/scripts/postProcess/CM2.1U_Control-1990_E1.M_3B_snowmelt_atmos_01050101"
    grep "SBATCH --mail-user=$USER@noaa.gov" $script
    [ "$status" -eq 0 ]
    rm "$unique_xml_name"
}

@test "Generate frepp script and verify error on bad email address" {
    case "$FRE_SYSTEM_SITE" in
        gfdl )
            ;;
        * )
            skip "No test for current platform"
            ;;
    esac

    platform=gfdl \
    default_platform=gfdl.all \
    unique_dir_xml CM2.1U.xml >"$unique_xml_name"

    target=prod,openmp
    archdir=$(frelist -x "$unique_xml_name" -p $default_platform -t $target CM2.1U_Control-1990_E1.M_3B_snowmelt -d archive)/history
    mkdir -p $archdir && touch $archdir/010{1,2,3,4,5}0101.nc.tar
    run frepp -x "$unique_xml_name" CM2.1U_Control-1990_E1.M_3B_snowmelt -t 105 -p $default_platform -T $target -c atmos --mail-list=bad.email
    [ "$status" -eq 255 ]
}

@test "Generate frepp script and verify custom email addresses" {
    case "$FRE_SYSTEM_SITE" in
        gfdl )
            ;;
        * )
            skip "No test for current platform"
            ;;
    esac

    platform=gfdl \
    default_platform=gfdl.all \
    unique_dir_xml CM2.1U.xml >"$unique_xml_name"

    target=prod,openmp
    archdir=$(frelist -x "$unique_xml_name" -p $default_platform -t $target CM2.1U_Control-1990_E1.M_3B_snowmelt -d archive)/history
    mkdir -p $archdir && touch $archdir/010{1,2,3,4,5}0101.nc.tar
    run frepp -x "$unique_xml_name" CM2.1U_Control-1990_E1.M_3B_snowmelt -t 105 -p $default_platform -T $target -c atmos --mail-list=title@yahoo.com,department@gmail.com,foo@noaa.gov
    [ "$status" -eq 0 ]

    script="/work/$USER/$unique_string/*/CM2.1U_Control-1990_E1.M_3B_snowmelt/${default_platform}-prod-openmp/scripts/postProcess/CM2.1U_Control-1990_E1.M_3B_snowmelt_atmos_01050101"
    grep "SBATCH --mail-user=title@yahoo.com,department@gmail.com,foo@noaa.gov" $script
    [ "$status" -eq 0 ]
    rm "$unique_xml_name"
}
