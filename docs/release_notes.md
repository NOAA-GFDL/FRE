# Bronx-23 Release Notes

Bronx-23 was released on --------, 2024 to support user management of gaea F5 

## `output.retry` Update
## SRUN Bug Fix
## FRE 2025 pp.starter 
## Refine Diag Options
## NetCDF-4 
## Batch Scheduler Updates
## FRE 2025 / FRE Bronx Integration Update
User can use FRE 2025.01 to create a model container based off of a model, compile, and platform yaml configuration. 

Details on how the yaml framework looks/built can be found here: https://noaa-gfdl.github.io/fre-cli/usage.html#yaml-framework

To build the model container:

1. `module load fre/2025.01`
2. Follow the guide here: https://noaa-gfdl.github.io/fre-cli/usage.html#guide

In order to use the container built (with FRE 2025.01) in a Bronx-23 run, follow these steps:

1. Make sure the created container is in a location accessible by `frerun`
2. Add `<container file="[path/to/container]"/>` under the `experiment name` in an experiment.xml
3. When running `frerun [options]` be sure to add the `--container` option