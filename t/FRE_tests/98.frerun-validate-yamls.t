#!perl
=head1 NAME

99.frerun-validate-yamls.t

=head1 DESCRIPTION

FMS input files (diag, data, fieldtables) were not previously validated
and now they are.

Positive test and negative test for each type.

=cut

use strict;
use warnings FATAL => 'all';
use FREExperiment;
use FREMsg;

# dataYaml examples
my $data_good = <<'EOF';
data_table:
- grid_name: ICE
  fieldname_in_model: sic_obs
  factor: 0.01
  override_file:
  - file_name: INPUT/hadisst_ice.data.nc
    fieldname_in_file: ice
    interp_method: bilinear
- grid_name: ICE
  fieldname_in_model: sit_obs
  factor: 2.0
- grid_name: ICE
  fieldname_in_model: sst_obs
  factor: 1.0
  override_file:
  - file_name: INPUT/hadisst_sst.data.nc
    fieldname_in_file: sst
    interp_method: bilinear
EOF
my $data_bad = <<'EOF';
data_table:
- grid_namename: LND
  fieldname_in_model: phot_co2
  factor:
  override:
  - file_name: INPUT/co2_data.nc
    fieldname_in_file: co2
    interp_method: bilinear
EOF

# fieldYaml examples
my $field_good = <<EOF;
field_table:
- field_type: tracer
  modlist:
  - model_type: atmos_mod
    varlist:
    - variable: sphum
      longname: specific humidity
      units: kg/kg
      profile_type:
      - value: fixed
        surface_value: 3.0e-06
    - variable: liq_wat
      longname: cloud liquid specific humidity
      units: kg/kg
    - variable: ice_wat
      longname: cloud ice water specific humidity
      units: kg/kg
    - variable: radon
      longname: radon-222
      units: VMR*1E21
      profile_type:
      - value: fixed
        surface_value: 0.0
      convection: all
  - model_type: land_mod
    varlist:
    - variable: sphum
      longname: specific humidity
      units: kg/kg
    - variable: co2
      longname: carbon dioxide
      units: kg/kg
EOF
my $field_bad = <<EOF;
field_table:
- field_123123type: tracer
  modlistn:
  - model_type: atmos_mod
    varlist:
        frac_incloud_uw: 0.25
        frac_incloud_donner: 0.25
        alphar: 0.001
        alphas: 0.001
      radiative_param:
      - value: online
        name_in_rad_mod: dust_mode1_of_2
        name_in_clim_mod: small_dust
    - variable: dust2
      longname: dust2 tracer
EOF

my $diag_good = <<EOF;
title: 'name'
base_date: [1, 1, 1, 0, 0, 0]
diag_files:
- file_name: grid_spec
  time_units: days
  unlimdim: time
  freq: -1 months
  varlist:
  - module: dynamics
    var_name: grid_lon
    reduction: none
    kind: r4
  - module: dynamics
    var_name: grid_lat
    reduction: none
    kind: r4
  - module: dynamics
    var_name: grid_lont
    reduction: none
    kind: r4
  - module: dynamics
    var_name: grid_latt
    reduction: none
    kind: r4
  - module: dynamics
    var_name: area
    reduction: none
    kind: r4
  - module: dynamics
    var_name: bk
    reduction: none
    kind: r4
  - module: dynamics
    var_name: pk
    reduction: none
    kind: r4
  - module: flux
    var_name: land_mask
    reduction: none
    kind: r4
  - module: dynamics
    var_name: zsurf
    reduction: none
    kind: r4
