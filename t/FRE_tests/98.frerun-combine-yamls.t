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
my $data2 = <<'EOF';
data_table:
- grid_name: LND
  fieldname_in_model: phot_co2
  factor: 1.0e-06
  override_file:
  - file_name: INPUT/co2_data.nc
    fieldname_in_file: co2
    interp_method: bilinear
EOF
my $data3 = <<EOF;
data_table:
- factor: 0.01
  fieldname_in_model: sic_obs
  grid_name: ICE
  override_file:
  - fieldname_in_file: ice
    file_name: INPUT/hadisst_ice.data.nc
    interp_method: bilinear
- factor: 2.0
  fieldname_in_model: sit_obs
  grid_name: ICE
- factor: 1.0
  fieldname_in_model: sst_obs
  grid_name: ICE
  override_file:
  - fieldname_in_file: sst
    file_name: INPUT/hadisst_sst.data.nc
    interp_method: bilinear
- factor: 1.0e-06
  fieldname_in_model: phot_co2
  grid_name: LND
  override_file:
  - fieldname_in_file: co2
    file_name: INPUT/co2_data.nc
    interp_method: bilinear
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
my $field2 = <<EOF;
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
    - variable: cld_amt
      longname: cloud fraction
      units: none
    - variable: liq_drp
      longname: cloud droplet
      units: none
    - variable: dust1
      longname: dust1 tracer
      units: mmr
      profile_type:
      - value: fixed
        surface_value: 1.0e-32
      parameters:
      - value: all
        ra: 1.0e-07
        rb: 1.25e-06
        dustref: 7.5e-07
        dustden: 2500.0
      emission:
      - value: prescribed
        source_fraction: 0.11
      convection: all
      dry_deposition:
      - value: wind_driven
        surfr: 100.0
      wet_deposition:
      - value: aerosol_below
        frac_incloud: 0.15
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
      units: mmr
      profile_type:
      - value: fixed
        surface_value: 1.0e-32
      parameters:
      - value: all
        ra: 1.25e-06
        rb: 5.0e-06
        dustref: 2.15e-06
        dustden: 2650.0
      emission:
      - value: prescribed
        source_fraction: 0.89
      convection: all
      dry_deposition:
      - value: wind_driven
        surfr: 100.0
      wet_deposition:
      - value: aerosol_below
        frac_incloud: 0.15
        frac_incloud_uw: 0.25
        frac_incloud_donner: 0.25
        alphar: 0.001
        alphas: 0.001
      radiative_param:
      - value: online
        name_in_rad_mod: dust_mode2_of_2
        name_in_clim_mod: large_dust
  - model_type: land_mod
    varlist:
    - variable: sphum
      longname: specific humidity
      units: kg/kg
    - variable: co2
      longname: carbon dioxide
      units: kg/kg
EOF
my $field3 = <<EOF;
field_table:
- field_type: tracer
  modlist:
  - model_type: atmos_mod
    varlist:
    - longname: specific humidity
      profile_type:
      - surface_value: 3.0e-06
        value: fixed
      units: kg/kg
      variable: sphum
    - longname: cloud liquid specific humidity
      units: kg/kg
      variable: liq_wat
    - longname: cloud ice water specific humidity
      units: kg/kg
      variable: ice_wat
    - convection: all
      longname: radon-222
      profile_type:
      - surface_value: 0.0
        value: fixed
      units: VMR*1E21
      variable: radon
    - longname: cloud fraction
      units: none
      variable: cld_amt
    - longname: cloud droplet
      units: none
      variable: liq_drp
    - convection: all
      dry_deposition:
      - surfr: 100.0
        value: wind_driven
      emission:
      - source_fraction: 0.11
        value: prescribed
      longname: dust1 tracer
      parameters:
      - dustden: 2500.0
        dustref: 7.5e-07
        ra: 1.0e-07
        rb: 1.25e-06
        value: all
      profile_type:
      - surface_value: 1.0e-32
        value: fixed
      radiative_param:
      - name_in_clim_mod: small_dust
        name_in_rad_mod: dust_mode1_of_2
        value: online
      units: mmr
      variable: dust1
      wet_deposition:
      - alphar: 0.001
        alphas: 0.001
        frac_incloud: 0.15
        frac_incloud_donner: 0.25
        frac_incloud_uw: 0.25
        value: aerosol_below
    - convection: all
      dry_deposition:
      - surfr: 100.0
        value: wind_driven
      emission:
      - source_fraction: 0.89
        value: prescribed
      longname: dust2 tracer
      parameters:
      - dustden: 2650.0
        dustref: 2.15e-06
        ra: 1.25e-06
        rb: 5.0e-06
        value: all
      profile_type:
      - surface_value: 1.0e-32
        value: fixed
      radiative_param:
      - name_in_clim_mod: large_dust
        name_in_rad_mod: dust_mode2_of_2
        value: online
      units: mmr
      variable: dust2
      wet_deposition:
      - alphar: 0.001
        alphas: 0.001
        frac_incloud: 0.15
        frac_incloud_donner: 0.25
        frac_incloud_uw: 0.25
        value: aerosol_below
  - model_type: land_mod
    varlist:
    - longname: specific humidity
      units: kg/kg
      variable: sphum
    - longname: carbon dioxide
      units: kg/kg
      variable: co2
EOF

my $diag1 = <<EOF;
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
my $diag2 = <<EOF;
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
my $diag3 = <<EOF;
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
    my $verbose = 0;
    FREMsg::out( $verbose, shift, @_ );
}
my $fre = FRE->new();

# run the 4 tests
use Test::More tests => 3;

# remove newlines from reference output
chomp $data3;
chomp $field3;
chomp $diag3;

# combine and compare
is(FREExperiment::_append_yaml($fre, $data1, $data2, 'dataYaml'), $data3, "combine two dataYamls and verify output");
is(FREExperiment::_append_yaml($fre, $field1, $field2, 'fieldYaml'), $field3, "combine two fieldYamls and verify output");
is(FREExperiment::_append_yaml($fre, $diag1, $diag2, 'diagYaml'), $diag3, "combine two diagYamls and verify output");
