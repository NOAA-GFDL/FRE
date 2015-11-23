source $MODULESHOME/init/csh
 
module use -a /ncrc/home2/fms/local/modulefiles
module unload PrgEnv-pgi PrgEnv-pathscale PrgEnv-intel PrgEnv-gnu PrgEnv-cray
module unload netcdf fre
if (`hostname` =~ gaea[1234]) then
    module load PrgEnv-gnu/4.0.46
else
    module load PrgEnv-gnu/5.2.40
endif
module load $(FRE_VERSION)
module load git
 
setenv KMP_STACKSIZE 512m
setenv NC_BLKSZ 1M
setenv F_UFMTENDIAN big
# MAIN_PROGRAM env is needed by the GNU compiler
setenv MAIN_PROGRAM coupler/coupler_main.o
