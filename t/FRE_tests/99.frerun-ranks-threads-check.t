#!perl
=head1 NAME

99.frerun-ranks-threads-check.t

=head1 DESCRIPTION

Since Bronx-11, resources (ranks, threads) have been specified in a <resources> tag.

Ranks and threads should be both non-zero, or zero for a non-active component.
Anything else should cause a frerun error.

=cut

use strict;
use warnings FATAL => 'all';
use Test::More;

# don't run frerun test at gfdl
if ($ENV{HSM_SITE} =~ /gfdl/) {
    plan skip_all => 'Test irrelevant on PP/AN and not likely to work on workstations';
}

my $xml = 'xml/CM4_am4p0c96L33_OM4p5.xml';
my $platform = 'ncrc4.intel16';
my $exp = 'CM4_c96L33_am4p0_OMp5_2010_30d30_me_tlt_geo_kd15_fgnv0p1';

system "frerun --qos=normal --cluster=c4 --transfer --target=openmp -x $xml -p $platform $exp -o > /dev/null 2>&1";
is($?, 0, 'control case frerun exited 0');

system "frerun -x $xml -p $platform $exp -o -r nothreads > /dev/null 2>&1";
isnt($?, 0, 'ranks/nothreads case gives error');

system "frerun -x $xml -p $platform $exp -o -r noranks > /dev/null 2>&1";
isnt($?, 0, 'noranks/threads case gives error');

system "frerun -x $xml -p $platform $exp -o -r noranks-nothreads > /dev/null 2>&1";
is($?, 0, 'noranks/nothreads case exits 0');

my $message = `frerun -x $xml -p $platform $exp -o -r nothreads 2>&1`;
like($message, qr/.FATAL.: A resource request tag was found but was incomplete./, 'ranks/nothreads case contains informative error message');

done_testing();
