#!/bin/sh
. /misc/lsf/conf/profile.lsf
source /misc/local/SOURCEME

store_tracking_dir=$(cd "$(dirname "$0")"; pwd)
pipeline_scripts_dir=$(dirname "$store_tracking_dir")
pipeline_dir=$("$pipeline_scripts_dir/Tools/pipeline_settings.pl" pipeline_root)
merge_tracking_dir="$pipeline_scripts_dir/MergeTracking"

# Make sure the next folders in the pipeline exist.
mkdir -p "$pipeline_dir/02_quarantine_not_fotracked"
mkdir -p "$pipeline_dir/04_loaded"

echo "$store_tracking_dir \n"
# All track merging jobs have finished, run follow up scripts.
"$merge_tracking_dir/merge_fotrak_QC.pl"

# Make sure the merging tool has been built.
if [ ! -x "$store_tracking_dir/build/distrib/store_tracking" ]
then
    echo "Doing one-time build of store_tracking tool..."
    cd "$store_tracking_dir"
    "$store_tracking_dir/build_store_tracking.sh"
    sleep 5     # Give the cluster nodes time to see the new file.
    echo "Build complete."
fi

# Now store the tracking data in SAGE.
cd "$pipeline_dir/02_fotracked"
ls */*.exp 2>/dev/null > /tmp/stacks.flyolympiad_load_fotrak
if [ -s /tmp/stacks.flyolympiad_load_fotrak ]
then
    # Make sure we're in the directory where this script was run from so the xml, etc. files can be found.
    cd "$store_tracking_dir"
    
    pipeline -v -config store_tracking.xml -file /tmp/stacks.flyolympiad_load_fotrak
fi

# Clean up
rm -f /tmp/stacks.flyolympiad_load_fotrak
