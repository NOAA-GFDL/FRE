#!perl
use strict;
use warnings FATAL => 'all';
use Test::Most;
use File::Basename;
use File::Spec::Functions;
bail_on_fail;

if ($ENV{HSM_SITE} eq 'gfdl') {
    done_testing;
    exit;
}

my $xml = 't/xml/CM2.1U.xml';
my $exp = 'CM2.1U_Control-1990_E1.M_3A';
my $good_platform = $ENV{HSM_SITE} eq 'gfdl' ? 'ncrc2-intel' : 'intel';

my $file = '/lustre/f1/unswept/Chris.Blanton/ulm_201505/CM2.1U_Control-1990_E1.M_3A/ncrc2.intel-debug/exec/compile_CM2.1U_Control-1990_E1.M_3A.csh';
my $cshrc = catfile dirname($file), 'env.cshrc';
my @files = ($file, $cshrc);

for (@files) {
    unlink $_ if -f $_;
}

system "fremake -F -x $xml -p intel -t debug $exp";

ok(-f $file, 'fremake runscript was generated');
ok(-f $cshrc, "fremake cshrc $cshrc was generated");

open (my $fh, $cshrc);
my @lines = <$fh>;
close $fh;
ok(grep(/echo "this is a secret"/, @lines), 'platform csh is in makescript');

done_testing;
