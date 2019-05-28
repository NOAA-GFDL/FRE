#!/usr/bin/env bats
# -*- mode: sh; eval: (sh-set-shell "sh"); -*-

setup() {
   # Create a few files to test expand_variables with
   cat <<EOF >good_env_file
A=Hello
B=Hola
SOMETHING_OTHER=2
EOF

   cat <<EOF >bad_env_file
A=Hello
B=Hola
}
this is not a valid line
SOMETHING_OTHER=2
EOF

   cat <<EOF >expand_file
\$A World.
or \$B Mundo
But what would it be without \$SOMETHING_OTHER?
EOF

   cat <<EOF >sample_expanded_file
Hello World.
or Hola Mundo
But what would it be without 2?
EOF
}

teardown() {
   # Remove extra test files
   rm -f good_env_file
   rm -f bad_env_file
   rm -f expand_file
   rm -f sample_expanded_file
   rm -f expanded_file
}

@test "expand_variables works" {
   run expand_variables -h
   [ "$status" -eq 0 ]
}

@test "expand_variables reads valid file" {
   run expand_variables good_env_file < expand_file
   [ "$status" -eq 0 ]
   echo "$output" > expanded_file
   run diff expanded_file sample_expanded_file
   [ "$status" -eq 0 ]
}

@test "expand_variables catches error in env file" {
   run expand_variables bad_env_file < expand_file
   [ "$status" -eq 1 ]
   [[ "$output" =~ "Error in line 3 (})" ]]
}
