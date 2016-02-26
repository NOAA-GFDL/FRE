# -*- mode: sh; eval: (sh-set-shell "sh"); -*-

# The output_good strings are configured with the exact number of spaces needed
# for the tests to pass.  DO NOT adjust unless needed, this includes removing
# whitespace.
good_platform="ncrc2.intel"

setup() {
    unique_string="date$(date +%s)pid$$"
}

@test "fremake is in PATH" {
    run which fremake
    echo "Got: \"$output\""
    echo "Exit status: $status"
    [ "$status" -eq 0 ]
}

@test "fremake print help message" {
    run fremake -h
    echo "Got: \"$output\""
    echo "Exit status: $status"
    [ "$status" -eq 0 ]
}

@test "fremake print version" {
    run fremake -V
    echo "Got: \"$output\""
    echo "Exit status: $status"
    [ "$status" -eq 0 ]
}

@test "No experiment listed on fremake command line and no rts.xml file" {
    case $( hostname ) in
        an??? )
            skip "Don't test fremake on Analysis"
            ;;
        * )
            output_good="*FATAL*: At least one experiment name is needed on the command line
         Try 'fremake --help' for more information"
            ;;
    esac

    run fremake
    echo "Expected: \"$output_good\""
    echo "Got:      \"$output\""
    echo "Exit status: $status"
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
    run fremake -p $good_platform CM2.1U_Control-1990_E1.M_3A
    echo "Expected: \"$output_good\""
    echo "Got:      \"$output\""
    echo "Exit status: $status"
    [ "$status" -eq 30 ]
    [ "$output" = "$output_good" ]
}

@test "Create compile script when experiment listed on fremake command line, and rts.xml exists" {
    case $( hostname ) in
        gaea?* )
            platform="ncrc2"
            root_stem="/lustre/f1"
            submit_cmd="sleep 1; msub"
            ;;
        tfe?? )
            platform="theia"
            root_stem="/scratch4/GFDL/gfdlscr"
            submit_cmd="qsub"
            ;;
        * )
            skip "No test for current platform"
            ;;
    esac

    last_line_good="TO SUBMIT => ${submit_cmd} ${root_stem}/${USER}/FRE_tests-${unique_string}-temp/ulm_201505/CM2.1U_Control-1990_E1.M_3A/${platform}.intel-prod/exec/compile_CM2.1U_Control-1990_E1.M_3A.csh"

    sed "s/SED_UNIQUE_STRING_HERE/${unique_string}/" <sedMe.xml >rts.xml
    run fremake -p $good_platform CM2.1U_Control-1990_E1.M_3A

    # Get the last line from the output
    num_lines=${#lines[@]}
    last_line="${lines[$((num_lines-1))]}"

    echo "Output:   \"$output\""
    echo "Expected: \"$last_line_good\""
    echo "Got:      \"$last_line\""
    echo "Exit status: $status"
    [ "$status" -eq 0 ]
    [ "$last_line" = "$last_line_good" ]
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
    run fremake -x nonexistent_file.xml -p $good_platform CM2.1U_Control-1990_E1.M_3A
    echo "Expected: \"$output_good\""
    echo "Got:      \"$output\""
    echo "Exit status: $status"
    [ "$status" -eq 30 ]
    [ "$output" = "$output_good" ]
}

