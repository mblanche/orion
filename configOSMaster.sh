#!/usr/bin/env bash

ip_address=$1
mntIP=$2
machineName=$3
nodesIPs=($4)
nodeNames=($5)

#ip_address=$masterIP; mntIP=$mntIP; machineName='master'; nodesIPs=($masterIP "${nodeIPs[*]}"); nodeNames=('master' "${nodeIDs[*]}")

echo "Running config.sh on $machineName"

ssh="ssh -i $privateKey -q -o StrictHostKeyChecking=no -o LogLevel=Error ubuntu@$ip_address"
################################################################################
## Upgrading OS then rebooting $$$ The fuck apt-get can't shut up...
################################################################################
echo "Upgrading $machineName operating system, waiting to reboot..."

## Config the /host/etc for machine name resolution
$ssh "echo $machineName |sudo tee /etc/hostname"

for (( i=0; $i < ${#nodesIPs[@]}; i++ )); do
    $ssh "echo '${nodesIPs[$i]} ${nodeNames[$i]}' | sudo tee -a /etc/hosts"
done


## Config master and nodes for password less ssh
echo "Configuring SSH keys on $machineName"
$ssh 2>/dev/null <<'EOF'
rm -f ~/.ssh/known_hosts	
rm -f ~/.ssh/id_rsa*
ssh-keygen -q -t rsa -N "" -f ~/.ssh/id_rsa >/dev/null
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
EOF

$ssh "sudo DEBIAN_FRONTEND=noninteractive apt-get update && \
     sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y"


echo "Rebooting $machineName, waiting to be up and running"
$ssh "sudo reboot"

## Waiting on the node to get back online
sleep 2
f=0
while [[ $f -eq 0 ]]; do
    if nc -zv -w 1 $ip_address 22 2>&1 | grep -q succeeded
    then 
	f=1
    else
	echo -n .
	sleep 0.25
    fi
done

echo $ip_address

################################################################################
## Mounting NFS server
################################################################################
echo "Configuring $machineName fstab for NFS access"
$ssh 2>/dev/null <<EOF 
sudo DEBIAN_FRONTEND=noninteractive apt-get -y install nfs-kernel-server nfs-common emacs24-nox \
     build-essential zlib1g-dev python-setuptools python-dev build-essential

sudo easy_install pip
sudo pip install awscli

## Moving home directory to the NFS
sudo mkdir -p  /new_home
sudo mount -t nfs -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 $mntIP:/ /new_home

sudo rsync -aXS --exclude='/*/.gvfs' /home/. /new_home/.
sudo umount /new_home
sudo mkdir -p /old_home && sudo mv /home /old_home && sudo mkdir /home
sudo cp /etc/fstab /etc/bak_fstab
echo $mntIP:/ /home  nfs4 nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,_netdev 0 0 \
    | sudo tee --append /etc/fstab 2>&1 >/dev/null
sudo mount -a

mkdir -p ~/.aws
echo -e "[default]\nregion = $region" > ~/.aws/config
echo -e "[default]\naws_secret_access_key = $secretKey\naws_access_key_id = $accessKey" > ~/.aws/config

EOF

echo "Done configuring $machineName"
