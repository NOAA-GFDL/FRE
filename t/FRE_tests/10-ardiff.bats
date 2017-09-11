# -*- mode: sh; eval: (sh-set-shell "sh"); -*-

setup() {
    # Create a few tar files with some random data.
    # Eventually we will need some additional data files to make sure
    # ardiff is calling nccmp, and other commands.
    head -c 1024 /dev/urandom > testfile1
    head -c 1024 /dev/urandom > testfile2
    tar cf tar1.tar testfile1 testfile2 testrh.nc
    tar cf tar2.tar testfile1 testfile2 testrh.nc
    ls -1 >&2
}

teardown() {
    # Remove sample tar files.
    rm -f testfile* *.tar
}

@test "ardiff prints help message" {
    run ardiff -h
    [ "$status" -eq 1 ]
}

@test "Dealing with color from ls" {
    # Set the alias to ls to always use color
    run bash -c "ls --color=always -1 tar1.tar tar2.tar | ardiff -c cp"
    [ "$status" -eq 0 ]
}