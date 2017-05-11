# add load test_helpers to the top of your bats files to load these functions

default_platform="${FRE_SYSTEM_SITE}.intel"

unique_stdout_xml() {
# NOTE: Do not use
# I have to transition away from this one
    awk </dev/null '/platform/{s=0}/"'"${FRE_SYSTEM_SITE}"'.intel"/{s=1}{if (s) {if ($0 ~ /<directory/){ret=system("sed s/UNIQUE_STRING/FRE_tests-'"${unique_string}"'-temp/ '"${platform}"'.dirs"); if(ret){exit ret}} else {print}} else {print}}' "$@"
}
unique_dir_xml() {
    awk </dev/null '/platform/{s=0}/"'"${default_platform}"'"/{s=1}{if (s) {if ($0 ~ /<directory/){ret=system("sed s/UNIQUE_STRING/'"${unique_string}"'/ '"${platform}"'.dirs"); if(ret){exit ret}} else {print}} else {print}}' "$@"
}
string_matches_pattern() {
# string pattern
    [ $( expr "$1" : "$2" ) -gt 0 ]
}
remove_output_matching() {
    output=$(printf '%s' "$output" | grep -v "$1")
}
remove_lines_matching() {
    for k in "${!lines[@]}"
    do
        if string_matches_pattern "${lines[$k]}" "$1"
        then
            unset lines[$k]
        fi
    done
}
remove_ninac_from_output_and_lines() {
    local ninac="NiNaC'ing ...Dir([.]*done\!)"
    remove_lines_matching "$ninac"
    remove_output_matching "$ninac"
}
