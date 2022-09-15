#!/bin/bash

# sbconvert.py test script: calculate background on cluster; this
#   script will be qsub'd

# adapted from Mark Bolstad's "mtrax_batch"; removed the xvfb calls
#   since sbconvert doesn't require a screen

# Determine the path to this script file, and the folder containing it
BASH_SOURCE_0=${BASH_SOURCE[0]}
printf "BASH_SOURCE_0: $BASH_SOURCE_0\n"
SCRIPT_FILE_PATH=$(realpath ${BASH_SOURCE[0]})
printf "SCRIPT_FILE_PATH: $SCRIPT_FILE_PATH\n"
SCRIPT_FOLDER_PATH=$(dirname "$SCRIPT_FILE_PATH")

SCE_RAW_PATH="${SCRIPT_FOLDER_PATH}/../local/SCE"
SCE_PATH=$(realpath ${SCE_RAW_PATH})
printf "SCE_PATH: $SCE_PATH\n"

# set up the environment
#module use /misc/local/SCE/SCE/build/COTS
module use "${SCE_PATH}/SCE/build/COTS"
module avail
module load cse-build
module load cse/ctrax/latest

# This runs on the flyolympiad VM which has not been upgraded to SL 6.3.  (as of Mar. '13)
# The current versions of numpy and scipy in the module environment require libraries only available in 6.3 so we need to load older versions.
module unload cse/numpy/1.6.1
module load cse/numpy/1.5.0
module unload cse/scipy/0.10.0
module load cse/scipy/0.8.0

# call the main script, passing in all command-line parameters
python2 $SCRIPT_FOLDER_PATH/sbconvert.py $*
