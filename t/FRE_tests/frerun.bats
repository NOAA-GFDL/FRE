#!/usr/bin/env bats
# -*- mode: sh; eval: (sh-set-shell "sh"); -*-

# The output_good strings are configured with the exact number of spaces needed
# for the tests to pass.  DO NOT adjust unless needed, this includes removing
# whitespace.

load test_helpers

setup() {
    unique_string="date$(date +%s)pid$$"
}

add_submit_cmd_to_last_line_good() {
    if [ -n "${submit_cmd}" ]; then
        last_line_good="TO SUBMIT => ${submit_cmd} ${last_line_good}"
    else
        last_line_good="The runscript '${last_line_good}' is ready"
    fi
}

@test "frerun is in PATH" {
    run which frerun
    print_output_and_status
    [ "$status" -eq 0 ]
}

@test "frerun print help message" {
    run frerun -h
    print_output_and_status
    [ "$status" -eq 0 ]
}

@test "frerun print version" {
    run frerun -V
    print_output_and_status
    [ "$status" -eq 0 ]
}

@test "No experiment listed on frerun command line and no rts.xml file" {
    case $( hostname ) in
        an??? )
            skip "Don't test frerun on Analysis"
            ;;
        * )
            output_good="*FATAL*: At least one experiment name is needed on the command line
         Try 'frerun --help' for more information"
            ;;
    esac

    run frerun
    print_output_status_and_diff_expected
    [ "$status" -eq 11 ]
    [ "$output" = "$output_good" ]
}

@test "Experiment listed on frerun command line and no rts.xml file" {
    case $( hostname ) in
        an??? )
            skip "Don't test frerun on Analysis"
            ;;
        * )
            output_good="*FATAL*: The XML file '`pwd -P`/rts.xml' doesn't exist or isn't readable"
            ;;
    esac

    rm -f rts.xml
    run frerun -p ${default_platform} CM2.1U_Control-1990_E1.M_3A
    print_output_status_and_diff_expected
    [ "$status" -eq 30 ]
    [ "$output" = "$output_good" ]
}

@test "Create run script when experiment listed on frerun command line, and rts.xml exists" {
    case "${default_platform%%.*}" in
        ncrc? )
            platform="ncrc"
            root_stem="/lustre/f2/scratch"
            submit_cmd="sleep 1; sbatch"
            ;;
        theia ) platform="theia"
            root_stem="/scratch4/GFDL/gfdlscr"
            submit_cmd="qsub"
            ;;
        gfdl-ws )
            platform="gfdl-ws"
            root_stem="/local2/tmp"
            submit_cmd=""
            ;;
        * )
            skip "No test for current platform"
            ;;
    esac

    last_line_good="${root_stem}/${USER}/FRE_tests-${unique_string}-temp/.*/CM2.1U_Control-1990_E1.M_3B_snowmelt/${default_platform}-prod/scripts/run/CM2.1U_Control-1990_E1.M_3B_snowmelt"
    add_submit_cmd_to_last_line_good

    unique_stdout_xml CM2.1U.xml >rts.xml
    run frerun -p ${default_platform} CM2.1U_Control-1990_E1.M_3B_snowmelt
    remove_ninac_from_output_and_lines

    # Get the last line from the output
    num_lines=${#lines[@]}
    last_line="${lines[$((${num_lines}-1))]}"

    print_output_status_and_diff_expected_long "$last_line" "$last_line_good"
    [ "$status" -eq 0 ]
    string_matches_pattern "$last_line" "$last_line_good"
    rm -rf "${root_stem}/${USER}/FRE_tests-${unique_string}-temp"
    rm rts.xml
}

@test "XML listed on frerun command line but XML file doesn't exist" {
    case $( hostname ) in
        an??? )
            skip "Don't test frerun on Analysis"
            ;;
        * )
    # NOTE: I am using the $USER environment variable so we don't have to glob and escape the * in *FATAL*
            output_good="*FATAL*: The XML file '`pwd -P`/nonexistent_file.xml' doesn't exist or isn't readable"
            ;;
    esac

    [ ! -f nonexistent_file.xml ] # Assert file doesn't exist
    run frerun -x nonexistent_file.xml -p ${default_platform} CM2.1U_Control-1990_E1.M_3A
    print_output_status_and_diff_expected
    [ "$status" -eq 30 ]
    [ "$output" = "$output_good" ]
}

