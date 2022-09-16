#!/bin/bash

bash_source_0=${BASH_SOURCE[0]}
this_script_file_path=$(realpath ${bash_source_0})
this_script_folder_path=$(dirname "$this_script_file_path")
box_root_folder_path=$(realpath "${this_script_folder_path}/../..")
matutil_folder_path="${box_root_folder_path}/matutil"
printf "matutil_folder_path: ${matutil_folder_path}\n"

source "${matutil_folder_path}/mcr_select.sh" 2013a

deploytool -build fo_trak.prj
