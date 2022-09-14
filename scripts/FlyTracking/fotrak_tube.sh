#!/bin/bash
#
# Run the MATLAB fly tracking code on all of a tube's SBFMF files.

tube_path="$1"
output_path="$2"

fotrak_dir=$(cd "$(dirname "$0")"; pwd)
pipeline_scripts_path=$(dirname "$fotrak_dir")

source /misc/local/matutil/mcr_select.sh 2013a

cd "$tube_path"
for sbfmf in `ls *.sbfmf`
do
    echo "==========================================================================================="
    echo "Running tracking on $sbfmf"
    echo ""
    
    sbfmf_path="$tube_path/$sbfmf"
    output_dir_name=$(basename "$sbfmf" .sbfmf)
    output_dir_path="$output_path/$output_dir_name"
    
    # Run tracking on the SBFMF file if it hasn't already been done.
    if [ -d "$output_dir_path" ]
    then
        echo "Skipping, tracking has already been done."
    else
        mkdir -p "$output_dir_path"
        chmod 775 "$output_dir_path"
        
        "$pipeline_scripts_path/FlyTracking/build/distrib/fo_trak" \
            /groups/reiser/home/boxuser/box/scripts/FlyTracking/FO_Trak/params_Olympiad.txt \
            "$sbfmf_path" \
            "$output_dir_path"
    fi
    
    echo "==========================================================================================="
    echo ""
    echo ""
done

source /misc/local/matutil/mcr_select.sh clean
