#!/bin/bash

transfer_dir=$(cd "$(dirname "$0")"; pwd)
pipeline_scripts_dir=$(dirname "$transfer_dir")
pipeline_dir=$("$pipeline_scripts_dir/Tools/pipeline_settings.pl" pipeline_root)
incoming_dir="$pipeline_dir/00_incoming"

# Make sure the incoming folder exists.
mkdir -p "$incoming_dir"

/groups/flyprojects/home/olympiad/bin/fly_olympiad_assay_transfer.pl -assay box

# Make sure each experiment has a "Logs" directory.
for exp_name in `ls "$incoming_dir" 2>/dev/null`
do
	mkdir -p "$incoming_dir/$exp_name/Logs"
done

# Load the experiments into SAGE.
"$pipeline_scripts_dir/MetadataLoader/metadata_loader.pl" run;

# Perform QC checks on the experiments.
"$pipeline_scripts_dir/MetadataLoader/metadata_loader_QC.pl";

# Perform additional QC checks on the experiments.
# This must be run after the metadata loads because it needs the experiments to be in SAGE.
"$pipeline_scripts_dir/TransferApp/transfer_QC.pl";

# Delete successfully transferred experiments from the assay machines.
/groups/flyprojects/home/olympiad/bin/fly_olympiad_assay_transfer.pl -assay box -cleanup
