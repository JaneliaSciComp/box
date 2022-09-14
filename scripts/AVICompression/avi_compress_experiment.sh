#!/bin/bash

# Usage:
#    avi_compress_experiment.sh /groups/sciserv/flyolympiad/Olympiad_Screen/box/box_data/GMR_45G07_AE_01_shi_Athena_20111118T144650

# Find all AVI's in the experiment folder and pass them to avi_compress_movie.sh.
# But first make sure that the comparison summary and the corresponding SBFMF's exist.

avi_compression_dir=$(cd "$(dirname "$0")"; pwd)
pipeline_scripts_dir=$(dirname "$avi_compression_dir")
do_sage_load=$("$pipeline_scripts_dir/Tools/pipeline_settings.pl" do_sageload_str)

experiment_path="$1"
experiment_name=$(basename "$experiment_path")
if [ -L "$experiment_path" ]
then
    real_experiment_path=$(readlink -f "$experiment_path")
else
    real_experiment_path="$experiment_path"
fi

# Grep the box name out of the experiment name
box_name=$(echo "$experiment_name" | sed "s/^.*_\([^_]*\)_[0-9T]*$/\1/g")
#TODO: get the line name from the sequence details file

output_dir_name=$("$pipeline_scripts_dir/Tools/pipeline_settings.pl" output_dir_name)
if [ ! -s "$experiment_path/$output_dir_name/comparison_summary.pdf" ]
then
	echo "This experiment was not analyzed successfully.  (missing or empty comparison summary)" >&2
    /groups/flyprojects/home/olympiad/bin/flyolympiad_create_jira_ticket.pl \
        --summary="AVI compression failed for $experiment_name" \
        --description="The comparison summary PDF is missing or empty." \
        --filepath="$real_experiment_path" \
        --component="AVI compression" \
        --box="$box_name"
	exit 1
fi

IFS=$'\n'

for avi_path in $(ls "$experiment_path"/*/*.avi 2>/dev/null | grep -v "_archived")
do
	unset IFS
	
	avi_name=$(basename "$avi_path" ".avi")
	
	# Check that SBFMF's are present and non-empty.
	temp_dir=$(dirname "$avi_path")
	temp_name=$(basename "$temp_dir")
	prefix=$(echo "$temp_name" | rev | cut -c 4- | rev)
	for tube in 1 2 3 4 5 6
	do
		tube_path="$temp_dir/${prefix}_tube${tube}_sbfmf/${avi_name}_tube${tube}.sbfmf"
		if [ -L "$tube_path" ]
		then
			tube_path=$(readlink "$tube_path")
		fi
		if [ ! -s "$tube_path" ]
		then
			echo "One of the SBFMF's is missing or empty: $tube_path" >&2
            /groups/flyprojects/home/olympiad/bin/flyolympiad_create_jira_ticket.pl \
                --summary="AVI compression failed for $experiment_name" \
                --description="One of the SBFMF files is missing or empty at $tube_path." \
                --filepath="$real_experiment_path" \
                --component="AVI compression" \
                --box="$box_name"
			exit 1
		fi
	done
	
	echo "Compressing $avi_path ..."
	movie_dir=$(dirname "$avi_path")
	mp4_path="$movie_dir/$avi_name.mp4"
	if [ -L "$avi_path" ]
	then
		# Compress the file at the link.
		real_avi_path=$(readlink -f "$avi_path")
		"$avi_compression_dir/avi_compress_movie.sh" "$real_avi_path" "$mp4_path"
		
		# If it worked then remove the link.
		compress_result=$?
		if [ $compress_result -eq 0 ]
		then
			rm "$avi_path"
            
            mp4_size=$(stat -c "%s" "$mp4_path")
		else
            echo "Compression failed." >&2
            /groups/flyprojects/home/olympiad/bin/flyolympiad_create_jira_ticket.pl \
                --summary="AVI compression failed for $experiment_name" \
                --description="Failed to compress movie at $real_avi_path." \
                --filepath="$real_experiment_path" \
                --component="AVI compression" \
                --box="$box_name"
			exit $compress_result
		fi
	else
		"$avi_compression_dir/avi_compress_movie.sh" "$avi_path" "$mp4_path"
		compress_result=$?
		if [ ! $compress_result -eq 0 ]
		then
            echo "Compression failed." >&2
            /groups/flyprojects/home/olympiad/bin/flyolympiad_create_jira_ticket.pl \
                --summary="AVI compression failed for $experiment_name" \
                --description="Failed to compress movie at $avi_path." \
                --filepath="$real_experiment_path" \
                --component="AVI compression" \
                --box="$box_name"
			exit $compress_result
		fi
	fi
done

if [ $do_sage_load = true ]
then
    # Update the image and image property tables in SAGE, making sure to use our copy of sage.py.
    echo "Updating the SAGE imagery tables."
    export PYTHONPATH="$pipeline_scripts_dir":$PYTHONPATH
    /misc/local/python-2.7.3/bin/python "$avi_compression_dir/update_box_imagery.py" "$experiment_path"
    update_result=$?
    if [ ! $update_result -eq 0 ]
    then
        echo "SAGE update failed." >&2
        /groups/flyprojects/home/olympiad/bin/flyolympiad_create_jira_ticket.pl \
            --summary="AVI compression failed for $experiment_name" \
            --description="Failed to update SAGE after compressing AVI's at $avi_path." \
            --filepath="$real_experiment_path" \
            --component="AVI compression" \
            --box="$box_name"
    	exit $compress_result
    fi
fi

echo "Compression completed"