@test "Create compile script when XML listed on fremake command line and XML file exists" {
    case $( hostname ) in
        gaea?* )
            platform="ncrc2"
            root_stem="/lustre/f1"
            submit_cmd="sleep 1; msub"
            ;;
        tfe?? )
            platform="theia"
            root_stem="/scratch4/GFDL/gfdlscr"
            submit_cmd="qsub"
            ;;
        * )
            skip "No test for current platform"
            ;;
    esac

    last_line_good="TO SUBMIT => ${submit_cmd} ${root_stem}/${USER}/FRE_tests-${unique_string}-temp/ulm_201505/CM2.1U_Control-1990_E1.M_3A/${platform}.intel-prod/exec/compile_CM2.1U_Control-1990_E1.M_3A.csh"
    # NOTE: used $USER above

    sed "s/SED_UNIQUE_STRING_HERE/${unique_string}/" <sedMe.xml >"${unique_string}-temp.xml"
    run fremake -x "${unique_string}-temp.xml" -p $good_platform CM2.1U_Control-1990_E1.M_3A

    # Get the last line from the output
    num_lines=${#lines[@]}
    last_line="${lines[$((num_lines-1))]}"

    echo "Output:   \"$output\""
    echo "Expected: \"$last_line_good\""
    echo "Got:      \"$last_line\""
    echo "Exit status: $status"
    [ "$status" -eq 0 ]
    [ "$last_line" = "$last_line_good" ]
    rm -rf "${root_stem}/${USER}/FRE_tests-${unique_string}-temp"
    rm "${unique_string}-temp.xml"
}

@test "Specify nonexistent platform" {
    case $( hostname ) in
        gaea?* )
            platform="ncrc2"
            ;;
        tfe?? )
            platform="theia"
            ;;
        * )
            skip "No test for current platform"
            ;;
    esac

    output_good="*FATAL*: XML file line 42: the platform '${platform}.nonexistent_platform' is missed
*FATAL*: A problem with the XML file '`pwd -P`/CM2.1U.xml'"

    run fremake -x CM2.1U.xml -p nonexistent_platform CM2.1U_Control-1990_E1.M_3A
    echo "Expected: \"$output_good\""
    echo "Got:      \"$output\""
    echo "Exit status: $status"
    [ "$status" -eq 30 ]
    [ "$output" = "$output_good" ]
}

@test "Create compile script when --platform=<current_platform_here>.intel" {
    case $( hostname ) in
        gaea?* )
            platform="ncrc2"
            root_stem="/lustre/f1"
            submit_cmd="sleep 1; msub"
            ;;
        tfe?? )
            platform="theia"
            root_stem="/scratch4/GFDL/gfdlscr"
            submit_cmd="qsub"
            ;;
        * )
            skip "No test for current platform"
            ;;
    esac

    last_line_good="TO SUBMIT => ${submit_cmd} ${root_stem}/${USER}/FRE_tests-${unique_string}-temp/ulm_201505/CM2.1U_Control-1990_E1.M_3A/${platform}.intel-prod/exec/compile_CM2.1U_Control-1990_E1.M_3A.csh"

    sed "s/SED_UNIQUE_STRING_HERE/${unique_string}/" <sedMe.xml >"${unique_string}-temp.xml"
    run fremake -x "${unique_string}-temp.xml" -p "${platform}.intel" CM2.1U_Control-1990_E1.M_3A

    # Get the last line from the output
    num_lines=${#lines[@]}
    last_line="${lines[$((num_lines-1))]}"

    echo "Output:   \"$output\""
    echo "Expected: \"$last_line_good\""
    echo "Got:      \"$last_line\""
    echo "Exit status: $status"
    [ "$status" -eq 0 ]
    [ "$last_line" = "$last_line_good" ]
    rm -rf "${root_stem}/${USER}/FRE_tests-${unique_string}-temp"
    rm "${unique_string}-temp.xml"
}

