#!/bin/bash

# sbconvert.py test script: calculate background on cluster; this
#   script will be qsub'd

# adapted from Mark Bolstad's "mtrax_batch"; removed the xvfb calls
#   since sbconvert doesn't require a screen

# Declare ourselves
>&2 printf "In sbconvert.sh\n"

# Determine the path to this script file, and the folder containing it
BASH_SOURCE_0=${BASH_SOURCE[0]}
>&2 printf "BASH_SOURCE_0: $BASH_SOURCE_0\n"
THIS_SCRIPT_FILE_PATH=$(realpath ${BASH_SOURCE_0})
>&2 printf "THIS_SCRIPT_FILE_PATH: $THIS_SCRIPT_FILE_PATH\n"
SBMOVIE_SUITE_FOLDER_PATH=$(dirname "$THIS_SCRIPT_FILE_PATH")
BOX_ROOT_PATH=$(dirname "$SBMOVIE_SUITE_FOLDER_PATH")
#SCE_PATH="${BOX_ROOT_PATH}/local/SCE"
#>&2 printf "SCE_PATH: $SCE_PATH\n"
#python2_interpreter_path="$BOX_ROOT_PATH/local/python-2.7.11/bin/python"  # used to me /misc/local/old_software/python-2.7.11/bin/python
python2_interpreter_path="$BOX_ROOT_PATH/local/python-2-env/bin/python2"  # used to me /misc/local/old_software/python-2.7.11/bin/python

# # set up the environment
# module use "${SCE_PATH}/SCE/build/COTS"
# module avail
# module load cse-build
# module load cse/ctrax/latest

# # This runs on the flyolympiad VM which has not been upgraded to SL 6.3.  (as of Mar. '13)
# # The current versions of numpy and scipy in the module environment require libraries only available in 6.3 so we need to load older versions.
# module unload cse/numpy/1.6.1
# module load cse/numpy/1.5.0
# module unload cse/scipy/0.10.0
# module load cse/scipy/0.8.0

# call the main script, passing in all command-line parameters
$python2_interpreter_path "$SBMOVIE_SUITE_FOLDER_PATH/sbconvert.py" $*
