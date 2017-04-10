module use -a /home/fms/local/modulefiles
module use /home/sdu/publicmodules

module unload netcdf netcdf-fortran intel_compilers mpich mpich2
module load netcdf/4.3.2
module load netcdf-fortran/4.4.1
module load mpich/3.1.3

setenv OMP_STACKSIZE 512m
setenv NC_BLKSZ 1M
# MAIN_PROGRAM env is needed by the GNU compiler
setenv MAIN_PROGRAM coupler/coupler_main.o
