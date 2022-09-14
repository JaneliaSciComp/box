#!/bin/sh
. /sge/current/default/common/settings.sh
source /usr/local/SOURCEME

analysis_dir=$(cd "$(dirname "$0")"; pwd)
pipeline_scripts_dir=$(dirname "$analysis_dir")
pipeline_dir=$("$pipeline_scripts_dir/Tools/pipeline_settings.pl" pipeline_root)
output_dir_name=$("$pipeline_scripts_dir/Tools/pipeline_settings.pl" output_dir_name)
store_tracking_dir="$pipeline_scripts_dir/TrackingLoader"
do_sage_load=$("$pipeline_scripts_dir/Tools/pipeline_settings.pl" do_sageload_str)

# Make sure the next folders in the pipeline exist.
mkdir -p "$pipeline_dir/04_quarantine_not_loaded"
mkdir -p "$pipeline_dir/05_analyzed"

if [ $do_sage_load = true ]
then
    # All merge tracking jobs have finished, run follow up scripts.
    "$store_tracking_dir/store_tracking_QC.pl"
fi

# Make sure the analysis tool has been built.
if [ ! -x "$analysis_dir/build/distrib/analyze_experiment" ]
then
    echo "Doing one-time build of analysis tool..."
    cd "$analysis_dir"
    "$analysis_dir/build_analyze_experiment.sh"
    sleep 5     # Give the cluster nodes time to see the new file.
    echo "Build complete."
fi

# Queue up cluster jobs to analyze the experiments.
cd "$pipeline_dir/04_loaded";
ls -d */$output_dir_name 2>/dev/null > /tmp/stacks.flyolympiad_box_analysis
if [ -s /tmp/stacks.flyolympiad_box_analysis ]
then
    # Make sure we're in the directory where this script was run from so the xml, etc. files can be found.
    cd "$analysis_dir"
    
    pipeline -v -config analysis.xml -file /tmp/stacks.flyolympiad_box_analysis
fi

# Clean up
rm /tmp/stacks.flyolympiad_box_analysis
