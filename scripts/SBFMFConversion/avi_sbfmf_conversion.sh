#!/bin/bash

BASH_SOURCE_0=${BASH_SOURCE[0]}
printf "BASH_SOURCE_0: $BASH_SOURCE_0\n"
SCRIPT_FILE_PATH=$(realpath ${BASH_SOURCE_0})
printf "SCRIPT_FILE_PATH: $SCRIPT_FILE_PATH\n"
SCRIPT_FOLDER_PATH=$(dirname "$SCRIPT_FILE_PATH")
printf "SCRIPT_FOLDER_PATH: $SCRIPT_FOLDER_PATH\n"
SCRIPTS_FOLDER_PATH=$( dirname "$SCRIPT_FOLDER_PATH" )
printf "SCRIPTS_FOLDER_PATH: $SCRIPTS_FOLDER_PATH\n"
BOX_ROOT_PATH=$( dirname "$SCRIPTS_FOLDER_PATH" )
printf "BOX_ROOT_PATH: $BOX_ROOT_PATH\n"
PIPELINE_ROOT_PATH="$BOX_ROOT_PATH/informatics-pipeline"
#export PATH="$PATH:$PIPELINE_ROOT_PATH/bin:$SCRIPTS_FOLDER_PATH/bin"
pipeline_script_path="$PIPELINE_ROOT_PATH/bin/pipeline"
printf "pipeline_script_path: $pipeline_script_path\n"
perl_interpreter_path="${BOX_ROOT_PATH}/local/python-2-env/bin/perl"
printf "perl_interpreter_path: $perl_interpreter_path\n"

#avi_sbfmf_dir=$(cd "$(dirname "$0")"; pwd)
#printf "avi_sbfmf_dir: $avi_sbfmf_dir\n"
#pipeline_scripts_dir=$(dirname "$SCRIPT_FOLDER_PATH")
#printf "pipeline_scripts_dir: $pipeline_scripts_dir\n"
# pipeline_dir=$("$SCRIPTS_FOLDER_PATH/Tools/pipeline_settings.pl" pipeline_root)
# printf "pipeline_dir: $pipeline_dir\n"
# do_sage_load=$("$SCRIPTS_FOLDER_PATH/Tools/pipeline_settings.pl" do_sageload_str)
# printf "do_sage_load: $do_sage_load\n"

# Example values of the above:
# SCRIPT_FILE_PATH: /groups/reiser/home/boxuser/flyvisionbox/scripts/SBFMFConversion/avi_sbfmf_conversion.sh
# SCRIPT_FOLDER_PATH: /groups/reiser/home/boxuser/flyvisionbox/scripts/SBFMFConversion
# SCRIPTS_FOLDER_PATH: /groups/reiser/home/boxuser/flyvisionbox/scripts
# pipeline_dir: /groups/reiser/home/boxuser/box
# do_sage_load: false

# Make sure the next folders in the pipeline exist.
mkdir -p "$BOX_ROOT_PATH/00_quarantine_not_split"
mkdir -p "$BOX_ROOT_PATH/01_sbfmf_compressed"

# if [ $do_sage_load = true ]
# then
#     # Run QC's on the experiments now that tube splitting is done.
#     "$SCRIPTS_FOLDER_PATH/TubeSplitter/avi_extract_QC.pl";
# fi
# Convert all tube AVI's to SBFMF.
cd "$BOX_ROOT_PATH"/00_incoming
ls */*/*seq*tube*.avi 2>/dev/null >/tmp/stacks.boxuser_avisbfmf;
if [ -s /tmp/stacks.boxuser_avisbfmf ]
then
    # Make sure we're in the directory where this script lives so that the xml, etc. files can be found.
    cd "$SCRIPT_FOLDER_PATH"
    "${perl_interpreter_path}" "${pipeline_script_path}" -v -config avi_sbfmf_conversion.xml -file /tmp/stacks.boxuser_avisbfmf
fi
