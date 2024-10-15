# !/bin/bash

# export kubeconfig
export KUBECONFIG="kubeconfig"

INSTALLATION_NAMESPACE="atul-testing"
DOMAIN="atul-testing.mavq.in"
EMAIL="khetanatulz@gmail.com"
DEPLOYMENT_NAMESPACE="atul-testing"
DEPLOYMENT_NAME="atul"

Install Keda from within cluster
kubectl create ns $INSTALLATION_NAMESPACE
kubectl apply -f ./setup/configmap.yaml -n $INSTALLATION_NAMESPACE
kubectl apply -f ./setup/sa.yaml -n $INSTALLATION_NAMESPACE
sed -i -e "s/<NAMESPACE>/$INSTALLATION_NAMESPACE/g" ./setup/cluster-role-binding.yaml
kubectl apply -f ./setup/cluster-role-binding.yaml 
kubectl apply -f ./setup/job.yaml -n $INSTALLATION_NAMESPACE

# Verify Installation of tools
verifyStatus(){
  echo "Testing namespace \"$1\""
  ITEMS=`kubectl get pods -n $1 -o json`
  ITEMS_LENGTH=`kubectl get pods -n $1 -o json | jq '.items | length'`
  echo "Total number of pods $ITEMS_LENGTH"
  ITEMS_LENGTH=`expr $ITEMS_LENGTH - 1`
  for i in `seq 0 $ITEMS_LENGTH`
  do
    echo $ITEMS | jq ".items[$i].metadata.name"
    echo $ITEMS | jq ".items[$i].status.phase"
  done
  echo "----------------------------------------------------------------------------"
}

verifyStatus "nginx"
verifyStatus "keda"
verifyStatus "cert-manager"

# Install and configure certificate
kubectl create ns $DEPLOYMENT_NAMESPACE
IP=`kubectl get -n nginx service/nginx-ingress-nginx-controller  -o jsonpath='{.spec.loadBalancerIP}'`
echo "Map the ip $IP to the domain."
read -n 1 -s -r -p "Press any key to continue: "
sed -i -e "s/<DOMAIN>/$DOMAIN/g" ./setup/certificate.yaml
sed -i -e "s/<EMAIL>/$EMAIL/g" ./setup/certificate.yaml
kubectl apply -f ./setup/certificate.yaml -n $DEPLOYMENT_NAMESPACE

# Deployment
sed -i -e "s/<DOMAIN>/$DOMAIN/g" ./deployment-values.yaml
helm install $DEPLOYMENT_NAME ./custom-chart -n $DEPLOYMENT_NAMESPACE -f deployment-value.yaml

# Keda config
sed -i -e "s/<DEPLOYMENT_NAME>/$DEPLOYMENT_NAME/g" ./keda.yaml
sed -i -e "s/<NAMESPACE>/$DEPLOYMENT_NAMESPACE/g" ./keda.yaml
kubectl apply -f keda.yaml


# Deployment Status
echo "Printing Deploymnet status"
echo "----------------------------------------------------------------------------"
verifyStatus $DEPLOYMENT_NAMESPACE
echo "Deployment metric"
PODS=`kubectl get pods --namespace=$DEPLOYMENT_NAMESPACE --no-headers -o custom-columns=":metadata.name"`
for i in $PODS 
do
  kubectl top pod $i --namespace=$DEPLOYMENT_NAMESPACE
done
echo "----------------------------------------------------------------------------"
echo "HPA config"
kubectl get hpa --namespace=$DEPLOYMENT_NAMESPACE
echo "----------------------------------------------------------------------------"
echo "Monitoring Deployment"
kubectl get pods --namespace=$DEPLOYMENT_NAMESPACE --watch
