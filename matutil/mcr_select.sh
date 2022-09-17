#!/bin/bash

# This script properly sets up your UNIX environment for running compiled MATLAB code on the cluster.
# It can list which versions of MATLAB are available, switch between them and clean up afterwards.
# The script must be 'sourced' so that the environment variable changes are made to the current shell.
#
# Usage:
#   source /misc/local/matutil/mcr_select.sh
#   source /misc/local/matutil/mcr_select.sh 2012b
#   source /misc/local/matutil/mcr_select.sh clean

# Determine the path to this script file, and the folder containing it
bash_source_0=${BASH_SOURCE[0]}
printf "bash_source_0: $bash_source_0\n"
this_script_file_path=$(realpath ${bash_source_0})
printf "this_script_file_path: $this_script_file_path\n"
matutil_folder_path=$(dirname "${this_script_file_path}")
box_root_path=$(dirname "${matutil_folder_path}")
MCRROOT="${box_root_path}/local/MATLAB_Compiler_Runtime/v81"

if [ $# -eq 0 ]; then
    echo "Available MATLAB runtimes:"
    echo ${MCRROOT}
elif [ $# -eq 1 ]; then
    if [ $1 = "clean" ]; then
        # Remove the MCR cache directory.
        if [ -n "$MCR_CACHE_ROOT" ]; then
            rm -rf "$MCR_CACHE_ROOT"
        else
            echo "No MCR cache directory is defined."
        fi
    else
        # We ignore the argument and just use the one MCR we use
        echo "Hopefully you want to use the MCR at ${MCRROOT}."
        if [ ! -d $MCRROOT ]; then
            echo "Could not find a MATLAB runtime at $MCRROOT"
        else
            # Set up the MATLAB environment
            export PATH="$MCRROOT/bin:$PATH"
            
            MCRJRE="${MCRROOT}/sys/java/jre/glnxa64/jre/lib/amd64" ;
            LD_LIBRARY_PATH="${MCRROOT}/runtime/glnxa64:${MCRROOT}/bin/glnxa64:${MCRROOT}/sys/os/glnxa64:${MCRJRE}/native_threads:${MCRJRE}/server:$LD_LIBRARY_PATH" ;
            export LD_LIBRARY_PATH
            
            export XAPPLRESDIR="${MCRROOT}/X11/app-defaults";
            
            if [ -n "$JOB_ID" ]; then
                # We're running on the cluster via SGE, make sure we don't step on other nodes' toes.
                if [ -d "/scratch/$USER" ]; then
                    # Use the space that was set up for this user.
                    export MCR_CACHE_ROOT=/scratch/$USER/mcr_cache_root.$JOB_ID
                else
                    # Use generic temp space.
                    export MCR_CACHE_ROOT=/tmp/mcr_cache_root.$USER.$JOB_ID
                    
                    # # If we're on a compute node then let SciComp know that this user might need a scratch area created.
                    # if [ -f '/misc/local/matutil/no_cluster_scratch.log' -a -n "`hostname | grep '^f[0-9][0-9]'`" ]; then
                    #     echo -e "`date +'%F %T'`\t$USER\t$JOB_ID" >> /misc/local/matutil/no_cluster_scratch.log
                    # fi
                fi
                
                #export MCR_CACHE_VERBOSE=1
                
                # Since we know our MCR cache is unique to this job we don't need write locking on it.
                export MCR_INHIBIT_CTF_LOCK=1
            fi
            
            # Hack to fix a bug running deploytool from the command line.
            # <http://www.mathworks.com/support/bugreports/800249>
            #export MWE_INSTALL="$MCRROOT"
        fi
    fi
else
    echo "Usage:"
    echo "  source mcr_select.sh                (list available runtimes)"
    echo "or:"
    echo "  source mcr_select.sh <runtime_name> (select a specific runtime)"
    echo "or:"
    echo "  source mcr_select.sh clean          (delete cached files)"
fi
