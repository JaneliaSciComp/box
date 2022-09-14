#!/bin/bash
#. /misc/lsf/conf/profile.lsf
#source /misc/local/SOURCEME
#export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/misc/local/matlab-2013a/bin/glnxa64"

BASH_SOURCE_0=${BASH_SOURCE[0]}
printf "BASH_SOURCE_0: $BASH_SOURCE_0\n"
SCRIPT_FILE_PATH=$(realpath ${BASH_SOURCE[0]})
printf "SCRIPT_FILE_PATH: $SCRIPT_FILE_PATH\n"
SCRIPT_FOLDER_PATH=$(dirname "$SCRIPT_FILE_PATH")
printf "SCRIPT_FOLDER_PATH: $SCRIPT_FOLDER_PATH\n"
SCRIPTS_FOLDER_PATH=$( dirname "$SCRIPT_FOLDER_PATH" )
printf "SCRIPTS_FOLDER_PATH: $SCRIPTS_FOLDER_PATH\n"
export PATH="$PATH:/misc/sc/pipeline/bin:$SCRIPTS_FOLDER_PATH/bin"
#source "$SCRIPTS_FOLDER_PATH/SOURCEME"

fotrak_dir=$(cd "$(dirname "$0")"; pwd)
pipeline_scripts_dir=$(dirname "$fotrak_dir")
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
