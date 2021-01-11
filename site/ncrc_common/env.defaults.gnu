module unload cray-netcdf cray-hdf5 fre
module unload PrgEnv-pgi PrgEnv-intel PrgEnv-gnu PrgEnv-cray
module load PrgEnv-gnu/6.0.5
module unload gcc
module load gcc/$(COMPILER_VERSION)
module load fre/$(FRE_VERSION)
module load cray-hdf5/1.10.5.2
module load git

setenv KMP_STACKSIZE 512m
setenv NC_BLKSZ 1M
setenv F_UFMTENDIAN big
# MAIN_PROGRAM env is needed by the GNU compiler
setenv MAIN_PROGRAM coupler/coupler_main.o