@test "Create run script when XML listed on frerun command line and XML file exists" {
    case "${default_platform%%.*}" in
        ncrc? )
            platform="ncrc"
            root_stem="/lustre/f2/scratch"
            submit_cmd="sleep 1; sbatch"
            ;;
        theia )
            platform="theia"
            root_stem="/scratch4/GFDL/gfdlscr"
            submit_cmd="qsub"
            ;;
        gfdl-ws )
            platform="gfdl-ws"
            root_stem="/local2/tmp"
            submit_cmd=""
            ;;
        * )
            skip "No test for current platform"
            ;;
    esac

    last_line_good="${root_stem}/${USER}/FRE_tests-${unique_string}-temp/.*/CM2.1U_Control-1990_E1.M_3B_snowmelt/${default_platform}-prod/scripts/run/CM2.1U_Control-1990_E1.M_3B_snowmelt"
    add_submit_cmd_to_last_line_good

    unique_stdout_xml CM2.1U.xml >"${unique_string}-temp.xml"
    run frerun -x "${unique_string}-temp.xml" -p ${default_platform} CM2.1U_Control-1990_E1.M_3B_snowmelt
    remove_ninac_from_output_and_lines

    # Get the last line from the output
    num_lines=${#lines[@]}
    last_line="${lines[$((num_lines-1))]}"

    print_output_status_and_diff_expected_long "$last_line" "$last_line_good"
    [ "$status" -eq 0 ]
    string_matches_pattern "$last_line" "$last_line_good"
    rm -rf "${root_stem}/${USER}/FRE_tests-${unique_string}-temp"
    rm "${unique_string}-temp.xml"
}

@test "Specify nonexistent platform" {
    # NOTE: I am using the $USER environment variable so we don't have to glob and escape the * in *FATAL*
    output_good="*FATAL*: The --platform option value 'nonexistent_platform.intel' is not valid"

    run frerun -x CM2.1U.xml -p nonexistent_platform.intel CM2.1U_Control-1990_E1.M_3B_snowmelt
    print_output_status_and_diff_expected
    [ "$status" -eq 30 ]
    [ "$output" = "$output_good" ]
}

@test "Create run script when --platform=${default_platform}" {
    case "${default_platform%%.*}" in
        ncrc? )
            platform="ncrc"
            root_stem="/lustre/f2/scratch"
            submit_cmd="sleep 1; sbatch"
            ;;
        theia )
            platform="theia"
            root_stem="/scratch4/GFDL/gfdlscr"
            submit_cmd="qsub"
            ;;
        gfdl-ws )
            platform="gfdl-ws"
            root_stem="/local2/tmp"
            submit_cmd=""
            ;;
        * )
            skip "No test for current platform"
            ;;
    esac

    last_line_good="${root_stem}/${USER}/FRE_tests-${unique_string}-temp/.*/CM2.1U_Control-1990_E1.M_3B_snowmelt/${default_platform}-prod/scripts/run/CM2.1U_Control-1990_E1.M_3B_snowmelt"
    add_submit_cmd_to_last_line_good

    unique_stdout_xml CM2.1U.xml >"${unique_string}-temp.xml"
    run frerun -x "${unique_string}-temp.xml" -p ${default_platform} CM2.1U_Control-1990_E1.M_3B_snowmelt
    remove_ninac_from_output_and_lines

    # Get the last line from the output
    num_lines=${#lines[@]}
    last_line="${lines[$((num_lines-1))]}"

    print_output_status_and_diff_expected_long "$last_line" "$last_line_good"
    [ "$status" -eq 0 ]
    string_matches_pattern "$last_line" "$last_line_good"
    rm -rf "${root_stem}/${USER}/FRE_tests-${unique_string}-temp"
    rm "${unique_string}-temp.xml"
}