- file_name: atmos_month
  time_units: days
  unlimdim: time
  freq: 1 months
  varlist:
  - module: dynamics
    var_name: bk
    reduction: none
    kind: r4
  - module: dynamics
    var_name: pk
    reduction: none
    kind: r4
  - module: flux
    var_name: land_mask
    reduction: none
    kind: r4
  - module: dynamics
    var_name: zsurf
    reduction: none
    kind: r4
  - module: dynamics
    var_name: ps
    reduction: average
    kind: r4
  - module: dynamics
    var_name: temp
    reduction: average
    kind: r4
  - module: dynamics
    var_name: ucomp
    reduction: average
    kind: r4
  - module: dynamics
    var_name: vcomp
    reduction: average
    kind: r4
  - module: dynamics
    var_name: sphum
    reduction: average
    kind: r4
  - module: dynamics
    var_name: cld_amt
    reduction: average
    kind: r4
  - module: dynamics
    var_name: liq_wat
    reduction: average
    kind: r4
  - module: dynamics
    var_name: ice_wat
    reduction: average
    kind: r4
  - module: dynamics
    var_name: liq_drp
    reduction: average
    kind: r4
  - module: dynamics
    var_name: omega
    reduction: average
    kind: r4
  - module: dynamics
    var_name: slp
    output_name: slp_dyn
    reduction: average
    kind: r4
  - module: vert_turb
    var_name: z_full
    reduction: average
    kind: r4
  - module: moist
    var_name: precip
    reduction: average
    kind: r4
  - module: moist
    var_name: prec_conv
    reduction: average
    kind: r4
  - module: moist
    var_name: prec_ls
    reduction: average
    kind: r4
  - module: moist
    var_name: snow_tot
    reduction: average
    kind: r4
  - module: moist
    var_name: snow_conv
    reduction: average
    kind: r4
  - module: moist
    var_name: snow_ls
    reduction: average
    kind: r4
  - module: moist
    var_name: rh
    reduction: average
    kind: r4
  - module: moist
    var_name: WVP
    reduction: average
    kind: r4
  - module: moist
    var_name: LWP
    reduction: average
    kind: r4
  - module: moist
    var_name: IWP
    reduction: average
    kind: r4
  - module: moist
    var_name: WP_all_clouds
    reduction: average
    kind: r4
  - module: moist
    var_name: IWP_all_clouds
    reduction: average
    kind: r4
  - module: moist
    var_name: tot_liq_amt
    reduction: average
    kind: r4
  - module: moist
    var_name: tot_ice_amt
    reduction: average
    kind: r4
  - module: moist
    var_name: mc_full
    reduction: average
    kind: r4
  - module: moist
    var_name: prc_deep_donner
    reduction: average
    kind: r4
  - module: moist
    var_name: prc_mca_donner
    reduction: average
    kind: r4
  - module: moist
    var_name: uw_precip
    reduction: average
    kind: r4
  - module: moist
    var_name: enth_ls_col
    reduction: average
    kind: r4
  - module: moist
    var_name: enth_uw_col
    reduction: average
    kind: r4
  - module: moist
    var_name: enth_conv_col
    reduction: average
    kind: r4
  - module: moist
    var_name: enth_donner_col
    reduction: average
    kind: r4
  - module: moist
    var_name: wat_ls_col
    reduction: average
    kind: r4
  - module: moist
    var_name: wat_uw_col
    reduction: average
    kind: r4
  - module: moist
    var_name: wat_conv_col
    reduction: average
    kind: r4
  - module: moist
    var_name: wat_donner_col
    reduction: average
    kind: r4
- file_name: atmos_scalar
  time_units: days
  unlimdim: time
  freq: 1 months
  varlist:
  - module: radiation
    var_name: rrvco2
    reduction: average
    kind: r4
  - module: radiation
    var_name: rrvch4
    reduction: average
    kind: r4
  - module: radiation
    var_name: rrvn2o
    reduction: average
    kind: r4
  - module: radiation
    var_name: rrvf11
    reduction: average
    kind: r4
  - module: radiation
    var_name: rrvf12
    reduction: average
    kind: r4
  - module: radiation
    var_name: rrvf113
    reduction: average
    kind: r4
  - module: radiation
    var_name: rrvf22
    reduction: average
    kind: r4
  - module: radiation
    var_name: solar_constant
    reduction: average
    kind: r4
  - module: tracers
    var_name: ch4_lbc
    output_name: CH4_lbc
    reduction: average
    kind: r4
  - module: tracers
    var_name: n2o_lbc
    output_name: N2O_lbc
    reduction: average
    kind: r4
- file_name: atmos_diurnal
  time_units: days
  unlimdim: time
  freq: 1 months
  varlist:
  - module: flux
    var_name: land_mask
    reduction: none
    kind: r4
  - module: dynamics
    var_name: zsurf
    reduction: none
    kind: r4
  - module: flux
    var_name: t_ref
    reduction: diurnal24
    kind: r4
  - module: flux
    var_name: evap
    reduction: diurnal24
    kind: r4
  - module: flux
    var_name: shflx
    reduction: diurnal24
    kind: r4
  - module: vert_turb
    var_name: z_Ri_025
    reduction: diurnal24
    kind: r4
  - module: moist
    var_name: precip
    reduction: diurnal24
    kind: r4
  - module: moist
    var_name: prec_conv
    reduction: diurnal24
    kind: r4
