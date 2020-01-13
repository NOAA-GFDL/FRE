#!/usr/bin/env bats
# -*- mode: sh; eval: (sh-set-shell "sh"); -*-

# The output_good strings are configured with the exact number of spaces needed
# for the tests to pass.  DO NOT adjust unless needed, this includes removing
# whitespace.

load test_helpers

setup() {
    unique_string="date$(date +%s)pid$$"
}

@test "fremake is in PATH" {
    run which fremake
    print_output_and_status
    [ "$status" -eq 0 ]
}

@test "fremake print help message" {
    run fremake -h
    print_output_and_status
    [ "$status" -eq 0 ]
}

@test "fremake print version" {
    run fremake -V
    print_output_and_status
    [ "$status" -eq 0 ]
}

@test "No experiment listed on fremake command line and no rts.xml file" {
    case "${default_platform%%.*}" in
        an??? )
            skip "Don't test fremake on Analysis"
            ;;
        * )
            output_good="*FATAL*: At least one experiment name is needed on the command line
         Try 'fremake --help' for more information"
            ;;
    esac

    run fremake
    print_output_status_and_diff_expected
    [ "$status" -eq 11 ]
    [ "$output" = "$output_good" ]
}

@test "Experiment listed on fremake command line and no rts.xml file" {
    case $( hostname ) in
        an??? )
            skip "Don't test fremake on Analysis"
            ;;
        * )
            output_good="*FATAL*: The XML file '`pwd -P`/rts.xml' doesn't exist or isn't readable"
            ;;
    esac

    rm -f rts.xml
    run fremake -p ${default_platform} CM2.1U_Control-1990_E1.M_3A
    print_output_status_and_diff_expected
    [ "$status" -eq 30 ]
    [ "$output" = "$output_good" ]
}

@test "Create compile script when experiment listed on fremake command line, and rts.xml exists" {
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

    last_line_good="${root_stem}/${USER}/FRE_tests-${unique_string}-temp/.*/CM2.1U_Control-1990_E1.M_3A/${default_platform}-prod/exec/compile_CM2.1U_Control-1990_E1.M_3A.csh"

    if [ -n "${submit_cmd}" ]; then
        last_line_good="TO SUBMIT => ${submit_cmd} ${last_line_good}"
    else
        last_line_good="The compile script '${last_line_good}' is ready"
    fi

    if [ -e rts.xml ]
    then
       rm -f rts.xml
    fi

    unique_stdout_xml CM2.1U.xml >rts.xml
    run fremake -p ${default_platform} CM2.1U_Control-1990_E1.M_3A

    # Get the last line from the output
    num_lines=${#lines[@]}
    last_line="${lines[$((num_lines-1))]}"

    print_output_status_and_diff_expected_long "$last_line" "$last_line_good"
    [ "$status" -eq 0 ]
    string_matches_pattern "$last_line" "$last_line_good"
    rm -rf "${root_stem}/${USER}/FRE_tests-${unique_string}-temp"
    rm rts.xml
}

@test "XML listed on fremake command line but XML file doesn't exist" {
    case $( hostname ) in
        an??? )
            skip "Don't test fremake on Analysis"
            ;;
        * )
            # NOTE: I am using the pwd command here so we don't have to glob and escape the * in *FATAL*
            output_good="*FATAL*: The XML file '`pwd -P`/nonexistent_file.xml' doesn't exist or isn't readable"
            ;;
    esac

    [ ! -f nonexistent_file.xml ] # Assert file doesn't exist
    run fremake -x nonexistent_file.xml -p ${default_platform} CM2.1U_Control-1990_E1.M_3A
    print_output_status_and_diff_expected
    [ "$status" -eq 30 ]
    [ "$output" = "$output_good" ]
}

@test "Create compile script when XML listed on fremake command line and XML file exists" {
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

    last_line_good="${root_stem}/${USER}/FRE_tests-${unique_string}-temp/.*/CM2.1U_Control-1990_E1.M_3A/${default_platform}-prod/exec/compile_CM2.1U_Control-1990_E1.M_3A.csh"
    # NOTE: used $USER above

    if [ -n "${submit_cmd}" ]; then
        last_line_good="TO SUBMIT => ${submit_cmd} ${last_line_good}"
    else
        last_line_good="The compile script '${last_line_good}' is ready"
    fi

    unique_stdout_xml CM2.1U.xml >"${unique_string}-temp.xml"
    run fremake -x "${unique_string}-temp.xml" -p ${default_platform} CM2.1U_Control-1990_E1.M_3A

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
    output_good="*FATAL*: The --platform option value 'nonexistent_platform.intel' is not valid"

    run fremake -x CM2.1U.xml -p nonexistent_platform.intel CM2.1U_Control-1990_E1.M_3A
    print_output_status_and_diff_expected
    [ "$status" -eq 30 ]
    [ "$output" = "$output_good" ]
}

