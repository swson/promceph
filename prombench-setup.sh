#!/bin/sh
echo "Install Docker..."
sudo apt-get update
sudo apt-get -y install \
     apt-transport-https \
     ca-certificates \
     curl \
     gnupg-agent \
     software-properties-common

echo "Add Docker’s official GPG key..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo apt-key fingerprint 0EBFCD88

echo "Set up the stable repository ..."
sudo add-apt-repository \
     "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

echo "Install docker engine ..."
sudo apt-get update
sudo apt-get -y install docker-ce docker-ce-cli containerd.io

echo "Check docker version ..."
sudo docker version

echo "1.6 Add current user to the ‘docker’ group so that you don’t have to prefix ‘sudo’ (SSH again to take effect) "
sudo usermod -aG docker $USER

echo "Move Docker to /mydata ..."
sudo systemctl stop docker
sudo mv /var/lib/docker /mydata/docker
sudo ln -s /mydata/docker /var/lib/docker
sudo systemctl start docker

echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.profile
echo 'export PATH=$PATH:/users/$USER/go/bin' >> ~/.profile
echo 'export CLUSTER_NAME=prombench' >> ~/.profile
echo 'export PR_NUMBER=8258' >> ~/.profile
echo 'export RELEASE=v2.23.0' >> ~/.profile

echo 'export GRAFANA_ADMIN_PASSWORD=password' >> ~/.profile
echo 'export DOMAIN_NAME=" "' >> ~/.profile
echo 'export OAUTH_TOKEN=" "' >> ~/.profile
echo 'export WH_SECRET=" "' >> ~/.profile
echo 'export GITHUB_ORG=prometheus' >> ~/.profile
echo 'export GITHUB_REPO=prometheus' >> ~/.profile
echo 'export SERVICEACCOUNT_CLIENT_EMAIL=seungwoo_son@uml.edu' >> ~/.profile

. ~/.profile

echo "Install GO ..."
wget -c https://dl.google.com/go/go1.14.2.linux-amd64.tar.gz -O - | sudo tar -xz -C /usr/local

echo "Install KIND ..."
GO111MODULE="on" go get sigs.k8s.io/kind@v0.9.0

echo "Install kubernetes ..."
curl -LO "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl

echo "Cloning test-infra github ..."
git clone https://github.com/prometheus/test-infra.git
cd test-infra
sed -i 's/6.3.0-beta1/7.3.6/g' prombench/manifests/cluster-infra/grafana_deployment.yaml
make
cd infra

echo "Set the following environment variables and deploy the cluster ..."
sudo ./infra kind cluster create -v PR_NUMBER:$PR_NUMBER -v CLUSTER_NAME:$CLUSTER_NAME -f ~/test-infra/prombench/manifests/cluster_kind.yaml

echo "Remove taint(node-role.kubernetes.io/master) from prombench-control-plane node for deploying nginx-ingress-controller ..."
sudo kubectl taint nodes $CLUSTER_NAME-control-plane node-role.kubernetes.io/master-

echo "Deploy the nginx-ingress-controller, Prometheus-Meta, Loki, Grafana, Alertmanager & Github Notifier ..."
sudo ./infra kind resource apply -v CLUSTER_NAME:$CLUSTER_NAME -v DOMAIN_NAME:$DOMAIN_NAME \
     -v GRAFANA_ADMIN_PASSWORD:$GRAFANA_ADMIN_PASSWORD \
     -v OAUTH_TOKEN="$(printf $OAUTH_TOKEN | base64 -w 0)" \
     -v WH_SECRET="$(printf $WH_SECRET | base64 -w 0)" \
     -v GITHUB_ORG:$GITHUB_ORG -v GITHUB_REPO:$GITHUB_REPO \
     -v SERVICEACCOUNT_CLIENT_EMAIL:$SERVICEACCOUNT_CLIENT_EMAIL \
     -f ~/test-infra/prombench/manifests/cluster-infra

sudo chown $(id -u):$(id -g) $HOME/.kube/config

echo "Set NODE_NAME, INTERNAL_IP and NODE_PORT environment variable ..."
echo "export NODE_NAME=$(kubectl get pod -l "app=grafana" -o=jsonpath='{.items[*].spec.nodeName}')" >> ~/.profile
. ~/.profile
echo "export INTERNAL_IP=$(kubectl get nodes $NODE_NAME -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')" >> ~/.profile
echo "export NODE_PORT=$(kubectl get -o jsonpath="{.spec.ports[0].nodePort}" services grafana)" >> ~/.profile

. ~/.profile

echo "Grafana: http://$INTERNAL_IP:$NODE_PORT/grafana"
echo "Prometheus: http://$INTERNAL_IP:$NODE_PORT/prometheus-meta"
echo "Logs: http://$INTERNAL_IP:$NODE_PORT/grafana/explore"

sudo apt-get -y install firefox xauth jq

CEPH_SECRET=`sudo cat /etc/ceph/admin.secret | base64 -w 0`
echo "apiVersion: v1" > 1d_ceph-secret.yaml
echo "kind: Secret" >> 1d_ceph-secret.yaml
echo "metadata:" >> 1d_ceph-secret.yaml
echo "  name: ceph-secret" >> 1d_ceph-secret.yaml
echo "  namespace: prombench-{{ .PR_NUMBER }}" >> 1d_ceph-secret.yaml
echo "data:" >> 1d_ceph-secret.yaml
echo "  key: $CEPH_SECRET" >> 1d_ceph-secret.yaml
mv 1d_ceph-secret.yaml ../prombench/manifests/prombench/benchmark

echo "Start a benchmarking test manually ..."
# Set the following environment variables
# Deploy the k8s objects
sudo ./infra kind resource apply -v CLUSTER_NAME:$CLUSTER_NAME \
     -v PR_NUMBER:$PR_NUMBER -v RELEASE:$RELEASE -v DOMAIN_NAME:$DOMAIN_NAME \
     -v GITHUB_ORG:${GITHUB_ORG} -v GITHUB_REPO:${GITHUB_REPO} \
     -f ~/test-infra/prombench/manifests/prombench/benchmark

# Deleting benchmark infra
# sudo ./infra kind cluster delete -v PR_NUMBER:$PR_NUMBER -v CLUSTER_NAME:$CLUSTER_NAME -f ~/test-infra/prombench/manifests/cluster_kind.yaml
