# -*- mode: sh; eval: (sh-set-shell "sh"); -*-

# The output_good strings are configured with the exact number of spaces needed
# for the tests to pass.  DO NOT adjust unless needed, this includes removing
# whitespace.

setup() {
    unique_string="date$(date +%s)pid$$"
}

@test "frerun is in PATH" {
    run which frerun
    echo "Got: \"$output\""
    echo "Exit status: $status"
    [ "$status" -eq 0 ]
}

@test "frerun print help message" {
    run frerun -h
    echo "Got: \"$output\""
    echo "Exit status: $status"
    [ "$status" -eq 0 ]
}

@test "frerun print version" {
    run frerun -V
    echo "Got: \"$output\""
    echo "Exit status: $status"
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
    echo "Expected: \"$output_good\""
    echo "Got:      \"$output\""
    echo "Exit status: $status"
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
    run frerun CM2.1U_Control-1990_E1.M_3A
    echo "Expected: \"$output_good\""
    echo "Got:      \"$output\""
    echo "Exit status: $status"
    [ "$status" -eq 30 ]
    [ "$output" = "$output_good" ]
}

@test "Create run script when experiment listed on frerun command line, and rts.xml exists" {
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

    last_line_good="TO SUBMIT => ${submit_cmd} ${root_stem}/${USER}/FRE_tests-${unique_string}-temp/ulm_201505/CM2.1U_Control-1990_E1.M_3B_snowmelt/${platform}.default-prod/scripts/run/CM2.1U_Control-1990_E1.M_3B_snowmelt"

    sed "s/SED_UNIQUE_STRING_HERE/${unique_string}/" <sedMe.xml >rts.xml
    run frerun CM2.1U_Control-1990_E1.M_3B_snowmelt

    # Get the last line from the output
    num_lines=${#lines[@]}
    last_line="${lines[$((${num_lines}-1))]}"

    echo "Output:   \"$output\""
    echo "Expected: \"$last_line_good\""
    echo "Got:      \"$last_line\""
    echo "Exit status: $status"
    [ "$status" -eq 0 ]
    [ "$last_line" = "$last_line_good" ]
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
    run frerun -x nonexistent_file.xml CM2.1U_Control-1990_E1.M_3A
    echo "Expected: \"$output_good\""
    echo "Got:      \"$output\""
    echo "Exit status: $status"
    [ "$status" -eq 30 ]
    [ "$output" = "$output_good" ]
}

@test "Create run script when XML listed on frerun command line and XML file exists" {
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

    last_line_good="TO SUBMIT => ${submit_cmd} ${root_stem}/${USER}/FRE_tests-${unique_string}-temp/ulm_201505/CM2.1U_Control-1990_E1.M_3B_snowmelt/${platform}.default-prod/scripts/run/CM2.1U_Control-1990_E1.M_3B_snowmelt"

    sed "s/SED_UNIQUE_STRING_HERE/${unique_string}/" <sedMe.xml >"${unique_string}-temp.xml"
    run frerun -x "${unique_string}-temp.xml" CM2.1U_Control-1990_E1.M_3B_snowmelt

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

    # NOTE: I am using the $USER environment variable so we don't have to glob and escape the * in *FATAL*
    output_good="*FATAL*: XML file line 42: the platform '${platform}.nonexistent_platform' is missed
*FATAL*: A problem with the XML file '`pwd -P`/CM2.1U.xml'"

    run frerun -x CM2.1U.xml -p nonexistent_platform CM2.1U_Control-1990_E1.M_3B_snowmelt
    echo "Expected: \"$output_good\""
    echo "Got:      \"$output\""
    echo "Exit status: $status"
    [ "$status" -eq 30 ]
    [ "$output" = "$output_good" ]
}

@test "Create run script when --platform=<current_platform_here>.intel" {
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

    last_line_good="TO SUBMIT => ${submit_cmd} ${root_stem}/${USER}/FRE_tests-${unique_string}-temp/ulm_201505/CM2.1U_Control-1990_E1.M_3B_snowmelt/${platform}.intel-prod/scripts/run/CM2.1U_Control-1990_E1.M_3B_snowmelt"

    sed "s/SED_UNIQUE_STRING_HERE/${unique_string}/" <sedMe.xml >"${unique_string}-temp.xml"
    run frerun -x "${unique_string}-temp.xml" -p "${platform}.intel" CM2.1U_Control-1990_E1.M_3B_snowmelt

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

@test "Create run script when --platform=intel" {
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

    last_line_good="TO SUBMIT => ${submit_cmd} ${root_stem}/${USER}/FRE_tests-${unique_string}-temp/ulm_201505/CM2.1U_Control-1990_E1.M_3B_snowmelt/${platform}.intel-prod/scripts/run/CM2.1U_Control-1990_E1.M_3B_snowmelt"

    sed "s/SED_UNIQUE_STRING_HERE/${unique_string}/" <sedMe.xml >"${unique_string}-temp.xml"
    run frerun -x "${unique_string}-temp.xml" -p intel CM2.1U_Control-1990_E1.M_3B_snowmelt

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

@test "Create run script when --target=prod" {
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

    last_line_good="TO SUBMIT => ${submit_cmd} ${root_stem}/${USER}/FRE_tests-${unique_string}-temp/ulm_201505/CM2.1U_Control-1990_E1.M_3B_snowmelt/${platform}.intel-prod/scripts/run/CM2.1U_Control-1990_E1.M_3B_snowmelt"

    sed "s/SED_UNIQUE_STRING_HERE/${unique_string}/" <sedMe.xml >"${unique_string}-temp.xml"
    run frerun -x "${unique_string}-temp.xml" -p intel -t prod CM2.1U_Control-1990_E1.M_3B_snowmelt

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

@test "State directory exists but --extend, --overwrite, or --unique not specified" {
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

    last_3_lines_good="*FATAL*: The state directory '${root_stem}/${USER}/FRE_tests-${unique_string}-temp/ulm_201505/CM2.1U_Control-1990_E1.M_3B_snowmelt/${platform}.intel-prod/state/run' exists, so you must specify --extend, --overwrite or --unique
*FATAL*: Unable to setup output directories for the experiment 'CM2.1U_Control-1990_E1.M_3B_snowmelt'
*FATAL*: Unable to create a runscript for the experiment 'CM2.1U_Control-1990_E1.M_3B_snowmelt'"

    sed "s/SED_UNIQUE_STRING_HERE/${unique_string}/" <sedMe.xml >"${unique_string}-temp.xml"
    mkdir -p "${root_stem}/${USER}/FRE_tests-${unique_string}-temp/ulm_201505/CM2.1U_Control-1990_E1.M_3B_snowmelt/${platform}.intel-prod/state/run"
    run frerun -x "${unique_string}-temp.xml" -p intel -t prod CM2.1U_Control-1990_E1.M_3B_snowmelt

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

    echo "Output:   \"$output\""
    echo "Expected: \"$last_3_lines_good\""
    echo "Got:      \"$last_3_lines\""
    echo "Exit status: $status"
    [ "$status" -eq 60 ]
    [ "$last_3_lines" = "$last_3_lines_good" ]
    rm -rf "${root_stem}/${USER}/FRE_tests-${unique_string}-temp"
    rm "${unique_string}-temp.xml"
}

@test "Create run script when state directory exists and --overwrite is specified" {
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

    last_line_good="TO SUBMIT => ${submit_cmd} ${root_stem}/${USER}/FRE_tests-${unique_string}-temp/ulm_201505/CM2.1U_Control-1990_E1.M_3B_snowmelt/${platform}.intel-prod/scripts/run/CM2.1U_Control-1990_E1.M_3B_snowmelt"

    sed "s/SED_UNIQUE_STRING_HERE/${unique_string}/" <sedMe.xml >"${unique_string}-temp.xml"
    mkdir -p "${root_stem}/${USER}/FRE_tests-${unique_string}-temp/ulm_201505/CM2.1U_Control-1990_E1.M_3B_snowmelt/${platform}.intel-prod/state/run"
    run frerun -x "${unique_string}-temp.xml" -p intel -t prod CM2.1U_Control-1990_E1.M_3B_snowmelt -o

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

@test "Create run script when state directory exists and --unique is specified" {
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

    last_line_good="TO SUBMIT => ${submit_cmd} ${root_stem}/${USER}/FRE_tests-${unique_string}-temp/ulm_201505/CM2.1U_Control-1990_E1.M_3B_snowmelt/${platform}.intel-prod/scripts/run/CM2.1U_Control-1990_E1.M_3B_snowmelt__1"

    sed "s/SED_UNIQUE_STRING_HERE/${unique_string}/" <sedMe.xml >"${unique_string}-temp.xml"
    mkdir -p "${root_stem}/${USER}/FRE_tests-${unique_string}-temp/ulm_201505/CM2.1U_Control-1990_E1.M_3B_snowmelt/${platform}.intel-prod/state/run"
    run frerun -x "${unique_string}-temp.xml" -p intel -t prod CM2.1U_Control-1990_E1.M_3B_snowmelt -u

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

@test "Create run script when state directory exists and --extend is specified" {
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

    last_line_good="TO SUBMIT => ${submit_cmd} ${root_stem}/${USER}/FRE_tests-${unique_string}-temp/ulm_201505/CM2.1U_Control-1990_E1.M_3B_snowmelt/${platform}.intel-prod/scripts/run/CM2.1U_Control-1990_E1.M_3B_snowmelt"

    sed "s/SED_UNIQUE_STRING_HERE/${unique_string}/" <sedMe.xml >"${unique_string}-temp.xml"
    mkdir -p "${root_stem}/${USER}/FRE_tests-${unique_string}-temp/ulm_201505/CM2.1U_Control-1990_E1.M_3B_snowmelt/${platform}.intel-prod/state/run"
    run frerun -x "${unique_string}-temp.xml" -p intel -t prod CM2.1U_Control-1990_E1.M_3B_snowmelt -e

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
