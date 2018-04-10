#!/usr/bin/env bash

masterIP=$1
masterName=$2
nodeIPs=($3)
nodesNames=($4)

echo "Running configMaster.sh on $masterName"

ssh="ssh -i $privateKey -q -o StrictHostKeyChecking=no ubuntu@$masterIP"

$ssh <<'EOF'
# Configure the master hostname for Grid Engine
echo "gridengine-master       shared/gridenginemaster string  $HOSTNAME" | sudo debconf-set-selections
echo "gridengine-master       shared/gridenginecell   string  default" | sudo debconf-set-selections
echo "gridengine-master       shared/gridengineconfig boolean false" | sudo debconf-set-selections
echo "gridengine-common       shared/gridenginemaster string  $HOSTNAME" | sudo debconf-set-selections
echo "gridengine-common       shared/gridenginecell   string  default" | sudo debconf-set-selections
echo "gridengine-common       shared/gridengineconfig boolean false" | sudo debconf-set-selections
echo "gridengine-client       shared/gridenginemaster string  $HOSTNAME" | sudo debconf-set-selections
echo "gridengine-client       shared/gridenginecell   string  default" | sudo debconf-set-selections
echo "gridengine-client       shared/gridengineconfig boolean false" | sudo debconf-set-selections
# Postfix mail server is also installed as a dependency
echo "postfix postfix/main_mailer_type        select  No configuration" | sudo debconf-set-selections

# Install Grid Engine
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y gridengine-master gridengine-client 2>&1 >/dev/null
while [ $? -ne 0 ];do
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y gridengine-master gridengine-client 2>&1 >/dev/null
done
     
# Set up Grid Engine
sudo -u sgeadmin /usr/share/gridengine/scripts/init_cluster /var/lib/gridengine default /var/spool/gridengine/spooldb sgeadmin
sudo service gridengine-master restart

# Disable Postfix
sudo service postfix stop
sudo update-rc.d postfix disable

sudo qconf -am $USER
sudo qconf -ao $USER
sudo qconf -as $HOSTNAME
sudo qconf -ah $HOSTNAME
EOF

# change scheduler config
config=$(cat <<EOF
algorithm                          default
schedule_interval                 0:0:1
maxujobs                          0
queue_sort_method                 load
job_load_adjustments              np_load_avg=0.50
load_adjustment_decay_time        0:7:30
load_formula                      np_load_avg
schedd_job_info                   true
flush_submit_sec                  0
flush_finish_sec                  0
params                            none
reprioritize_interval             0:0:0
halftime                          168
usage_weight_list                 cpu=1.000000,mem=0.000000,io=0.000000
compensation_factor               5.000000
weight_user                       0.250000
weight_project                    0.250000
weight_department                 0.250000
weight_job                        0.250000
weight_tickets_functional         0
weight_tickets_share              0
share_override_tickets            TRUE
share_functional_shares           TRUE
max_functional_jobs_to_schedule   200
report_pjob_tickets               TRUE
max_pending_tasks_per_job         50
halflife_decay_list               none
policy_hierarchy                  OFS
weight_ticket                     0.500000
weight_waiting_time               0.278000
weight_deadline                   3600000.000000
weight_urgency                    0.500000
weight_priority                   0.000000
max_reservation                   0
default_duration                  INFINITY
EOF
)
echo "$config" | $ssh "cat > ./grid && sudo qconf -Msconf ./grid && rm ./grid"


# create a host list
echo -e "group_name @allhosts\nhostlist NONE" | \
    $ssh "cat > ./grid && sudo qconf -Ahgrp ./grid && rm ./grid"

# create a queue
config=$(cat <<EOF
qname                 all.q
hostlist              @allhosts
seq_no                0
load_thresholds       NONE
suspend_thresholds    NONE
nsuspend              1
suspend_interval      00:00:01
priority              0
min_cpu_interval      00:00:01
processors            UNDEFINED
qtype                 BATCH INTERACTIVE
ckpt_list             NONE
pe_list               make
rerun                 FALSE
slots                 2
tmpdir                /tmp
shell                 /bin/csh
prolog                NONE
epilog                NONE
shell_start_mode      posix_compliant
starter_method        NONE
suspend_method        NONE
resume_method         NONE
terminate_method      NONE
notify                00:00:01
owner_list            NONE
user_lists            NONE
xuser_lists           NONE
subordinate_list      NONE
complex_values        NONE
projects              NONE
xprojects             NONE
calendar              NONE
initial_state         default
s_rt                  INFINITY
h_rt                  INFINITY
s_cpu                 INFINITY
h_cpu                 INFINITY
s_fsize               INFINITY
h_fsize               INFINITY
s_data                INFINITY
h_data                INFINITY
s_stack               INFINITY
h_stack               INFINITY
s_core                INFINITY
h_core                INFINITY
s_rss                 INFINITY
h_rss                 INFINITY
s_vmem                INFINITY
h_vmem                INFINITY
EOF
)
echo "$config" | $ssh "cat > ./grid && sudo qconf -Aq ./grid && rm ./grid"
