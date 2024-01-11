## fms-yaml-tools used by Bronx-21+
Bronx-21 relies on 3 external tools to combine FMS YAML input files:
combine-data-table-yamls, combine-diag-table-yamls, and combine-field-table-yamls.
They are exercised in the 98.frerun-combine-yamls.t test. Additionally,
3 related conversion tools are included in the PATH for user convenience
but are not used or tested by FRE.

The tools are maintained on github (https://github.com/NOAA-GFDL/fms_yaml_tools),
and can be most easily installed via pip.

## fms-yaml-tool installation locations
We decided to install the fms-yaml-tools via pip as the fms user,
on gaea and GFDL, and include 6 site-specific symlinks from the installed
location and the fre-commands site bin directory.
- on gaea, /ncrc/home2/fms/local/opt/fms-yaml-tools/(prod|test)/bin
- at GFDL,       /home/fms/local/opt/fms-yaml-tools/(prod|test)/bin

Production versions of Bronx will use the "prod" set, and fre/test can use the "test" set.

## How to install (as the fms user)

Installing the tools, 3 steps:

1. Create an isolated virtual python environment using system python3

python3 -m venv /home/fms/local/opt/fms-yaml-tools/prod

2. Activate the isolated virtual python

source /home/fms/local/opt/fms-yaml-tools/prod/bin/activate.csh

3. Install/update the fms-yaml-tools

git clone https://github.com/NOAA-GFDL/fms_yaml_tools.git src

cd src

pip install --upgrade pip

pip install .