@test "Create run script when --target=prod" {
    case "${default_platform%%.*}" in
        ncrc? )
            platform="ncrc"
            root_stem="/lustre/f2/scratch"
            submit_cmd="sleep 1; sbatch"
            ;;
        theia )
            platform="theia"
            root_stem="/scratch4/GFDL/gfdlscr"
            submit_cmd="qsub"
            ;;
        gfdl-ws )
            platform="gfdl-ws"
            root_stem="/local2/tmp"
            submit_cmd=""
            ;;
        * )
            skip "No test for current platform"
            ;;
    esac

    last_line_good="${root_stem}/${USER}/FRE_tests-${unique_string}-temp/.*/CM2.1U_Control-1990_E1.M_3B_snowmelt/${default_platform}-prod/scripts/run/CM2.1U_Control-1990_E1.M_3B_snowmelt"
    add_submit_cmd_to_last_line_good

    unique_stdout_xml CM2.1U.xml >"${unique_string}-temp.xml"
    run frerun -x "${unique_string}-temp.xml" -p ${default_platform} -t prod CM2.1U_Control-1990_E1.M_3B_snowmelt
    remove_ninac_from_output_and_lines

    # Get the last line from the output
    num_lines=${#lines[@]}
    last_line="${lines[$((num_lines-1))]}"

    print_output_status_and_diff_expected_long "$last_line" "$last_line_good"
    [ "$status" -eq 0 ]
    string_matches_pattern "$last_line" "$last_line_good"
    rm -rf "${root_stem}/${USER}/FRE_tests-${unique_string}-temp"
    rm "${unique_string}-temp.xml"
}

@test "State directory exists but --extend, --overwrite, or --unique not specified" {
    case "${default_platform%%.*}" in
        ncrc? )
            platform="ncrc"
            root_stem="/lustre/f2/scratch"
            submit_cmd="sleep 1; sbatch"
            ;;
        theia )
            platform="theia"
            root_stem="/scratch4/GFDL/gfdlscr"
            submit_cmd="qsub"
            ;;
        gfdl-ws )
            platform="gfdl-ws"
            root_stem="/local2/tmp"
            submit_cmd=""
            ;;
        * )
            skip "No test for current platform"
            ;;
    esac

    xml="${unique_string}-temp.xml"
    unique_stdout_xml CM2.1U.xml >$xml
    freopts="-p ${default_platform} -t prod -x $xml CM2.1U_Control-1990_E1.M_3B_snowmelt"
    release=$(frelist $freopts -d root | rev | cut -d / -f 1 | rev)

    last_3_lines_good="*FATAL*: The state directory '${root_stem}/${USER}/FRE_tests-${unique_string}-temp/$release/CM2.1U_Control-1990_E1.M_3B_snowmelt/${default_platform}-prod/state/run' exists, so you must specify --extend, --overwrite or --unique
*FATAL*: Unable to setup output directories for the experiment 'CM2.1U_Control-1990_E1.M_3B_snowmelt'
*FATAL*: Unable to create a runscript for the experiment 'CM2.1U_Control-1990_E1.M_3B_snowmelt'"

    mkdir -p "$(frelist $freopts -d state)/run"
    run frerun $freopts
    remove_ninac_from_output_and_lines

    # Get the last 3 lines of output (i.e. only the *FATAL* errors)
    num_lines=${#lines[@]}
    if [ $num_lines -lt 3 ]; then
        last_3_lines="$output"
    else
        last_3_lines="${lines[$((num_lines-3))]}"
        last_3_lines="${last_3_lines}
${lines[$((num_lines-2))]}"
        last_3_lines="${last_3_lines}
${lines[$((num_lines-1))]}"
    fi

    print_output_status_and_diff_expected_long "$last_3_lines" "$last_3_lines_good"
    [ "$status" -eq 60 ]
    [ "$last_3_lines" = "$last_3_lines_good" ]
    rm -rf "${root_stem}/${USER}/FRE_tests-${unique_string}-temp"
    rm "${unique_string}-temp.xml"
}

@test "Create run script when state directory exists and --overwrite is specified" {
    case "${default_platform%%.*}" in
        ncrc? )
            platform="ncrc"
            root_stem="/lustre/f2/scratch"
            submit_cmd="sleep 1; sbatch"
            ;;
        theia )
            platform="theia"
            root_stem="/scratch4/GFDL/gfdlscr"
            submit_cmd="qsub"
            ;;
        gfdl-ws )
            platform="gfdl-ws"
            root_stem="/local2/tmp"
            submit_cmd=""
            ;;
        * )
            skip "No test for current platform"
            ;;
    esac

    xml="${unique_string}-temp.xml"
    unique_stdout_xml CM2.1U.xml >$xml
    freopts="-p ${default_platform} -t prod -x $xml CM2.1U_Control-1990_E1.M_3B_snowmelt"
    release=$(frelist $freopts -d root | rev | cut -d / -f 1 | rev)

    last_line_good="${root_stem}/${USER}/FRE_tests-${unique_string}-temp/$release/CM2.1U_Control-1990_E1.M_3B_snowmelt/${default_platform}-prod/scripts/run/CM2.1U_Control-1990_E1.M_3B_snowmelt"
    add_submit_cmd_to_last_line_good

    mkdir -p "$(frelist $freopts -d state)/run"
    run frerun $freopts -o --no-dual
    remove_ninac_from_output_and_lines

    # Get the last line from the output
    num_lines=${#lines[@]}
    last_line="${lines[$((num_lines-1))]}"

    print_output_status_and_diff_expected_long "$last_line" "$last_line_good"
    [ "$status" -eq 0 ]
    [ "$last_line" = "$last_line_good" ]
    rm -rf "${root_stem}/${USER}/FRE_tests-${unique_string}-temp"
    rm "${unique_string}-temp.xml"
}

