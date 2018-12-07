# -*- mode: sh; eval: (sh-set-shell "sh"); -*-

setup() {
    # Create a few tar files with some random data.
    # Eventually we will need some additional data files to make sure
    # ardiff is calling nccmp, and other commands.
    head -c 1024 /dev/urandom > testfile1
    head -c 1024 /dev/urandom > testfile2
    tar cf tar1.tar testfile1 testfile2 testrh.nc
    tar cf tar2.tar testfile1 testfile2 testrh.nc
    # Create directories as well
    mkdir ardiff_dir1
    mkdir ardiff_dir2
    cp testfile1 testfile2 testrh.nc ardiff_dir1
    cp testfile1 testfile2 testrh.nc ardiff_dir2
    ls -1 >&2
}

teardown() {
    # Remove sample tar files.
    rm -f testfile* *.tar
    rm -rf ardiff_dir?
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

@test "Dealing with no color from ls" {
    run bash -c "ls --color=none -1 tar1.tar tar2.tar | ardiff -c cp"
    [ "$status" -eq 0 ]
}

@test "ardiff compare two directories" {
    run bash -c "ls -1d ardiff_dir1 ardiff_dir2 | ardiff -c cp"
    [ "$status" -eq 0 ]
}