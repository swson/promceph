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

echo ""
echo "Bootstrap your cluster..."
sudo mkdir -p /etc/ceph
# Replace <ip> with the IP address of your first manager node within your cluster (node1)
sudo ./cephadm bootstrap --mon-ip <ip>
echo "Check ceph status..."
sudo ceph status

echo ""
echo "Adding more nodes..."
# before you can add a new node to your cluster,
# you need to copy the ceph ssh key from your manager node into your new server.
sudo ssh-copy-id -f -i /etc/ceph/ceph.pub root@node2
sudo ceph orch host add node2

echo ""
echo "Adding storage, at lease 3 OSDs..."
echo "list the current status..."
sudo ceph orch device ls
echo "Tell Ceph to consume any available and unused storage device..."
sudo ceph orch apply osd --all-available-devices

echo ""
echo "Mounting ceph file system..."
sudo su -
echo "Creating storage pools..."
ceph osd pool create cephfs_data (erasure)
ceph osd pool create cephfs_metadata
echo "Creating the new ceph file system..."
ceph fs new cephfs cephfs_metadata cephfs_data # (if erasure: ceph osd pool set cephfs_data allow_ec_overwrites true)
echo "Create a ceph metadata server..."
# ceph orch apply mds *<fs-name>* --placement="*<num-daemons>* [*<host1>* ...]"
ceph orch apply mds cephfs --placement="1 node1"
echo "Checking the status of the Ceph MDS..."
ceph mds stat

echo ""
echo "Store the secret key used for admin authentication into a file that can be used for mounting the Ceph FS"
echo $(sed -n 's/.*key *= *\([^ ]*.*\)/\1/p' < /etc/ceph/ceph.client.admin.keyring) > /etc/ceph/admin.secret
chmod 600 /etc/ceph/admin.secret
echo "Mount the file system, Replace ceph-node2 with the hostname or IP address of a Ceph monitor within your Storage Cluster."
mkdir -p /mnt/cephfs
mount -t ceph ceph-node2:6789:/ /mnt/cephfs -o name=admin,secretfile=/etc/ceph/admin.secret

#echo "Enable compression"
#radosgw-admin bucket stats
#radosgw-admin zone placement modify \
#	      --rgw-zone default \
#	      --placement-id default-placement \
#	      --storage-class STANDARD \
#	      --compression zlib