@test "Create compile script when --platform=${default_platform}" {
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

    last_line_good="${root_stem}/${USER}/FRE_tests-${unique_string}-temp/.*/CM2.1U_Control-1990_E1.M_3A/${default_platform}-prod/exec/compile_CM2.1U_Control-1990_E1.M_3A.csh"

    if [ -n "${submit_cmd}" ]; then
        last_line_good="TO SUBMIT => ${submit_cmd} ${last_line_good}"
    else
        last_line_good="The compile script '${last_line_good}' is ready"
    fi

    unique_stdout_xml CM2.1U.xml >"${unique_string}-temp.xml"
    run fremake -x "${unique_string}-temp.xml" -p ${default_platform} CM2.1U_Control-1990_E1.M_3A

    # Get the last line from the output
    num_lines=${#lines[@]}
    last_line="${lines[$((num_lines-1))]}"

    print_output_status_and_diff_expected_long "$last_line" "$last_line_good"
    [ "$status" -eq 0 ]
    string_matches_pattern "$last_line" "$last_line_good"
    rm -rf "${root_stem}/${USER}/FRE_tests-${unique_string}-temp"
    rm "${unique_string}-temp.xml"
}

@test "Create compile script when --target=prod" {
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

    last_line_good="${root_stem}/${USER}/FRE_tests-${unique_string}-temp/.*/CM2.1U_Control-1990_E1.M_3A/${default_platform}-prod/exec/compile_CM2.1U_Control-1990_E1.M_3A.csh"

    if [ -n "${submit_cmd}" ]; then
        last_line_good="TO SUBMIT => ${submit_cmd} ${last_line_good}"
    else
        last_line_good="The compile script '${last_line_good}' is ready"
    fi

    unique_stdout_xml CM2.1U.xml >"${unique_string}-temp.xml"
    run fremake -x "${unique_string}-temp.xml" -p ${default_platform} -t prod CM2.1U_Control-1990_E1.M_3A

    # Get the last line from the output
    num_lines=${#lines[@]}
    last_line="${lines[$((num_lines-1))]}"

    print_output_status_and_diff_expected_long "$last_line" "$last_line_good"
    [ "$status" -eq 0 ]
    string_matches_pattern "$last_line" "$last_line_good"
    rm -rf "${root_stem}/${USER}/FRE_tests-${unique_string}-temp"
    rm "${unique_string}-temp.xml"
}

@test "Source and executable directories exist but --force-checkout and --force-compile not specified" {
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

    last_line_good="${root_stem}/${USER}/FRE_tests-${unique_string}-temp/.*/CM2.1U_Control-1990_E1.M_3A/${default_platform}-prod/exec/compile_CM2.1U_Control-1990_E1.M_3A.csh"

    if [ -n "${submit_cmd}" ]; then
        last_line_good="TO SUBMIT => ${submit_cmd} ${last_line_good}"
    else
        last_line_good="The compile script '${last_line_good}' is ready"
    fi

    output_good="WARNING: The checkout script '${root_stem}/${USER}/FRE_tests-${unique_string}-temp/.*/CM2.1U_Control-1990_E1.M_3A/src/checkout.csh' already exists and matches checkout instructions in the XML file, so checkout is skipped
WARNING: The compile script '${root_stem}/${USER}/FRE_tests-${unique_string}-temp/.*/CM2.1U_Control-1990_E1.M_3A/${default_platform}-prod/exec/compile_CM2.1U_Control-1990_E1.M_3A.csh' already exists and matches compile instructions in the XML file
${last_line_good}"

    unique_stdout_xml CM2.1U.xml >"${unique_string}-temp.xml"
    fremake -x "${unique_string}-temp.xml" -p ${default_platform} -t prod CM2.1U_Control-1990_E1.M_3A
    run fremake -x "${unique_string}-temp.xml" -p ${default_platform} -t prod CM2.1U_Control-1990_E1.M_3A
    remove_ninac_from_output_and_lines

    print_output_status_and_diff_expected
    [ "$status" -eq 0 ]
    string_matches_pattern "$output" "$output_good"
    rm -rf "${root_stem}/${USER}/FRE_tests-${unique_string}-temp"
    rm "${unique_string}-temp.xml"
}

@test "Create compile script when source directory exists and --force-checkout specified" {
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

    last_line_good="${root_stem}/${USER}/FRE_tests-${unique_string}-temp/.*/CM2.1U_Control-1990_E1.M_3A/${default_platform}-prod/exec/compile_CM2.1U_Control-1990_E1.M_3A.csh"

    if [ -n "${submit_cmd}" ]; then
        last_line_good="TO SUBMIT => ${submit_cmd} ${last_line_good}"
    else
        last_line_good="The compile script '${last_line_good}' is ready"
    fi

    unique_stdout_xml CM2.1U.xml >"${unique_string}-temp.xml"
    fremake -x "${unique_string}-temp.xml" -p ${default_platform} -t prod CM2.1U_Control-1990_E1.M_3A
    run fremake -x "${unique_string}-temp.xml" -p ${default_platform} -t prod CM2.1U_Control-1990_E1.M_3A -f

    # Get the last line from the output
    num_lines=${#lines[@]}
    last_line="${lines[$((num_lines-1))]}"

    print_output_status_and_diff_expected_long "$last_line" "$last_line_good"
    [ "$status" -eq 0 ]
    string_matches_pattern "$last_line" "$last_line_good"
    rm -rf "${root_stem}/${USER}/FRE_tests-${unique_string}-temp"
    rm "${unique_string}-temp.xml"
}

@test "Create compile script when executable directory exists and --force-compile specified" {
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

    last_line_good="${root_stem}/${USER}/FRE_tests-${unique_string}-temp/.*/CM2.1U_Control-1990_E1.M_3A/${default_platform}-prod/exec/compile_CM2.1U_Control-1990_E1.M_3A.csh"

    if [ -n "${submit_cmd}" ]; then
        last_line_good="TO SUBMIT => ${submit_cmd} ${last_line_good}"
    else
        last_line_good="The compile script '${last_line_good}' is ready"
    fi

    unique_stdout_xml CM2.1U.xml >"${unique_string}-temp.xml"
    fremake -x "${unique_string}-temp.xml" -p ${default_platform} -t prod CM2.1U_Control-1990_E1.M_3A
    run fremake -x "${unique_string}-temp.xml" -p ${default_platform} -t prod CM2.1U_Control-1990_E1.M_3A -F

    # Get the last line from the output
    num_lines=${#lines[@]}
    last_line="${lines[$((num_lines-1))]}"

    print_output_status_and_diff_expected_long "$last_line" "$last_line_good"
    [ "$status" -eq 0 ]
    string_matches_pattern "$last_line" "$last_line_good"
    rm -rf "${root_stem}/${USER}/FRE_tests-${unique_string}-temp"
    rm "${unique_string}-temp.xml"
}

@test "Create compile script and verify default batch scheduler mail target" {
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
        * )
            skip "No test for current platform"
            ;;
    esac

    unique_stdout_xml CM2.1U.xml >"${unique_string}-temp.xml"
    run fremake -x "${unique_string}-temp.xml" -p ${default_platform} -t prod CM2.1U_Control-1990_E1.M_3A
    [ "$status" -eq 0 ]

    script="${root_stem}/${USER}/FRE_tests-${unique_string}-temp/*/CM2.1U_Control-1990_E1.M_3A/${default_platform}-prod/exec/compile_CM2.1U_Control-1990_E1.M_3A.csh"
    grep "SBATCH --mail-user=$USER@noaa.gov" $script
    [ "$status" -eq 0 ]

    rm -rf "${root_stem}/${USER}/FRE_tests-${unique_string}-temp"
    rm "${unique_string}-temp.xml"
}

@test "Verify fremake error when using --mail-list with invalid email address" {
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

    unique_stdout_xml CM2.1U.xml >"${unique_string}-temp.xml"
    run fremake -x "${unique_string}-temp.xml" -p ${default_platform} -t prod CM2.1U_Control-1990_E1.M_3A --mail-list bad_address@no-domain
    [ "$status" -eq 10 ]

    rm -rf "${root_stem}/${USER}/FRE_tests-${unique_string}-temp"
    rm "${unique_string}-temp.xml"
}

@test "Create compile script and verify one user-specified batch scheduler mail target" {
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
        * )
            skip "No test for current platform"
            ;;
    esac

    unique_stdout_xml CM2.1U.xml >"${unique_string}-temp.xml"
    run fremake -x "${unique_string}-temp.xml" -p ${default_platform} -t prod CM2.1U_Control-1990_E1.M_3A --mail-list friendly_cats@gmail.com
    [ "$status" -eq 0 ]

    script="${root_stem}/${USER}/FRE_tests-${unique_string}-temp/*/CM2.1U_Control-1990_E1.M_3A/${default_platform}-prod/exec/compile_CM2.1U_Control-1990_E1.M_3A.csh"
    grep "SBATCH --mail-user=friendly_cats@gmail.com" $script
    [ "$status" -eq 0 ]

    rm -rf "${root_stem}/${USER}/FRE_tests-${unique_string}-temp"
    rm "${unique_string}-temp.xml"
}

@test "Create compile script and verify two user-specified batch scheduler mail targets" {
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
        * )
            skip "No test for current platform"
            ;;
    esac

    unique_stdout_xml CM2.1U.xml >"${unique_string}-temp.xml"
    run fremake -x "${unique_string}-temp.xml" -p ${default_platform} -t prod CM2.1U_Control-1990_E1.M_3A --mail-list one@foo.com,two@bar.edu
    [ "$status" -eq 0 ]

    script="${root_stem}/${USER}/FRE_tests-${unique_string}-temp/*/CM2.1U_Control-1990_E1.M_3A/${default_platform}-prod/exec/compile_CM2.1U_Control-1990_E1.M_3A.csh"
    grep "SBATCH --mail-user=one@foo.com,two@bar.edu" $script
    [ "$status" -eq 0 ]

    rm -rf "${root_stem}/${USER}/FRE_tests-${unique_string}-temp"
    rm "${unique_string}-temp.xml"
}
