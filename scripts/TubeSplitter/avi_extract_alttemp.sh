#!/bin/sh
. /misc/lsf/conf/profile.lsf
source /misc/local/SOURCEME
tube_splitter_dir=$(cd "$(dirname "$0")"; pwd)
pipeline_scripts_dir=$(dirname "$tube_splitter_dir")
pipeline_dir=$("$pipeline_scripts_dir/Tools/pipeline_settings.pl" pipeline_root)

# Make sure each experiment has a "Logs" directory.
for exp_name in `ls "$pipeline_dir/00_incoming" 2>/dev/null`
do
    mkdir -p "$pipeline_dir/00_incoming/$exp_name/Logs"
done
cd "$pipeline_dir"/00_incoming
ls */*/*seq*.avi 2>/dev/null | grep -v '_tube' >/tmp/stacks.boxuser_avi_extract;
if [ -s /tmp/stacks.boxuser_avi_extract ]
then
    # Make sure we're in the directory where this script was run from so the xml, etc. files can be found.
    cd "$tube_splitter_dir"
    
    pipeline -v -config avi_extract.xml -file /tmp/stacks.boxuser_avi_extract
fi