@test "Create compile script when --platform=intel" {
    case $( hostname ) in
        gaea?* )
            platform="ncrc2"
            root_stem="/lustre/f1"
            submit_cmd="sleep 1; msub"
            ;;
        tfe?? )
            platform="theia"
            root_stem="/scratch4/GFDL/gfdlscr"
            submit_cmd="qsub"
            ;;
        * )
            skip "No test for current platform"
            ;;
    esac

    last_line_good="TO SUBMIT => ${submit_cmd} ${root_stem}/${USER}/FRE_tests-${unique_string}-temp/ulm_201505/CM2.1U_Control-1990_E1.M_3A/${platform}.intel-prod/exec/compile_CM2.1U_Control-1990_E1.M_3A.csh"

    sed "s/SED_UNIQUE_STRING_HERE/${unique_string}/" <sedMe.xml >"${unique_string}-temp.xml"
    run fremake -x "${unique_string}-temp.xml" -p intel CM2.1U_Control-1990_E1.M_3A

    # Get the last line from the output
    num_lines=${#lines[@]}
    last_line="${lines[$((num_lines-1))]}"

    echo "Output:   \"$output\""
    echo "Expected: \"$last_line_good\""
    echo "Got:      \"$last_line\""
    echo "Exit status: $status"
    [ "$status" -eq 0 ]
    [ "$last_line" = "$last_line_good" ]
    rm -rf "${root_stem}/${USER}/FRE_tests-${unique_string}-temp"
    rm "${unique_string}-temp.xml"
}

@test "Create compile script when --target=prod" {
    case $( hostname ) in
        gaea?* )
            platform="ncrc2"
            root_stem="/lustre/f1"
            submit_cmd="sleep 1; msub"
            ;;
        tfe?? )
            platform="theia"
            root_stem="/scratch4/GFDL/gfdlscr"
            submit_cmd="qsub"
            ;;
        * )
            skip "No test for current platform"
            ;;
    esac

    last_line_good="TO SUBMIT => ${submit_cmd} ${root_stem}/${USER}/FRE_tests-${unique_string}-temp/ulm_201505/CM2.1U_Control-1990_E1.M_3A/${platform}.intel-prod/exec/compile_CM2.1U_Control-1990_E1.M_3A.csh"

    sed "s/SED_UNIQUE_STRING_HERE/${unique_string}/" <sedMe.xml >"${unique_string}-temp.xml"
    run fremake -x "${unique_string}-temp.xml" -p intel -t prod CM2.1U_Control-1990_E1.M_3A

    # Get the last line from the output
    num_lines=${#lines[@]}
    last_line="${lines[$((num_lines-1))]}"

    echo "Output:   \"$output\""
    echo "Expected: \"$last_line_good\""
    echo "Got:      \"$last_line\""
    echo "Exit status: $status"
    [ "$status" -eq 0 ]
    [ "$last_line" = "$last_line_good" ]
    rm -rf "${root_stem}/${USER}/FRE_tests-${unique_string}-temp"
    rm "${unique_string}-temp.xml"
}

@test "Source and executable directories exist but --force-checkout and --force-compile not specified" {
    case $( hostname ) in
        gaea?* )
            platform="ncrc2"
            root_stem="/lustre/f1"
            submit_cmd="sleep 1; msub"
            ;;
        tfe?? )
            platform="theia"
            root_stem="/scratch4/GFDL/gfdlscr"
            submit_cmd="qsub"
            ;;
        * )
            skip "No test for current platform"
            ;;
    esac

    output_good="WARNING: The checkout script '${root_stem}/${USER}/FRE_tests-${unique_string}-temp/ulm_201505/CM2.1U_Control-1990_E1.M_3A/src/checkout.csh' already exists and matches checkout instructions in the XML file, so checkout is skipped
WARNING: The compile script '${root_stem}/${USER}/FRE_tests-${unique_string}-temp/ulm_201505/CM2.1U_Control-1990_E1.M_3A/${platform}.intel-prod/exec/compile_CM2.1U_Control-1990_E1.M_3A.csh' already exists and matches compile instructions in the XML file
TO SUBMIT => ${submit_cmd} ${root_stem}/${USER}/FRE_tests-${unique_string}-temp/ulm_201505/CM2.1U_Control-1990_E1.M_3A/${platform}.intel-prod/exec/compile_CM2.1U_Control-1990_E1.M_3A.csh"

    sed "s/SED_UNIQUE_STRING_HERE/${unique_string}/" <sedMe.xml >"${unique_string}-temp.xml"
    fremake -x "${unique_string}-temp.xml" -p intel -t prod CM2.1U_Control-1990_E1.M_3A
    run fremake -x "${unique_string}-temp.xml" -p intel -t prod CM2.1U_Control-1990_E1.M_3A

    echo "Expected: \"$output_good\""
    echo "Got:      \"$output\""
    echo "Exit status: $status"
    [ "$status" -eq 0 ]
    [ "$output" = "$output_good" ]
    rm -rf "${root_stem}/${USER}/FRE_tests-${unique_string}-temp"
    rm "${unique_string}-temp.xml"
}

