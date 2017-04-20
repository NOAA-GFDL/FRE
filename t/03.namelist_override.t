#!perl
use strict;
use warnings FATAL => 'all';
use Test::More tests => 1;
use FRENamelists;

if ($ENV{HSM_SITE} eq 'gfdl') {
    ok(1);
    exit;
}

my $base = <<'EOF';
    var1 = 0.0001
    var2 = .true.
    var3 = 'string'
    var3(1)='blah1',
    var3(2)='blah2',
    foo = 10.01,
    file = "/path/to/file",
    x = 1, y = 2,
    multi = 1890, 1, 1, 0, 0, 0,
            1790, 1, 1, 0, 0, 0,
            1690, 1, 1, 0, 0, 0,
            1590, 1, 1, 0, 0, 0,
EOF

my $child = <<'EOF';
    var3 = 'override',
    var10 = 'newvar',
    var11 = .false.
    foo = 1.0
    # next items don't work as they should
    x = 10,
    multi = 0001, 1, 1, 0, 0, 0,
            0002, 1, 1, 0, 0, 0,
            0003, 1, 1, 0, 0, 0,
            0004, 1, 1, 0, 0, 0,
EOF

my $ref_override = <<EOF;
\tvar10 = 'newvar',
\tvar11 = .false.
    var1 = 0.0001
    var2 = .true.
    var3 = 'override',
    var3(1)='blah1',
    var3(2)='blah2',
    foo = 1.0
    file = "/path/to/file",
    x = 10,
    multi = 0001, 1, 1, 0, 0, 0,
            1790, 1, 1, 0, 0, 0,
            1690, 1, 1, 0, 0, 0,
            1590, 1, 1, 0, 0, 0,
EOF

my $override = FRENamelists::mergeNamelistContent($base, $child);
#print "reference:\n$ref_override\nEOF\n";
#print "testing:\n$override\nEOF\n";
ok($override eq $ref_override, "Merged content is equal to reference content");
