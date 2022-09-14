#!/bin/bash

ssh_host="olympiad@10.102.32.50"

for line in `ssh $ssh_host ls /cygdrive/e`
  do
    if ssh $ssh_host "ls /cygdrive/e/$line/*.exp 1> /dev/null 2>&1;"
      then
        scp -r $ssh_host:/cygdrive/e/$line /tier2/flyvisionbox/box_data/ && ssh $ssh_host rm -rf /cygdrive/e/$line
        chmod 755 $(find /tier2/flyvisionbox/box_data/$line -type d)
        chmod 644 $(find /tier2/flyvisionbox/box_data/$line -type f)
    fi
done

