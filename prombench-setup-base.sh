#!/bin/sh
echo "Install Docker..."
sudo apt-get update
sudo apt-get -y install \
     apt-transport-https \
     ca-certificates \
     curl \
     gnupg \
     software-properties-common

echo "Add Docker’s official GPG key..."
#curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
#sudo apt-key fingerprint 0EBFCD88
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo "Set up the stable repository ..."
#sudo add-apt-repository \
#     "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "Install docker engine ..."
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

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
wget -c https://dl.google.com/go/go1.20.3.linux-amd64.tar.gz -O - | sudo tar -xz -C /usr/local

echo "Install KIND ..."
# The following line was for older versions, lower than 1.17
# GO111MODULE="on" go get sigs.k8s.io/kind@v0.9.0
go install sigs.k8s.io/kind@v0.18.0 && kind create cluster

echo "Install kubernetes ..."
## The following three lines were for old scripts
#curl -LO "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl"
#chmod +x ./kubectl
#sudo mv ./kubectl /usr/local/bin/kubectl
# Download the latest release
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
# validate the binary
curl -LO "https://dl.k8s.io/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"
echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check
# Install kubectl
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
# Test to ensure the version installed is up-to-date
kubectl version --client