@test "Create compile script when source directory exists and --force-checkout specified" {
    case $( hostname ) in
        gaea?* )
            platform="ncrc2"
            root_stem="/lustre/f1"
            submit_cmd="sleep 1; msub"
            ;;
        tfe?? )
            platform="theia"
            root_stem="/scratch4/GFDL/gfdlscr"
            submit_cmd="qsub"
            ;;
        * )
            skip "No test for current platform"
            ;;
    esac

    last_line_good="TO SUBMIT => ${submit_cmd} ${root_stem}/${USER}/FRE_tests-${unique_string}-temp/ulm_201505/CM2.1U_Control-1990_E1.M_3A/${platform}.intel-prod/exec/compile_CM2.1U_Control-1990_E1.M_3A.csh"

    sed "s/SED_UNIQUE_STRING_HERE/${unique_string}/" <sedMe.xml >"${unique_string}-temp.xml"
    fremake -x "${unique_string}-temp.xml" -p intel -t prod CM2.1U_Control-1990_E1.M_3A
    run fremake -x "${unique_string}-temp.xml" -p intel -t prod CM2.1U_Control-1990_E1.M_3A -f

    # Get the last line from the output
    num_lines=${#lines[@]}
    last_line="${lines[$((num_lines-1))]}"

    echo "Output:   \"$output\""
    echo "Expected: \"$last_line_good\""
    echo "Got:      \"$last_line\""
    echo "Exit status: $status"
    [ "$status" -eq 0 ]
    [ "$last_line" = "$last_line_good" ]
    rm -rf "${root_stem}/${USER}/FRE_tests-${unique_string}-temp"
    rm "${unique_string}-temp.xml"
}

@test "Create compile script when executable directory exists and --force-compile specified" {
    case $( hostname ) in
        gaea?* )
            platform="ncrc2"
            root_stem="/lustre/f1"
            submit_cmd="sleep 1; msub"
            ;;
        tfe?? )
            platform="theia"
            root_stem="/scratch4/GFDL/gfdlscr"
            submit_cmd="qsub"
            ;;
        * )
            skip "No test for current platform"
            ;;
    esac

    last_line_good="TO SUBMIT => ${submit_cmd} ${root_stem}/${USER}/FRE_tests-${unique_string}-temp/ulm_201505/CM2.1U_Control-1990_E1.M_3A/${platform}.intel-prod/exec/compile_CM2.1U_Control-1990_E1.M_3A.csh"

    sed "s/SED_UNIQUE_STRING_HERE/${unique_string}/" <sedMe.xml >"${unique_string}-temp.xml"
    fremake -x "${unique_string}-temp.xml" -p intel -t prod CM2.1U_Control-1990_E1.M_3A
    run fremake -x "${unique_string}-temp.xml" -p intel -t prod CM2.1U_Control-1990_E1.M_3A -F

    # Get the last line from the output
    num_lines=${#lines[@]}
    last_line="${lines[$((num_lines-1))]}"

    echo "Output:   \"$output\""
    echo "Expected: \"$last_line_good\""
    echo "Got:      \"$last_line\""
    echo "Exit status: $status"
    [ "$status" -eq 0 ]
    [ "$last_line" = "$last_line_good" ]
    rm -rf "${root_stem}/${USER}/FRE_tests-${unique_string}-temp"
    rm "${unique_string}-temp.xml"
}
