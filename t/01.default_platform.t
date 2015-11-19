#!perl
use strict;
use warnings FATAL => 'all';
use Test::Most;
bail_on_fail;

my %tools = (
    diag_table_chk  => 0,
    frecheck        => 20,
    freinfo         => 20,
    frelist         => 0,
    fremake         => 0,
    frepriority     => 10,
    frerts_check    => 0,
    frerun          => 60,
    frescrub        => 0,
    frestatus       => 0,
    fretransform    => 0,
);

my $xml = 't/xml/CM2.1U.xml';
my $exp = 'CM2.1U_Control-1990_E1.M_3A';

ok(-f $xml);

while (my ($tool, $expected_exit_code) =  each %tools) {
    my $command = "$tool -x $xml -p default $exp";
    print "$command\n";
    my $exit_code = run($command);
    is($exit_code, 12,
        "$tool should exit with platform default problem; was $exit_code instead");
}

while (my ($tool, $expected_exit_code) =  each %tools) {
    my $command = "$tool -x $xml -p bad $exp";
    print "$command\n";
    my $exit_code = run($command);
    isnt($exit_code, 12);
}

for my $tool (keys %tools) {
    my $command = "$tool -x $xml $exp";
    print "$command\n";
    my $exit_code = run($command);
    is($exit_code, 12,
        "$tool should exit with platform default problem; was $exit_code instead");
}

while (my ($tool, $expected_exit_code) =  each %tools) {
    my $command = "$tool -x $xml -p intel $exp";
    print "$command\n";
    my $exit_code = run($command);
    is($exit_code, $expected_exit_code,
        "$tool should get expected exit code $expected_exit_code; was $exit_code instead");
}

sub run {
    my $command = shift;
    system $command;
    return $? >> 8;
}
