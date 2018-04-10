#!/usr/bin/env bash

ip=$1

ssh="ssh -i $privateKey -q -o StrictHostKeyChecking=no ubuntu@$ip"

echo "Running configWorkers.sh on $ip"


$ssh <<'EOF'
export MASTER_HOSTNAME=master
echo "gridengine-common       shared/gridenginemaster string  $MASTER_HOSTNAME" | sudo debconf-set-selections
echo "gridengine-common       shared/gridenginecell   string  default" | sudo debconf-set-selections
echo "gridengine-common       shared/gridengineconfig boolean false" | sudo debconf-set-selections
echo "gridengine-client       shared/gridenginemaster string  $MASTER_HOSTNAME" | sudo debconf-set-selections
echo "gridengine-client       shared/gridenginecell   string  default" | sudo debconf-set-selections
echo "gridengine-client       shared/gridengineconfig boolean false" | sudo debconf-set-selections
echo "postfix postfix/main_mailer_type        select  No configuration" | sudo debconf-set-selections

sudo DEBIAN_FRONTEND=noninteractive apt-get install -y gridengine-exec gridengine-client 2>&1 >/dev/null
if [ $? -ne 0 ]; then
   sudo apt-get update && \
   sudo DEBIAN_FRONTEND=noninteractive apt-get install -y gridengine-exec gridengine-client 2>&1 >/dev/null	
fi

sudo service postfix stop 2>&1 >/dev/null
sudo update-rc.d postfix disable 2>&1 >/dev/null

echo $MASTER_HOSTNAME | sudo tee /var/lib/gridengine/default/common/act_qmaster 2>&1 >/dev/null
#sudo service gridengine-exec restart
EOF