EOF
my $diag_bad = <<EOF;
diag_files:
- file_name: land_static
  time_units: days
  unlimdim: time
  freq: -1 months
  varlist:
  - module: land
    var_name: dummy_lon
    reduction: none
    kind: r8
  - module: land
    var_name: dummy_lat
    reduction: none
    kind: r8
  - module: land
    var_name: geolon_t
    reduction: none
    kind: r8
  - module: land
    var_name: geolat_t
    reduction: none
    kind: r8
  - module: lake
    var_name: lake_depth
    reduction: none
    kind: r4
  - module: lake
    var_name: lake_width
    reduction: none
    kind: r4
  - module: land
    var_name: area_land
    output_name: land_area
    reduction: none
    kind: r4
  - module: land
    var_name: area_lake
    output_name: lake_area
    reduction: none
    kind: r4
  - module: land
    var_name: area_soil
    output_name: soil_area
    reduction: none
    kind: r4
  - module: land
    var_name: land_frac
    reduction: none
    kind: r4
  - module: land
    var_name: area_glac
    output_name: glac_area
    reduction: none
    kind: r4
  - module: land
    var_name: frac_soil
    reduction: none
    kind: r4
  - module: soil
    var_name: soil_Ksat
    reduction: none
    kind: r4
  - module: soil
    var_name: soil_rlief
    reduction: none
    kind: r4
  - module: soil
    var_name: soil_sat
    reduction: none
    kind: r4
  - module: soil
    var_name: soil_type
    reduction: none
    kind: r4
  - module: soil
    var_name: soil_wilt
    reduction: none
    kind: r4
- file_name: land_month
  time_units: days
  unlimdim: time
  freq: 1 months
  varlist:
  - module: land
    var_name: dummy_lon
    reduction: none
    kind: r8
  - module: land
    var_name: dummy_lat
    reduction: none
    kind: r8
  - module: land
    var_name: geolon_t
    reduction: none
    kind: r8
  - module: land
    var_name: geolat_t
    reduction: none
    kind: r8
  - module: land
    var_name: frac_glac
    reduction: average
    kind: r4
  - module: land
    var_name: frac_lake
    reduction: average
    kind: r4
  - module: land
    var_name: area_ntrl
    reduction: average
    kind: r4
  - module: glacier
    var_name: glac_T
    reduction: average
    kind: r4
  - module: lake
    var_name: lake_dz
    reduction: average
    kind: r4
  - module: lake
    var_name: lake_K_z
    reduction: average
    kind: r4
  - module: lake
    var_name: lake_T
    reduction: average
    kind: r4
  - module: lake
    var_name: lake_wl
    reduction: average
    kind: r4
  - module: lake
    var_name: lake_ws
    reduction: average
    kind: r4
  - module: soil
    var_name: soil_ice
    reduction: average
    kind: r4
  - module: soil
    var_name: soil_liq
    reduction: average
    kind: r4
  - module: soil
    var_name: soil_psi
    reduction: average
    kind: r4
  - module: soil
    var_name: soil_T
    reduction: average
    kind: r4
  - module: soil
    var_name: soil_uptk
    reduction: average
    kind: r4
  - module: soil
    var_name: soil_uptk_ntrl
    reduction: average
    kind: r4
EOF
my $diag_bad2 = <<EOF;
title: ''
base_date: ''
diag_files:
- file_name: grid_spec
  time_units: days
  unlimdim: time
  freq: -1 months
  varlist:
  - module: dynamics
    var_name: grid_lon
    reduction: none
    kind: r4
  - module: dynamics
    var_name: grid_lat
    reduction: none
    kind: r4
  - module: dynamics
    var_name: grid_lont
    reduction: none
    kind: r4
  - module: dynamics
    var_name: grid_latt
    reduction: none
    kind: r4
  - module: dynamics
    var_name: area
    reduction: none
    kind: r4
  - module: dynamics
    var_name: bk
    reduction: none
    kind: r4
  - module: dynamics
    var_name: pk
    reduction: none
    kind: r4
  - module: flux
    var_name: land_mask
    reduction: none
    kind: r4
  - module: dynamics
    var_name: zsurf
    reduction: none
    kind: r4