@test "Create run script when state directory exists and --unique is specified" {
    case "${default_platform%%.*}" in
        ncrc? )
            platform="ncrc"
            root_stem="/lustre/f2/scratch"
            submit_cmd="sleep 1; sbatch"
            ;;
        theia )
            platform="theia"
            root_stem="/scratch4/GFDL/gfdlscr"
            submit_cmd="qsub"
            ;;
        gfdl-ws )
            platform="gfdl-ws"
            root_stem="/local2/tmp"
            submit_cmd=""
            ;;
        * )
            skip "No test for current platform"
            ;;
    esac

    xml="${unique_string}-temp.xml"
    unique_stdout_xml CM2.1U.xml >$xml
    freopts="-p ${default_platform} -t prod -x $xml CM2.1U_Control-1990_E1.M_3B_snowmelt"
    release=$(frelist $freopts -d root | rev | cut -d / -f 1 | rev)

    last_line_good="${root_stem}/${USER}/FRE_tests-${unique_string}-temp/$release/CM2.1U_Control-1990_E1.M_3B_snowmelt/${default_platform}-prod/scripts/run/CM2.1U_Control-1990_E1.M_3B_snowmelt__1"
    add_submit_cmd_to_last_line_good

    mkdir -p "$(frelist $freopts -d state)/run"
    run frerun $freopts -u
    remove_ninac_from_output_and_lines

    # Get the last line from the output
    num_lines=${#lines[@]}
    last_line="${lines[$((num_lines-1))]}"

    print_output_status_and_diff_expected_long "$last_line" "$last_line_good"
    [ "$status" -eq 0 ]
    [ "$last_line" = "$last_line_good" ]
    rm -rf "${root_stem}/${USER}/FRE_tests-${unique_string}-temp"
    rm "${unique_string}-temp.xml"
}

@test "Create run script when state directory exists and --extend is specified" {
    case "${default_platform%%.*}" in
        ncrc? )
            platform="ncrc"
            root_stem="/lustre/f2/scratch"
            submit_cmd="sleep 1; sbatch"
            ;;
        theia )
            platform="theia"
            root_stem="/scratch4/GFDL/gfdlscr"
            submit_cmd="qsub"
            ;;
        gfdl-ws )
            platform="gfdl-ws"
            root_stem="/local2/tmp"
            submit_cmd=""
            ;;
        * )
            skip "No test for current platform"
            ;;
    esac

    xml="${unique_string}-temp.xml"
    unique_stdout_xml CM2.1U.xml >$xml
    freopts="-p ${default_platform} -t prod -x $xml CM2.1U_Control-1990_E1.M_3B_snowmelt"
    release=$(frelist $freopts -d root | rev | cut -d / -f 1 | rev)

    last_line_good="${root_stem}/${USER}/FRE_tests-${unique_string}-temp/$release/CM2.1U_Control-1990_E1.M_3B_snowmelt/${default_platform}-prod/scripts/run/CM2.1U_Control-1990_E1.M_3B_snowmelt"
    add_submit_cmd_to_last_line_good

    mkdir -p "$(frelist $freopts -d state)/run"
    run frerun $freopts -e
    remove_ninac_from_output_and_lines

    # Get the last line from the output
    num_lines=${#lines[@]}
    last_line="${lines[$((num_lines-1))]}"

    print_output_status_and_diff_expected_long "$last_line" "$last_line_good"
    [ "$status" -eq 0 ]
    string_matches_pattern "$last_line" "$last_line_good"
    rm -rf "${root_stem}/${USER}/FRE_tests-${unique_string}-temp"
    rm "${unique_string}-temp.xml"
}

