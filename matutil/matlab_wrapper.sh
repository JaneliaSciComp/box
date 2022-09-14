#!/bin/bash

# unset the DISPLAY variable to avoid coredumps with large numbers of jobs
unset DISPLAY

#Set up your mcr cache location -- Replace <USERNAME> with your username
export MCR_CACHE_ROOT=/scratch/<USERNAME>/mcr_cache_root.$JOB_ID


#Now give the path to your matlab executable
/path/to/matlab/binary



#Cleanup after the job -- Replace <USERNAME> with your username
rm -rf /scratch/<USERNAME>/mcr_cache_root.$LSB_JOBID.$LSB_JOBINDEX


