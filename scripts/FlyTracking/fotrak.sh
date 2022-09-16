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
export PATH="$PATH:$PIPELINE_ROOT_PATH/bin:$SCRIPTS_FOLDER_PATH/bin"

#fotrak_dir=$(cd "$(dirname "$0")"; pwd)
fotrak_dir="$FLY_TRACKING_FOLDER_PATH"
#pipeline_scripts_dir=$(dirname "$fotrak_dir")
pipeline_scripts_dir="$SCRIPTS_FOLDER_PATH"
pipeline_dir=$("$pipeline_scripts_dir/Tools/pipeline_settings.pl" pipeline_root)
avi_sbfmf_dir="$pipeline_scripts_dir"/SBFMFConversion
do_sage_load=$("$pipeline_scripts_dir/Tools/pipeline_settings.pl" do_sageload_str)

# Make sure the next folders in the pipeline exist.
mkdir -p "$pipeline_dir/01_quarantine_not_compressed"
mkdir -p "$pipeline_dir/02_fotracked"

if [ $do_sage_load = true ]
then
    # All SBFMF jobs have finished, run follow up scripts.
    "$avi_sbfmf_dir/store_sbfmf_stats.pl"
    "$avi_sbfmf_dir/avi_sbfmf_conversion_QC.pl"
fi

# Make sure each experiment has a "Logs" directory.
# (This normally happens at the transfer step but we're skipping that for re-tracking.)
for exp_name in `ls "$pipeline_dir/01_sbfmf_compressed" 2>/dev/null`
do
	mkdir -p "$pipeline_dir/01_sbfmf_compressed/$exp_name/Logs"
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
cd "$pipeline_dir/01_sbfmf_compressed"
ls -d */*/*sbfmf 2>/dev/null > /tmp/stacks.boxuser_box_fotrak
if [ -s /tmp/stacks.boxuser_box_fotrak ]
then
    # Make sure we're in the directory where this script was run from so the xml, etc. files can be found.
    cd "$fotrak_dir"
    
    pipeline -v -config fotrak.xml -file /tmp/stacks.boxuser_box_fotrak
fi
