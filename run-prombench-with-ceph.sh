#!/bin/sh
#source ./prombench-setup-base.sh

#source ./setup-ceph.sh

echo "Cloning test-infra github ..."
git clone https://github.com/prometheus/test-infra.git
cd test-infra
MON_IP=`curl ifconfig.me`
sed -i 's/6.3.0-beta1/7.3.6/g' prombench/manifests/cluster-infra/grafana_deployment.yaml
sed -i 's#mountPath: /prometheus$#mountPath: /mnt/cephfs#g' prombench/manifests/prombench/benchmark/3b_prometheus-test_deployment.yaml
sed -i 's#volumes:$#&\n      - name: cephfs\n        cephfs:\n          monitors:\n          - MON_IP:6789\n          user: admin\n          secretRef:\n            name: ceph-secret#g' prombench/manifests/prombench/benchmark/3b_prometheus-test_deployment.yaml
sed -i "s/MON_IP/${MON_IP}/g" prombench/manifests/prombench/benchmark/3b_prometheus-test_deployment.yaml
sed -i -z "s#instance-ssd\n          mount#cephfs\n          mount#g" prombench/manifests/prombench/benchmark/3b_prometheus-test_deployment.yaml
make
cd infra

echo "Set the following environment variables and deploy the cluster ..."
sudo ./infra kind cluster create -v PR_NUMBER:$PR_NUMBER -v CLUSTER_NAME:$CLUSTER_NAME -f ../prombench/manifests/cluster_kind.yaml

echo "Remove taint(node-role.kubernetes.io/master) from prombench-control-plane node for deploying nginx-ingress-controller ..."
sudo kubectl taint nodes $CLUSTER_NAME-control-plane node-role.kubernetes.io/master-

echo "Deploy the nginx-ingress-controller, Prometheus-Meta, Loki, Grafana, Alertmanager & Github Notifier ..."
sudo ./infra kind resource apply -v CLUSTER_NAME:$CLUSTER_NAME -v DOMAIN_NAME:$DOMAIN_NAME \
     -v GRAFANA_ADMIN_PASSWORD:$GRAFANA_ADMIN_PASSWORD \
     -v OAUTH_TOKEN="$(printf $OAUTH_TOKEN | base64 -w 0)" \
     -v WH_SECRET="$(printf $WH_SECRET | base64 -w 0)" \
     -v GITHUB_ORG:$GITHUB_ORG -v GITHUB_REPO:$GITHUB_REPO \
     -v SERVICEACCOUNT_CLIENT_EMAIL:$SERVICEACCOUNT_CLIENT_EMAIL \
     -f ../prombench/manifests/cluster-infra

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

# setup Ceph secret key for Prometheus benchmark
echo "Adding ceph-secret.yaml to the prombench setup procedure..."
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
     -f ../prombench/manifests/prombench/benchmark

# Deleting benchmark infra
# sudo ./infra kind cluster delete -v PR_NUMBER:$PR_NUMBER -v CLUSTER_NAME:$CLUSTER_NAME -f ../prombench/manifests/cluster_kind.yaml
