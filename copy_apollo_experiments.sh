#!/bin/bash

ssh_host="olympiad@10.102.32.50"
origin_dir="/cygdrive/e/"
destination_dir="/groups/reiser/flyvisionbox/box_data/"

for line in `ssh $ssh_host ls $origin_dir`
  do
    if ssh $ssh_host "ls $origin_dir$line/*.exp 1> /dev/null 2>&1;"
      then
        scp -r $ssh_host:$origin_dir$line $destination_dir && ssh $ssh_host rm -rf $origin_dir$line
        chmod 755 $(find $destination_dir$line -type d)
        chmod 644 $(find $destination_dir$line -type f)
    fi
done

