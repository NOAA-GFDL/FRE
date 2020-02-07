#!/usr/bin/env bats
# -*- mode: sh; eval: (sh-set-shell "sh"); -*-

setup() {
    # Create a few tar files with some random data.
    # Eventually we will need some additional data files to make sure
    # ardiff is calling nccmp, and other commands.
    head -c 1024 /dev/urandom > testfile1
    head -c 1024 /dev/urandom > testfile2
    cp testrh.nc testrh2.nc
    tar cf tar1.tar testfile1 testfile2 testrh.nc testrh2.nc
    tar cf tar2.tar testfile1 testfile2 testrh.nc testrh2.nc
    # Create directories as well
    mkdir ardiff_dir1
    mkdir ardiff_dir2
    cp testfile1 testfile2 testrh.nc testrh2.nc ardiff_dir1
    cp testfile1 testfile2 testrh.nc testrh2.nc ardiff_dir2
    # Create a expected failure test
    ncatted -a attribute,var1,c,c,"test" testrh2.nc
    tar cf tar3.tar testfile1 testfile2 testrh.nc testrh2.nc
    mkdir ardiff_dir3
    cp testfile1 testfile2 testrh.nc testrh2.nc ardiff_dir3
    ls -1 >&2
}

teardown() {
    # Remove sample tar files.
    rm -f testfile* *.tar testrh2.nc
    rm -rf ardiff_dir?
}

@test "ardiff prints help message" {
    run ardiff -h
    [ "$status" -eq 1 ]
}

@test "ardiff dealing with color from ls (identical tarfiles)" {
    # Set the alias to ls to always use color
    run bash -c "ls --color=always -1 tar1.tar tar2.tar | ardiff -c cp"
    [ "$status" -eq 0 ]
}

@test "ardiff dealing with no color from ls (identical tarfiles)" {
    run bash -c "ls --color=none -1 tar1.tar tar2.tar | ardiff -c cp"
    [ "$status" -eq 0 ]
}

@test "ardiff reports failure when tarfiles are different" {
    run bash -c "ls -1 tar1.tar tar3.tar | ardiff -c cp"
    [ "$status" -eq 1 ]
}

@test "ardiff compare two identical directories" {
    run bash -c "ls -1d ardiff_dir1 ardiff_dir2 | ardiff -c cp"
    [ "$status" -eq 0 ]
}

@test "ardiff reports failure when directories are different" {
    run bash -c "ls -1d ardiff_dir1 ardiff_dir3 | ardiff -c cp"
    [ "$status" -eq 1 ]
}

@test "ardiff.py compares two identical tarfiles" {
    run bash -c "ardiff.py tar1.tar tar2.tar"
    [ "$status" -eq 0 ]
}

@test "ardiff.py reports failure when tarfiles are different" {
    run bash -c "ardiff.py tar1.tar tar3.tar"
    [ "$status" -eq 1 ]
}

@test "ardiff.py reports failure when directories are different" {
    run bash -c "ardiff.py ardiff_dir1 ardiff_dir3"
    [ "$status" -eq 1 ]
}
