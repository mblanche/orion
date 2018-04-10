#!/usr/bin/env bash

echo "Running addWorkers.sh on master"

masterIP=$1
workerIPs=($2)
workerIDs=($3)

ssh="ssh -i $privateKey -q -o StrictHostKeyChecking=no ubuntu@$masterIP"

    
## Add workers to cluser
for (( i=0; $i<${#workerIPs[@]};i++ ));do
    NODENAME=${workerIDs[$i]}
    QUEUE=all.q
    SLOTS=$($ssh nproc)


    
    # add to the execution host list
    config=$(cat <<EOF
    hostname $NODENAME
    load_scaling NONE
    complex_values NONE
    user_lists NONE
    xuser_lists NONE
    projects NONE
    xprojects NONE
    usage_scaling NONE
    report_variables NONE
EOF
)
    echo "$config" | $ssh "cat >./grid && sudo qconf -Ae ./grid && rm ./grid"
    
    # add to the all hosts list
    $ssh "sudo qconf -aattr hostgroup hostlist $NODENAME @allhosts"

    # enable the host for the queue, in case it was disabled and not removed
    $ssh "sudo qmod -e $QUEUE@$NODENAME 2>&1 >/dev/null"
    
    if [ "$SLOTS" ]; then
	$ssh "sudo qconf -aattr queue slots \"[$NODENAME=$SLOTS]\" $QUEUE"
    fi
done
