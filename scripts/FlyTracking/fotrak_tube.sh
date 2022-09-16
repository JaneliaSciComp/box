#!/bin/bash
#
# Run the MATLAB fly tracking code on all of a tube's SBFMF files.

tube_path="$1"
output_path="$2"

bash_source_0=${BASH_SOURCE[0]}
this_script_file_path=$(realpath ${bash_source_0})
fotrak_dir=$(dirname "$this_script_file_path")
pipeline_scripts_path=$(dirname "$fotrak_dir")
box_root_folder_path=$(dirname "$pipeline_scripts_path")
matutil_folder_path="${box_root_folder_path}/matutil"
printf "matutil_folder_path: ${matutil_folder_path}\n"

source "${matutil_folder_path}/mcr_select.sh" 2013a

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
        
        "${fotrak_dir}/build/distrib/fo_trak" \
            "${fotrak_dir}/FO_Trak/params_Olympiad.txt" \
            "${sbfmf_path}" \
            "${output_dir_path}"
    fi
    
    echo "==========================================================================================="
    echo ""
    echo ""
done

source "${matutil_folder_path}/mcr_select.sh" clean
