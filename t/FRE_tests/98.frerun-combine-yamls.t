#!perl
=head1 NAME

98.frerun-combine-yamls.t

=head1 DESCRIPTION

FMS input files (diag, data, fieldtables) have traditionally been handled by
FRE and combined into the runscript. Those tables are combined with
simple concatenation.

FMS is moving to yaml input files (diag, data, field yamls) in Bronx-21, and
as with the tables, FRE must combine the yamls and place the combined files
in the runscript. However, combining yamls is not as trivial as concatenation.
We are using three external tools for this purpose, which are available in
the site bin directories: combine-data-table-yamls, combine-diag-table-yamls,
and combine-field-table-yamls.

This test exercises each of the three combiners, combining two yamls
and verifying the result.

=cut

use strict;
use warnings FATAL => 'all';
use FREExperiment;
use FREMsg;

# dataYaml examples
my $data1 = <<'EOF';
data_table:
- gridname: ICE
  fieldname_code: sic_obs
  fieldname_file: ice
  file_name: INPUT/hadisst_ice.data.nc
  interpol_method: bilinear
  factor: 0.01
EOF
my $data2 = <<'EOF';
data_table:
- gridname: LND
  fieldname_code: phot_co2
  fieldname_file: co2
  file_name: INPUT/co2_data.nc
  interpol_method: bilinear
  factor: 1.0e-06
EOF
my $data3 = <<EOF;
data_table:
- factor: 0.01
  fieldname_code: sic_obs
  fieldname_file: ice
  file_name: INPUT/hadisst_ice.data.nc
  gridname: ICE
  interpol_method: bilinear
- factor: 1.0e-06
  fieldname_code: phot_co2
  fieldname_file: co2
  file_name: INPUT/co2_data.nc
  gridname: LND
  interpol_method: bilinear
EOF

# fieldYaml examples
my $field1 = <<EOF;
field_table:
- field_type: tracer
  modlist:
  - model_type: atmos_mod
    varlist:
    - variable: sphum
      longname: specific humidity
      units: kg/kg
      profile_type: fixed
      subparams:
      - surface_value: 3.0e-06
EOF
my $field2 = <<EOF;
field_table:
- field_type: tracer
  modlist:
  - model_type: atmos_mod
    varlist:
    - variable: liq_wat
      longname: cloud liquid specific humidity
      units: kg/kg
EOF
my $field3 = <<EOF;
field_table:
- field_type: tracer
  modlist:
  - model_type: atmos_mod
    varlist:
    - longname: specific humidity
      profile_type: fixed
      subparams:
      - surface_value: 3.0e-06
      units: kg/kg
      variable: sphum
    - longname: cloud liquid specific humidity
      units: kg/kg
      variable: liq_wat
EOF

my $diag1 = <<EOF;
title: c96L33_am4p0_cmip6Diag
base_date: 1979 1 1 0 0 0
diag_files:
- file_name: grid_spec
  freq: -1
  freq_units: months
  time_units: days
  unlimdim: time
  varlist:
  - module: dynamics
    var_name: grid_lon
    reduction: none
    kind: r4
EOF
my $diag2 = <<EOF;
diag_files:
- file_name: atmos_4xdaily
  freq: 6
  freq_units: hours
  time_units: days
  unlimdim: time
  varlist:
  - module: dynamics
    var_name: tm
    reduction: none
    kind: r4
  - module: flux
    var_name: u_ref
    reduction: none
    kind: r4
  - module: flux
    var_name: v_ref
    reduction: none
    kind: r4
EOF
my $diag3 = <<EOF;
title: c96L33_am4p0_cmip6Diag
base_date: 1979 1 1 0 0 0
diag_files:
- file_name: grid_spec
  freq: -1
  freq_units: months
  time_units: days
  unlimdim: time
  varlist:
  - module: dynamics
    var_name: grid_lon
    reduction: none
    kind: r4
- file_name: atmos_4xdaily
  freq: 6
  freq_units: hours
  time_units: days
  unlimdim: time
  varlist:
  - module: dynamics
    var_name: tm
    reduction: none
    kind: r4
  - module: flux
    var_name: u_ref
    reduction: none
    kind: r4
  - module: flux
    var_name: v_ref
    reduction: none
    kind: r4
EOF

# spoof the FRE class
# only need the out method
package FRE;
sub new {
    my ($class) = @_;
    my $fre = {};
    bless $fre, $class;
    return $fre;
}
sub out {
    my $fre = shift;
    my $verbose = 0;
    FREMsg::out( $verbose, shift, @_ );
}
my $fre = FRE->new();

# run the 4 tests
use Test::More tests => 4;

# remove newlines from reference output
chomp $data3;
chomp $field3;
chomp $diag3;

# combine and compare
is(FREExperiment::_append_yaml($fre, $data1, $data2, 'dataYaml'), $data3, "combine two dataYamls and verify output");
is(FREExperiment::_append_yaml($fre, $field1, $field2, 'fieldYaml'), $field3, "combine two fieldYamls and verify output");
is(FREExperiment::_append_yaml($fre, $diag1, $diag2, 'diagYaml'), $diag3, "combine two diagYamls and verify output");

# verify bad input causes error
# This is missing the diag_files header
my $bad_diag = <<EOF;
  freq: 6
  freq_units: hours
  time_units: days
  unlimdim: time
  varlist:
  - module: dynamics
    var_name: tm
    reduction: none
    kind: r4
  - module: flux
    var_name: u_ref
    reduction: none
    kind: r4
  - module: flux
    var_name: v_ref
    reduction: none
    kind: r4
EOF

ok(! FREExperiment::_append_yaml($fre, $diag1, $bad_diag, 'diagYaml'), 'dataYaml combining should fail if input is bad');