- file_name: atmos_month
  time_units: days
  unlimdim: time
  freq: 1 months
  varlist:
  - module: dynamics
    var_name: bk
    reduction: none
    kind: r4
  - module: dynamics
    var_name: pk
    reduction: none
    kind: r4
  - module: flux
    var_name: land_mask
    reduction: none
    kind: r4
  - module: dynamics
    var_name: zsurf
    reduction: none
    kind: r4
  - module: dynamics
    var_name: ps
    reduction: average
    kind: r4
  - module: dynamics
    var_name: temp
    reduction: average
    kind: r4
  - module: dynamics
    var_name: ucomp
    reduction: average
    kind: r4
  - module: dynamics
    var_name: vcomp
    reduction: average
    kind: r4
  - module: dynamics
    var_name: sphum
    reduction: average
    kind: r4
  - module: dynamics
    var_name: cld_amt
    reduction: average
    kind: r4
  - module: dynamics
    var_name: liq_wat
    reduction: average
    kind: r4
  - module: dynamics
    var_name: ice_wat
    reduction: average
    kind: r4
  - module: dynamics
    var_name: liq_drp
    reduction: average
    kind: r4
  - module: dynamics
    var_name: omega
    reduction: average
    kind: r4
  - module: dynamics
    var_name: slp
    output_name: slp_dyn
    reduction: average
    kind: r4
  - module: vert_turb
    var_name: z_full
    reduction: average
    kind: r4
  - module: moist
    var_name: precip
    reduction: average
    kind: r4
  - module: moist
    var_name: prec_conv
    reduction: average
    kind: r4
  - module: moist
    var_name: prec_ls
    reduction: average
    kind: r4
  - module: moist
    var_name: snow_tot
    reduction: average
    kind: r4
  - module: moist
    var_name: snow_conv
    reduction: average
    kind: r4
  - module: moist
    var_name: snow_ls
    reduction: average
    kind: r4
  - module: moist
    var_name: rh
    reduction: average
    kind: r4
  - module: moist
    var_name: WVP
    reduction: average
    kind: r4
  - module: moist
    var_name: LWP
    reduction: average
    kind: r4
  - module: moist
    var_name: IWP
    reduction: average
    kind: r4
  - module: moist
    var_name: WP_all_clouds
    reduction: average
    kind: r4
  - module: moist
    var_name: IWP_all_clouds
    reduction: average
    kind: r4
  - module: moist
    var_name: tot_liq_amt
    reduction: average
    kind: r4
  - module: moist
    var_name: tot_ice_amt
    reduction: average
    kind: r4
  - module: moist
    var_name: mc_full
    reduction: average
    kind: r4
  - module: moist
    var_name: prc_deep_donner
    reduction: average
    kind: r4
  - module: moist
    var_name: prc_mca_donner
    reduction: average
    kind: r4
  - module: moist
    var_name: uw_precip
    reduction: average
    kind: r4
  - module: moist
    var_name: enth_ls_col
    reduction: average
    kind: r4
  - module: moist
    var_name: enth_uw_col
    reduction: average
    kind: r4
  - module: moist
    var_name: enth_conv_col
    reduction: average
    kind: r4
  - module: moist
    var_name: enth_donner_col
    reduction: average
    kind: r4
  - module: moist
    var_name: wat_ls_col
    reduction: average
    kind: r4
  - module: moist
    var_name: wat_uw_col
    reduction: average
    kind: r4
  - module: moist
    var_name: wat_conv_col
    reduction: average
    kind: r4
  - module: moist
    var_name: wat_donner_col
    reduction: average
    kind: r4
- file_name: atmos_scalar
  time_units: days
  unlimdim: time
  freq: 1 months
  varlist:
  - module: radiation
    var_name: rrvco2
    reduction: average
    kind: r4
  - module: radiation
    var_name: rrvch4
    reduction: average
    kind: r4
  - module: radiation
    var_name: rrvn2o
    reduction: average
    kind: r4
  - module: radiation
    var_name: rrvf11
    reduction: average
    kind: r4
  - module: radiation
    var_name: rrvf12
    reduction: average
    kind: r4
  - module: radiation
    var_name: rrvf113
    reduction: average
    kind: r4
  - module: radiation
    var_name: rrvf22
    reduction: average
    kind: r4
  - module: radiation
    var_name: solar_constant
    reduction: average
    kind: r4
  - module: tracers
    var_name: ch4_lbc
    output_name: CH4_lbc
    reduction: average
    kind: r4
  - module: tracers
    var_name: n2o_lbc
    output_name: N2O_lbc
    reduction: average
    kind: r4
- file_name: atmos_diurnal
  time_units: days
  unlimdim: time
  freq: 1 months
  varlist:
  - module: flux
    var_name: land_mask
    reduction: none
    kind: r4
  - module: dynamics
    var_name: zsurf
    reduction: none
    kind: r4
  - module: flux
    var_name: t_ref
    reduction: diurnal24
    kind: r4
  - module: flux
    var_name: evap
    reduction: diurnal24
    kind: r4
  - module: flux
    var_name: shflx
    reduction: diurnal24
    kind: r4
  - module: vert_turb
    var_name: z_Ri_025
    reduction: diurnal24
    kind: r4
  - module: moist
    var_name: precip
    reduction: diurnal24
    kind: r4
  - module: moist
    var_name: prec_conv
    reduction: diurnal24
    kind: r4
