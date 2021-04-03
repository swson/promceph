#!/bin/bash
echo "Deploy a ceph cluster with cephadm (do not run set up as root)..."
echo "Download cephadm from github..."
curl --silent --remote-name --location https://github.com/ceph/ceph/raw/octopus/src/cephadm/cephadm
chmod +x cephadm

echo ""
echo "Add ceph debian package sources..."
wget -q -O- 'https://download.ceph.com/keys/release.asc' | sudo apt-key add -
echo deb https://download.ceph.com/debian-octopus/ $(lsb_release -sc) main | sudo tee /etc/apt/sources.list.d/ceph.list
sudo apt-get update

echo ""
echo "Install ceph-common and cephadm tools..."
sudo ./cephadm install cephadm ceph-common

# get node list
tail +2 /etc/hosts|awk '{print $NF}'| sort > node-list
NUM_NODES=`wc -l node-list | awk '{print $1}'`

echo ""
echo "Bootstrap your cluster..."
sudo mkdir -p /etc/ceph
# Replace <ip> with the IP address of your first manager node within your cluster (node1)
DOMAIN_NAME=`hostname | cut -d . -f2-`
# should execute the following before running bootstrap
sudo hostname `head -n 1 node-list`
#sudo ./cephadm bootstrap --mon-ip `hostname -I | cut -d" " -f1`   ### this line didn't work well
#IF=`/sbin/ifconfig|grep -i mtu|grep eno|cut -d: -f1`  ## this work on Utah nodes
#sudo ./cephadm bootstrap --mon-ip `/sbin/ifconfig $IF |grep -i mask | awk '{print $2}' | cut -f2 -d:`
sudo ./cephadm bootstrap --mon-ip `curl ifconfig.me`
echo "Check ceph status..."
sudo ceph status

echo ""
echo "Adding more nodes..."
# before you can add a new node to your cluster,
# you need to copy the ceph ssh key from your manager node into your new server.
for node in `tail -n +2 node-list`
do
    echo "sudo sh -c "ssh-copy-id -f -i /etc/ceph/ceph.pub root@$node" ..."
    sudo sh -c "ssh-copy-id -oStrictHostKeyChecking=no -f -i /etc/ceph/ceph.pub root@$node"
    # following commadline requires full node names
    echo "sudo ceph orch host add $node.$DOMAIN_NAME ..."
    sudo ceph orch host add $node.$DOMAIN_NAME
    sleep 30
done

sleep 1m

echo ""
echo "Adding storage, at lease 3 OSDs..."
#echo "list the current status..."
#sudo ceph orch device ls
NUM_OSDS=`sudo ceph orch device ls | tail +2 | grep ssd | awk '{print $NF}'|grep -i Yes`
echo "Wait until at least 3 OSDs are available ..."
while [ "$NUM_OSDS" != "$NUM_NODES" ]
do
    NUM_OSDS=`sudo ceph orch device ls | tail +2 | grep ssd | awk '{print $NF}' | grep -i Yes | wc -l`
done
echo "Tell Ceph to consume any available and unused storage device..."
sudo ceph orch apply osd --all-available-devices

sleep 1m

echo ""
echo "Mounting ceph file system..."
echo "Creating storage pools..."
sudo ceph osd pool create cephfs_data # (erasure)
sudo ceph osd pool create cephfs_metadata
echo "Creating the new ceph file system..."
sudo ceph fs new cephfs cephfs_metadata cephfs_data # (if erasure: ceph osd pool set cephfs_data allow_ec_overwrites true)
echo "Create a ceph metadata server..."
# ceph orch apply mds *<fs-name>* --placement="*<num-daemons>* [*<host1>* ...]"
sudo ceph orch apply mds cephfs --placement="1 node0"
sleep 1m
echo "Checking the status of the Ceph MDS..."
sudo ceph mds stat

echo ""
echo "Store the secret key used for admin authentication into a file that can be used for mounting the Ceph FS"
#sudo sh -c 'echo $(sed -n 's/.*key *= *\([^ ]*.*\)/\1/p' < /etc/ceph/ceph.client.admin.keyring) > /etc/ceph/admin.secret'  #### This line won't work due to permission issue on redirection
sudo sh -c "cat /etc/ceph/ceph.client.admin.keyring | sed -n 's/.*key *= *\([^ ]*.*\)/\1/p' > /etc/ceph/admin.secret"
sudo chmod 600 /etc/ceph/admin.secret
echo "Mount the file system, Replace ceph-node2 with the hostname or IP address of a Ceph monitor within your Storage Cluster."
sudo mkdir -p /mnt/cephfs
sudo mount -t ceph `curl ifconfig.me`:6789:/ /mnt/cephfs -o name=admin,secretfile=/etc/ceph/admin.secret

#echo "Enable compression"
#radosgw-admin bucket stats
#radosgw-admin zone placement modify \
#	      --rgw-zone default \
#	      --placement-id default-placement \
#	      --storage-class STANDARD \
#	      --compression zlib
