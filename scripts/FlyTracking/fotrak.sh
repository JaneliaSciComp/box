#!/bin/bash

BASH_SOURCE_0=${BASH_SOURCE[0]}
printf "BASH_SOURCE_0: $BASH_SOURCE_0\n"
THIS_SCRIPT_FILE_PATH=$(realpath ${BASH_SOURCE_0})
printf "THIS_SCRIPT_FILE_PATH: $THIS_SCRIPT_FILE_PATH\n"
FLY_TRACKING_FOLDER_PATH=$(dirname "$THIS_SCRIPT_FILE_PATH")
printf "FLY_TRACKING_FOLDER_PATH: $FLY_TRACKING_FOLDER_PATH\n"
SCRIPTS_FOLDER_PATH=$( dirname "$FLY_TRACKING_FOLDER_PATH" )
printf "SCRIPTS_FOLDER_PATH: $SCRIPTS_FOLDER_PATH\n"
BOX_ROOT_PATH=$( dirname "$SCRIPTS_FOLDER_PATH" )
printf "BOX_ROOT_PATH: $BOX_ROOT_PATH\n"
PIPELINE_ROOT_PATH="$BOX_ROOT_PATH/informatics-pipeline"
#export PATH="$PATH:$PIPELINE_ROOT_PATH/bin:$SCRIPTS_FOLDER_PATH/bin"
pipeline_script_path="$PIPELINE_ROOT_PATH/bin/pipeline"
printf "pipeline_script_path: $pipeline_script_path\n"
perl_interpreter_path="${BOX_ROOT_PATH}/local/python-2-env/bin/perl"
printf "perl_interpreter_path: $perl_interpreter_path\n"

fotrak_dir="$FLY_TRACKING_FOLDER_PATH"
SCRIPTS_FOLDER_PATH="$SCRIPTS_FOLDER_PATH"
avi_sbfmf_dir="$SCRIPTS_FOLDER_PATH"/SBFMFConversion

# Make sure the next folders in the pipeline exist.
mkdir -p "$BOX_ROOT_PATH/01_quarantine_not_compressed"
mkdir -p "$BOX_ROOT_PATH/02_fotracked"

# Make sure each experiment has a "Logs" directory.
# (This normally happens at the transfer step but we're skipping that for re-tracking.)
for exp_name in `ls "$BOX_ROOT_PATH/01_sbfmf_compressed" 2>/dev/null`
do
	mkdir -p "$BOX_ROOT_PATH/01_sbfmf_compressed/$exp_name/Logs"
done

# Make sure the tracking tool has been built.
if [ ! -x "$fotrak_dir/build/distrib/fo_trak" ]
then
    echo "Doing one-time build of fo_trak tool..."
    cd "$fotrak_dir"
    "$fotrak_dir/build_fo_trak.sh"
    sleep 5     # Give the cluster nodes time to see the new file.
    echo "Build complete."
fi

# Now run fotrak on them.
cd "$BOX_ROOT_PATH/01_sbfmf_compressed"
ls -d */*/*sbfmf 2>/dev/null > /tmp/stacks.boxuser_box_fotrak
if [ -s /tmp/stacks.boxuser_box_fotrak ]
then
    # Make sure we're in the directory where this script was run from so the xml, etc. files can be found.
    cd "$fotrak_dir"
    
    "${perl_interpreter_path}" "${pipeline_script_path}" -v -config fotrak.xml -file /tmp/stacks.boxuser_box_fotrak
fi