- file_name: land_static
  time_units: days
  unlimdim: time
  freq: -1 months
  varlist:
  - module: land
    var_name: dummy_lon
    reduction: none
    kind: r8
  - module: land
    var_name: dummy_lat
    reduction: none
    kind: r8
  - module: land
    var_name: geolon_t
    reduction: none
    kind: r8
  - module: land
    var_name: geolat_t
    reduction: none
    kind: r8
  - module: lake
    var_name: lake_depth
    reduction: none
    kind: r4
  - module: lake
    var_name: lake_width
    reduction: none
    kind: r4
  - module: land
    var_name: area_land
    output_name: land_area
    reduction: none
    kind: r4
  - module: land
    var_name: area_lake
    output_name: lake_area
    reduction: none
    kind: r4
  - module: land
    var_name: area_soil
    output_name: soil_area
    reduction: none
    kind: r4
  - module: land
    var_name: land_frac
    reduction: none
    kind: r4
  - module: land
    var_name: area_glac
    output_name: glac_area
    reduction: none
    kind: r4
  - module: land
    var_name: frac_soil
    reduction: none
    kind: r4
  - module: soil
    var_name: soil_Ksat
    reduction: none
    kind: r4
  - module: soil
    var_name: soil_rlief
    reduction: none
    kind: r4
  - module: soil
    var_name: soil_sat
    reduction: none
    kind: r4
  - module: soil
    var_name: soil_type
    reduction: none
    kind: r4
  - module: soil
    var_name: soil_wilt
    reduction: none
    kind: r4
- file_name: land_month
  time_units: days
  unlimdim: time
  freq: 1 months
  varlist:
  - module: land
    var_name: dummy_lon
    reduction: none
    kind: r8
  - module: land
    var_name: dummy_lat
    reduction: none
    kind: r8
  - module: land
    var_name: geolon_t
    reduction: none
    kind: r8
  - module: land
    var_name: geolat_t
    reduction: none
    kind: r8
  - module: land
    var_name: frac_glac
    reduction: average
    kind: r4
  - module: land
    var_name: frac_lake
    reduction: average
    kind: r4
  - module: land
    var_name: area_ntrl
    reduction: average
    kind: r4
  - module: glacier
    var_name: glac_T
    reduction: average
    kind: r4
  - module: lake
    var_name: lake_dz
    reduction: average
    kind: r4
  - module: lake
    var_name: lake_K_z
    reduction: average
    kind: r4
  - module: lake
    var_name: lake_T
    reduction: average
    kind: r4
  - module: lake
    var_name: lake_wl
    reduction: average
    kind: r4
  - module: lake
    var_name: lake_ws
    reduction: average
    kind: r4
  - module: soil
    var_name: soil_ice
    reduction: average
    kind: r4
  - module: soil
    var_name: soil_liq
    reduction: average
    kind: r4
  - module: soil
    var_name: soil_psi
    reduction: average
    kind: r4
  - module: soil
    var_name: soil_T
    reduction: average
    kind: r4
  - module: soil
    var_name: soil_uptk
    reduction: average
    kind: r4
  - module: soil
    var_name: soil_uptk_ntrl
    reduction: average
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
    my $verbose = 1;
    FREMsg::out( $verbose, shift, @_ );
}
my $fre = FRE->new();

use Test::More tests => 7;

# validate good yamls
ok(FREExperiment::validateYaml($fre, $data_good, 'dataYaml'), "good datayaml");
ok(FREExperiment::validateYaml($fre, $field_good, 'fieldYaml', 1), "good fieldyaml");
ok(FREExperiment::validateYaml($fre, $diag_good, 'diagYaml', 1), "good diagyaml");

# validate bad yamls
ok(! FREExperiment::validateYaml($fre, $data_bad, 'dataYaml', 1), 'bad datayaml');
ok(! FREExperiment::validateYaml($fre, $field_bad, 'fieldYaml', 1), 'bad fieldyaml');
ok(! FREExperiment::validateYaml($fre, $diag_bad, 'diagYaml', 1), 'bad diagyaml');
ok(! FREExperiment::validateYaml($fre, $diag_bad2, 'diagYaml', 1), 'another bad diagyaml');
