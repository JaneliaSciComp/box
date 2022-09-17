#!/bin/bash
. /misc/lsf/conf/profile.lsf
source /misc/local/SOURCEME

merge_dir=$(cd "$(dirname "$0")"; pwd)
pipeline_scripts_dir=$(dirname "$merge_dir")
pipeline_dir=$("$pipeline_scripts_dir/Tools/pipeline_settings.pl" pipeline_root)
output_dir_name=$("$pipeline_scripts_dir/Tools/pipeline_settings.pl" output_dir_name)
fotrak_dir="$pipeline_scripts_dir/FlyTracking"
do_sage_load=$("$pipeline_scripts_dir/Tools/pipeline_settings.pl" do_sageload_str)

if [ $do_sage_load = true ]
then
    # All tracking jobs have finished, run follow up scripts.
    "$fotrak_dir/fotrak_QC.pl"
fi

# Make sure the merging tool has been built.
if [ ! -x "$merge_dir/build/distrib/merge_analysis_output" ]
then
    echo "Doing one-time build of merge_analysis_output tool..."
    cd "$merge_dir"
    "$merge_dir/build_merge_analysis_output.sh"
    sleep 5     # Give the cluster nodes time to see the new file.
    echo "Build complete."
fi

cd "$pipeline_dir/02_fotracked"
ls -d */$output_dir_name 2>/dev/null > /tmp/stacks.flyolympiad_merge_fotrak
if [ -s /tmp/stacks.flyolympiad_merge_fotrak ]
then
    # Make sure we're in the directory where this script was run from so the xml, etc. files can be found.
    cd "$merge_dir"
    
    pipeline -v -config merge_fotrak.xml -file /tmp/stacks.flyolympiad_merge_fotrak
fi

# Clean up
rm -f /tmp/stacks.flyolympiad_merge_fotrak