@test "Create run script and verify default mail target" {
    case "${default_platform%%.*}" in
        ncrc? )
            platform="ncrc"
            root_stem="/lustre/f2/scratch"
            submit_cmd="sleep 1; sbatch"
            ;;
        theia ) platform="theia"
            root_stem="/scratch4/GFDL/gfdlscr"
            submit_cmd="qsub"
            ;;
        * )
            skip "No test for current platform"
            ;;
    esac


    unique_stdout_xml CM2.1U.xml >rts.xml
    run frerun -p ${default_platform} CM2.1U_Control-1990_E1.M_3B_snowmelt

    script="${root_stem}/${USER}/FRE_tests-${unique_string}-temp/*/CM2.1U_Control-1990_E1.M_3B_snowmelt/${default_platform}-prod/scripts/run/CM2.1U_Control-1990_E1.M_3B_snowmelt"
    grep "SBATCH --mail-user=$USER@noaa.gov" $script
    [ "$status" -eq 0 ]

    rm -rf "${root_stem}/${USER}/FRE_tests-${unique_string}-temp"
    rm rts.xml
}

@test "Verify frerun error when using --mail-list with invalid email address" {
    case "${default_platform%%.*}" in
        ncrc? )
            platform="ncrc"
            root_stem="/lustre/f2/scratch"
            submit_cmd="sleep 1; sbatch"
            ;;
        theia ) platform="theia"
            root_stem="/scratch4/GFDL/gfdlscr"
            submit_cmd="qsub"
            ;;
        gfdl-ws )
            platform="gfdl-ws"
            root_stem="/local2/tmp"
            submit_cmd=""
            ;;
        * )
            skip "No test for current platform"
            ;;
    esac


    unique_stdout_xml CM2.1U.xml >rts.xml
    run frerun -p ${default_platform} CM2.1U_Control-1990_E1.M_3B_snowmelt --mail-list ok@noaa.gov,not-real@yahoo
    [ "$status" -eq 10 ]

    rm -rf "${root_stem}/${USER}/FRE_tests-${unique_string}-temp"
    rm rts.xml
}

@test "Create run script and verify user-specified email" {
    case "${default_platform%%.*}" in
        ncrc? )
            platform="ncrc"
            root_stem="/lustre/f2/scratch"
            submit_cmd="sleep 1; sbatch"
            ;;
        theia ) platform="theia"
            root_stem="/scratch4/GFDL/gfdlscr"
            submit_cmd="qsub"
            ;;
        * )
            skip "No test for current platform"
            ;;
    esac


    unique_stdout_xml CM2.1U.xml >rts.xml
    run frerun -p ${default_platform} CM2.1U_Control-1990_E1.M_3B_snowmelt --mail-list one@two.com

    script="${root_stem}/${USER}/FRE_tests-${unique_string}-temp/*/CM2.1U_Control-1990_E1.M_3B_snowmelt/${default_platform}-prod/scripts/run/CM2.1U_Control-1990_E1.M_3B_snowmelt"
    grep "SBATCH --mail-user=one@two.com" $script
    [ "$status" -eq 0 ]

    rm -rf "${root_stem}/${USER}/FRE_tests-${unique_string}-temp"
    rm rts.xml
}

@test "Create run script and verify three user-specified emails" {
    case "${default_platform%%.*}" in
        ncrc? )
            platform="ncrc"
            root_stem="/lustre/f2/scratch"
            submit_cmd="sleep 1; sbatch"
            ;;
        theia ) platform="theia"
            root_stem="/scratch4/GFDL/gfdlscr"
            submit_cmd="qsub"
            ;;
        * )
            skip "No test for current platform"
            ;;
    esac


    unique_stdout_xml CM2.1U.xml >rts.xml
    run frerun -p ${default_platform} CM2.1U_Control-1990_E1.M_3B_snowmelt --mail-list one@two.com,foo@bar.edu,blue_green@algae.com

    script="${root_stem}/${USER}/FRE_tests-${unique_string}-temp/*/CM2.1U_Control-1990_E1.M_3B_snowmelt/${default_platform}-prod/scripts/run/CM2.1U_Control-1990_E1.M_3B_snowmelt"
    grep "SBATCH --mail-user=one@two.com,foo@bar.edu,blue_green@algae.com" $script
    [ "$status" -eq 0 ]

    rm -rf "${root_stem}/${USER}/FRE_tests-${unique_string}-temp"
    rm rts.xml
}
