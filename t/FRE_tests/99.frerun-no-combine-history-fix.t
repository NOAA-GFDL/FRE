#!perl
=head1 NAME

99.frerun-no-combine-history-fix.t

=head1 DESCRIPTION

By default frerun combines history, which can be negated with the --no-combine-history option.

Since Bronx-12 this has been broken due to the output.stager fillGrid behavior.

The solution is to not activate the feature if history files aren't combined,
which this test confirms.

=cut

use strict;
use warnings FATAL => 'all';
use Test::More;

my $xml = 'xml/CM4_am4p0c96L33_OM4p5.xml';
my $platform = 'ncrc4.intel16';
my $exp = 'CM4_c96L33_am4p0_OMp5_2010_30d30_me_tlt_geo_kd15_fgnv0p1';



system "frerun -x $xml -p $platform $exp -o";
is($?, 0, 'control case frerun exited 0');

my $script_dir = `frelist -x $xml -p $platform $exp -d scripts`;
chomp $script_dir;
my $runscript = "$script_dir/run/$exp";
ok(-f $runscript, 'control case runscript exists');

system "grep 'set -r flagOutputFillGridOn' $runscript";
is($?, 0, "control case runscript will activate ocean_static hole-filling");



system "frerun -x $xml -p $platform $exp -o --no-combine-history";
is($?, 0, 'frerun --no-combine-history exited 0');

system "grep 'set -r flagOutputFillGridOff' $runscript";
is($?, 0, "--no-combine-history runscript will not activate ocean_static hole-filling");



done_testing();
