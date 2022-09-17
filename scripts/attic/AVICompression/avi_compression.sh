#!/bin/bash
. /misc/lsf/conf/profile.lsf
source /misc/local/SOURCEME

avi_compression_dir=$(cd "$(dirname "$0")"; pwd)
pipeline_scripts_dir=$(dirname "$avi_compression_dir")
pipeline_dir=$("$pipeline_scripts_dir/Tools/pipeline_settings.pl" pipeline_root)
output_dir_name=$("$pipeline_scripts_dir/Tools/pipeline_settings.pl" output_dir_name)
analysis_dir="$pipeline_scripts_dir"/Analysis
do_sage_load=$("$pipeline_scripts_dir/Tools/pipeline_settings.pl" do_sageload_str)

# Make sure the next folders in the pipeline exist.
mkdir -p "$pipeline_dir/05_quarantine_analyzed"
mkdir -p "$pipeline_dir/06_avi_compressed"
mkdir -p "$pipeline_dir/06_quarantine_not_compressed"

if [ $do_sage_load = true ]
then
    # All analysis jobs have finished, run follow up scripts.
    "$analysis_dir"/analysis_QC.pl
fi

## Now compress the movie files.
#cd "$pipeline_dir/05_analyzed";
#ls */$output_dir_name/comparison_summary.pdf 2>/dev/null | sed 's/\/$output_dir_name\/comparison_summary\.pdf//' > /tmp/stacks.flyolympiad_box_avi_compression
#if [ -s /tmp/stacks.flyolympiad_box_avi_compression ]
#then
#    # Make sure we're in the directory where this script was run from so the xml, etc. files can be found.
#    cd "$avi_compression_dir"
#    
#    pipeline -v -config avi_compression.xml -file /tmp/stacks.flyolympiad_box_avi_compression
#fi
#
## Clean up
#rm /tmp/stacks.flyolympiad_box_avi_compression
