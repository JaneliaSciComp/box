#!/bin/bash

# This script finds experiments in 06_avi_compressed that are ready to be archived and runs the archive script on them.
# Afterwards the experiment tracking symlink is moved to either 07_archived or 07_quarantine_not_archived.

archive_dir=$(cd "$(dirname "$0")"; pwd)
pipeline_scripts_dir=$(dirname "$archive_dir")
pipeline_dir=$("$pipeline_scripts_dir/Tools/pipeline_settings.pl" pipeline_root)

# MySQLdb is installed for Python 2.7.1 on flyolympiad, not in 2.7.3 as on the cluster.
PYTHON=/misc/local/python-2.7.1/bin/python
ARCHIVE_SCRIPT="$archive_dir/archive_box_experiment.py"
LOG_DIR=/groups/flyprojects/home/olympiad/LOGS/ARCHIVING

# Make sure the next folders in the pipeline exist.
mkdir -p "$pipeline_dir/06_quarantine_not_compressed"
mkdir -p "$pipeline_dir/07_archived"
mkdir -p "$pipeline_dir/07_quarantine_not_archived"

# Loop through all of the experiments in 06_avi_compressed (allowing spaces in experiment names)
IFS=$'\n'
for EXP_NAME in $(ls -1 "$pipeline_dir/06_avi_compressed" 2>/dev/null)
do
    unset IFS
    
    EXP_PATH=$(readlink -m "$pipeline_dir/06_avi_compressed/$EXP_NAME")
    
    echo "Archiving $EXP_NAME..."
    
    # Create a log sub-directory for this experiment's year & month so we don't have tens of thousands of 
    # log files in the same directory.
    # TODO: use the new experiment-specific log directory instead.
    EXP_YEAR_MONTH=$(echo "$EXP_NAME" | sed 's/.*_\([0-9][0-9][0-9][0-9]\)\([0-9][0-9]\)[0-9][0-9]T[0-9]*$/\1_\2/')
    mkdir -p "$LOG_DIR/$EXP_YEAR_MONTH"
    
    # Run the archiving script and redirect stdout and stderr to an experiment-specific log file.
    export PYTHONPATH="$pipeline_scripts_dir":$PYTHONPATH
    $PYTHON $ARCHIVE_SCRIPT "$EXP_PATH" > "$LOG_DIR/$EXP_YEAR_MONTH/archiving_${EXP_NAME}.log" 2>&1
    
    ARCHIVE_RESULT=$?
    
    if [ $ARCHIVE_RESULT -eq 0 ]
    then
        # Success, move the experiment along.
        echo "Archiving succeeded, moving experiment to next step in pipeline."
        mv "$pipeline_dir/06_avi_compressed/$EXP_NAME" "$pipeline_dir/07_archived"
    else
        # Something went wrong, move the experiment to quarantine.
        echo "Archiving failed, moving experiment to quarantine."
        QUAR_PATH="$pipeline_dir/07_quarantine_not_archived/$EXP_NAME"
        mv "$pipeline_dir/06_avi_compressed/$EXP_NAME" "$QUAR_PATH"
        
        # Create a JIRA ticket.
        echo "Creating JIRA ticket."
        METADATA_PATH=$(ls "${QUAR_PATH}/*Metadata.xml" 2>/dev/null)
        if [ -n "$METADATA_PATH" -a -f "$METADATA_PATH" ]
        then
            # Extract the box name from the metadata XML.
            BOX_NAME=$(xml_grep "apparatus" "$METADATA_PATH" | grep apparatus | sed "s/^.*box=\"\([^\"]*\)\".*$/\1/")
        else
            # Hopefully get the box name from the folder name.
            BOX_NAME=$(echo "$EXP_NAME" | sed 's/.*_\([^_]*\)_[0-9T]*$/\1/')
        fi
        /groups/flyprojects/home/olympiad/bin/flyolympiad_create_jira_ticket.pl -s "Archiving failed for $EXP_NAME" -f "$QUAR_PATH" -c "Archiving" -b "$BOX_NAME" -D "$LOG_DIR/$EXP_YEAR_MONTH/archiving_${EXP_NAME}.log"
    fi
done
