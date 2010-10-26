#!/bin/csh -f
#PBS -l partition=noaa
#PBS -N frepptest
#PBS -l size=2
#PBS -l walltime=00:10:00
#PBS -q ic10.a
#PBS -o $HOME/qinfo4fre

source /opt/modules/default/init/tcsh
module purge

