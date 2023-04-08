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
echo 'export PR_NUMBER=12151' >> ~/.profile
echo 'export RELEASE=v2.43.0' >> ~/.profile

echo 'export GRAFANA_ADMIN_PASSWORD=password' >> ~/.profile
echo 'export DOMAIN_NAME=" "' >> ~/.profile
echo 'export OAUTH_TOKEN=" "' >> ~/.profile
echo 'export WH_SECRET=" "' >> ~/.profile
echo 'export GITHUB_ORG=prometheus' >> ~/.profile
echo 'export GITHUB_REPO=prometheus' >> ~/.profile
echo 'export SERVICEACCOUNT_CLIENT_EMAIL=seungwoo_son@uml.edu' >> ~/.profile

. ~/.profile

echo "Install GO ..."
wget -c https://go.dev/dl/go1.20.3.linux-amd64.tar.gz -O - | sudo tar -xz -C /usr/local

echo "Install KIND ..."
#go install sigs.k8s.io/kind@v0.18.0
go install sigs.k8s.io/kind@v0.8.1

echo "Install kubernetes ..."
#curl -LO "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl"
curl -LO "https://storage.googleapis.com/kubernetes-release/release/v1.18.2/bin/linux/amd64/kubectl"

chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl
