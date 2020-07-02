#!/bin/bash
#
#SBATCH -n 8
#SBATCH --output=comp_MESHER.out
#SBATCH --error=comp_MESHER.err
#
module purge
#
module load intel/19
COMP=intel19
##
#module load gnu/8
#COMP=gnu8
#module load openblas
#
module load openmpi_3/
MPI=openmpi3
#
#module load mpich/3.3.1
#MPI=mpich3

#module load impi_19/
#MPI=impi19
#
COMP_MPI=${COMP}_${MPI}
#COMP_MPI=${COMP}
#
module load netcdf/
module load netcdf-fortran/
module load netcdf-cxx/
#
# Some updated utiities (cmake is probably required).
module load git/
module load cmake
module load autotools

#module load anaconda/anaconda3
#module load anaconda/anaconda2
#
# build environment, source info:
ROOT_DIR=`pwd`
SRC_PATH="${ROOT_DIR}"
SRC_GIT="git@github.com:geodynamics/axisem.git"
BUILD_DIR=${SRC_PATH}/build_${COMP_MPI}
#
# guessing at version. latest tag is 1.2; release branches for 1.3, 1.4, but i'm guessing master is a variant of 1.2
VER="1.2.1"
TARGET_PATH_SW="${SCRATCH}/.local/software/axisem"
TARGET_PATH_MODULE="${SCRATCH}/.local/modules/moduledeps/${COMP}-${MPI}/axisem"
#
# if being called by SLURM, we'll use the SLURM variable for N_COMPILE_TASKS. else, set it.
if [ -z "${SLURM_NTASKS}" ]
then
      #echo "\$var is empty"
      N_COMPILE_TASKS=8
else
      #echo "\$var is NOT empty"
      N_COMPILE_TASKS=${SLURM_NTASKS}
fi
echo "** Compiling with ${N_COMPILE_TASKS} "
echo "*** MPI_DIR: ${MPI_DIR}"
echo "*** NetCDF: $NETCDF_DIR, $NETCDF_INC, $NETCDF_LIB"
echo "***"
echo "***"
#
# some env variables:
export CPATH=${MPI_DIR}/include:${INCLUDE}:${CPATH}
#
# compiler variables should be easy and standard, but they're not, so double-check if necessary. These variables should be
#  set by the module script if you use the /share module dependencies (aka, intel/19, gnu/8, openmmpi_3/, impi_19/, etc.)
#  Note: for fortran programs. sometimnes we need to set LD=$FC, insted of the CC or CXX default (which i don't recall right now.)
# For example, I think for impi, MPICC=mpiicc
#export MPICC=${MPI_DIR}/bin/mpicc
#export MPICXX=${MPI_DIR}/bin/mpicxx
#export MPIFC=${MPI_DIR}/bin/mpifort
#export MPIF77=$MPIFC
#export MPIF90=$MPIFC
export LD=$FC
#
echo "Some MPI vars: ${MPI_DIR}, ${MPICC}, ${MPICXX}, ${MPIFC} "
echo "***"
echo "***"
#
# Do we have the source? Note we can add more bit here to
if [ -d "${SRC_PATH}"  ]; then
    echo "Source exists: ${SRC_PATH}"
else
    echo "Source does not exist. Cloning from github. This might take a while..."
    #git clone --recursive git@github.com:trilinos/Trilinos.git
    #
    git clone ${SRC_GIT}
    #
fi
#
if [[ ! -d ${TARGET_PATH_SW} ]]; then
    mkdir -p ${TARGET_PATH_SW}
fi
#
# we can either set some of these variables as environment variables (which i find to be inconsistent), -D Cmake variables, or
#  leading Cmake variables.
CMAKE_MODULE_PATH="${SCRATCH}/Downloads/cmake-modules"
export CMAKE_MODULE_PATH="${CMAKE_MODULE_PATH}"
C_FLAGS="-fpic "
C_MAKE_FLAGS=" -DUSE_NETCDF=true -DUSE_PAR_NETCDF=true -DNETCDF_INCLUDES=${NETCDF_INC};${NETCDF_FORTRAN_INC} -DCMAKE_MODULE_PATH=${CMAKE_MODULE_PATH} "
C_MAKE_FLAGS=" -DNetCDF_lib_dirs=${NETCDF_LIB};${NETCDF_FORTRAN_LIB} -DNETCDF_DIR=${NETCDF_DIR};${NETCDF_FORTRAN_DIR} ${C_MAKE_FLAGS}"
# -DNETCDF_LIBRARIES=${NETCDF_LIB}:${NETCDF_FORTRAN_LIB}
# -DMPI_C=${MPI_DIR}/lib/libmpi.so
LDFLAGS="`nc-config --flibs`"

#export PATH=${NETCDF_FORTRAN_LIB}:${NETCDF_FORTRAN_INC}:${PATH}
#
export CMAKE_PREFIX_PATH="${NETCDF_DIR};${NETCDF_FORTRAN_DIR};${NETCDF_LIB};${NETCDF_FORTRAN_LIB};${NETCDF_INC};${NETCDF_FORTRAN_INC};${MPI_DIR};${MPI_DIR}/lib;${MPI_DIR}/lib"
#
# looks like Cmake should find NetCDF via the paths?
rm -rf ${BUILD_DIR}
mkdir -p ${BUILD_DIR}
cd ${BUILD_DIR}
#
echo "Cmaking: "
echo "SRC: ${SRC_PATH}"
echo "BUILD: ${BUILD_DIR} :: `pwd` "
echo "C_FLAGS: ${C_FLAGS}"
echo "C_MAKE_FLAGS: ${C_MAKE_FLAGS}"
echo "Target: ${TARGET_PATH_SW} "
echo "CMAKE_MOD: ${CMAKE_MODULE_PATH}"
echo "CMAKE_PREFIX_PATH: ${CMAKE_PREFIX_PATH}"
echo "LDFLAGS: ${LDFLAGS}"
echo "** DEBUG: `ls ${CMAKE_MODULE_PATH}/FindNetCDF.cmake` **"
ls ${CMAKE_MODULE_PATH}/FindNetCDF.cmake

CC=${CC} CXX=${CXX} FC=${FC} MPI_CC=${MPICC} MPI_FC=${MPIFC} MPI_CXX=${MPI_DIR}/bin/${MPICXX} LD=${FC} LDFLAGS=${LDFLAGS} CMAKE_PREFIX_PATH=${CMAKE_PREFIX_PATH} CMAKE_MODULE_PATH=${CMAKE_MODULE_PATH} cmake -DCMAKE_INSTALL_PREFIX=${TARGET_PATH_SW} -DCMAKE_C_FLAGS=${C_FLAGS} ${CMAKE_FLAGS} ${SRC_PATH}
#
#exit 1
#if [[ ! $? -eq 0 ]]; then
#    echo "Cmake problem. Exiting."
#    exit 1
#fi
#
make clean
#make -j ${N_COMPILE_TASKS}
make -j 1
#
# make instll does not seem to be working. I though cmake would build it, but seems not so...
# so we'll try again, or just write some copy commands here:


if [[ ! $? -eq 0 ]]; then
    exit 1
fi

make install
#
# now, write module file:


