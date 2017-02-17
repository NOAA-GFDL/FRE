source $MODULESHOME/init/csh

module use -a /ncrc/home2/fms/local/modulefiles
module unload PrgEnv-pgi PrgEnv-intel PrgEnv-gnu PrgEnv-cray
module unload netcdf cray-netcdf cray-hdf5 fre
module load PrgEnv-gnu/5.2.82
module swap gcc gcc/$(COMPILER_VERSION)
module load fre/$(FRE_VERSION)
module load cray-hdf5/1.8.16
module load git

setenv KMP_STACKSIZE 512m
setenv NC_BLKSZ 1M
setenv F_UFMTENDIAN big
# MAIN_PROGRAM env is needed by the GNU compiler
setenv MAIN_PROGRAM coupler/coupler_main.o
