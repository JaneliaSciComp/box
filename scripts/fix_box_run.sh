#!/bin/bash
stalled=$1
completed=$2
stalledshort=$(echo "$stalled" | sed 's/.\{16\}$//')
completedshort=$(echo "$completed" | sed 's/.\{16\}$//')
stalledgeno=$(echo $stalled | grep -Eo 'JHS_K_85321|GMR_SS[0-9]{5}')
completedgeno=$(echo $completed | grep -Eo 'JHS_K_85321|GMR_SS[0-9]{5}')
incomingdir=/groups/reiser/home/boxuser/box/00_incoming
cp "$incomingdir"/"$completed"/02_5.34_34/*.mat "$incomingdir"/"$stalled"/02_5.34_34
cp "$incomingdir"/"$completed"/02_5.34_34/sequence_details_"$completedshort".m "$incomingdir"/"$stalled"/02_5.34_34
cp "$incomingdir"/"$completed"/02_5.34_34/5.34.seq "$incomingdir"/"$stalled"/02_5.34_34
mv "$incomingdir"/"$stalled"/02_5.34_34/sequence_details_"$completedshort".m \
"$incomingdir"/"$stalled"/02_5.34_34/sequence_details_"$stalledshort".m
sed -i -e "s/$completedgeno/$stalledgeno/g" "$incomingdir"/"$stalled"/02_5.34_34/sequence_details_"$stalledshort".m

