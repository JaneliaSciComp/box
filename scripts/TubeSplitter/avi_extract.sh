#!/bin/bash
#echo "Before profile.lsf"
#. /misc/lsf/conf/profile.lsf
#echo "Past profile.lsf"

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

#source /misc/local/SOURCEME
#source "$SCRIPTS_FOLDER_PATH/SOURCEME"
echo "Milestone 1"
#tube_splitter_dir=$(cd "$(dirname "$0")"; pwd)
echo "Milestone 2"
#pipeline_scripts_dir=$(dirname "$tube_splitter_dir")
#pipeline_dir=$("$SCRIPTS_FOLDER_PATH/Tools/pipeline_settings.pl" pipeline_root)
#BOX_ROOT_PATH=`pwd`
printf "BOX_ROOT_PATH: $BOX_ROOT_PATH\n"
echo "Milestone 3"

# Make sure each experiment has a "Logs" directory.
for exp_name in `ls "$BOX_ROOT_PATH/00_incoming" 2>/dev/null`
do
    mkdir -p "$BOX_ROOT_PATH/00_incoming/$exp_name/Logs"
done
echo "Milestone 4"
cd "$BOX_ROOT_PATH"/00_incoming
ls */*/*seq*.avi 2>/dev/null | grep -v '_tube' >/tmp/stacks.boxuser_avi_extract;
echo "Milestone 5"
if [ -s /tmp/stacks.boxuser_avi_extract ]
then
    # Make sure we're in the directory where this script lives so the xml, etc. files can be found.
    cd "$SCRIPT_FOLDER_PATH"
    #echo "Milestone 5"
    #echo $tube_splitter_dir
    #whereis pipeline    
    #which pipeline
    "${perl_interpreter_path}" "${pipeline_script_path}" -v -config avi_extract.xml -file /tmp/stacks.boxuser_avi_extract
fi
echo "Milestone 6"
