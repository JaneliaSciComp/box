#!/bin/bash

# sbconvert.py test script: calculate background on cluster; this
#   script will be qsub'd

# adapted from Mark Bolstad's "mtrax_batch"; removed the xvfb calls
#   since sbconvert doesn't require a screen

# set up the environment
#source /misc/local/SCE/SCE/build/Modules-3.2.6/Modules/3.2.6/init/tcsh
module use /misc/local/SCE/SCE/build/COTS
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
BASH_SOURCE_0=${BASH_SOURCE[0]}
printf "BASH_SOURCE_0: $BASH_SOURCE_0\n"
SCRIPT_FILE_PATH=$(realpath ${BASH_SOURCE[0]})
printf "SCRIPT_FILE_PATH: $SCRIPT_FILE_PATH\n"
SCRIPT_FOLDER_PATH=$(dirname "$SCRIPT_FILE_PATH")
python $SCRIPT_FOLDER_PATH/sbconvert.py $*
