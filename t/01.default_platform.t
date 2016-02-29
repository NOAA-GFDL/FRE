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
    fremake         => [0, 30],
    frepriority     => [10, 30],
    frerts_check    => 0,
    frerun          => [20, 30],
    frescrub        => 0,
    frestatus       => 0,
    fretransform    => 0,
    'frepp -t 1982' => 0,
    'freppcheck -b 1980 -e 1981' => 0,
);

my $xml = 't/xml/CM2.1U.xml';
my $exp = 'CM2.1U_Control-1990_E1.M_3A';
my $good_platform = $ENV{HSM_SITE} eq 'gfdl' ? 'ncrc2-intel' : 'intel';

ok(-f $xml);

for my $tool (keys %tools) {
    next if $tool eq 'frelist';
    next if $tool =~ /frepp / and $ENV{HSM_SITE} ne 'gfdl';
    my $command = "$tool -x $xml -p default $exp";
    print "$command\n";
    my $exit_code = run($command);
    is($exit_code, 12,
        "$tool should exit with platform default problem");
}

for my $tool (keys %tools) {
    next if $tool =~ /frepp / and $ENV{HSM_SITE} ne 'gfdl';
    my $command = "$tool -x $xml --platform bad $exp";
    print "$command\n";
    my $exit_code = run($command);
    isnt($exit_code, 12, "$tool shouldn't exit with default platform problem");
}

for my $tool (keys %tools) {
    next if $tool eq 'frelist';
    next if $tool =~ /frepp / and $ENV{HSM_SITE} ne 'gfdl';
    my $command = "$tool -x $xml $exp";
    print "$command\n";
    my $exit_code = run($command);
    is($exit_code, 12, "$tool should exit with platform default problem");
}

while (my ($tool, $expected_exit_code) =  each %tools) {
    next if $tool =~ /frepp / and $ENV{HSM_SITE} ne 'gfdl';
    if (ref $expected_exit_code eq 'ARRAY') {
        $expected_exit_code
            = $ENV{HSM_SITE} eq 'gfdl' ? $expected_exit_code->[1]
            : $expected_exit_code->[0];
    }
    my $command = "$tool -x $xml --platform $good_platform $exp";
    print "$command\n";
    my $exit_code = run($command);
    is($exit_code, $expected_exit_code, "$tool should get expected exit code");
}

done_testing;

sub run {
    my $command = shift;
    system $command;
    return $? >> 8;
}
