

#Set the Resource Group*****************************************************************************************************************************************
resourceGroup='rs-AKS-Private-Cloud-test'

# Install kubectl***********************************************************************************************************************************************
sudo snap install kubectl --classic
# **************************************************************************************************************************************************************

#Install Azure cli**********************************************************************************************************************************************
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
# *****************************************************************************************************************************************************************

#Login to Azure*************************Log into Azure******************************************************
az login
#In case yo have multiple subscriptions, set it to the correct subscription. Change the subscription below to yours: 
az account set  --subscription e6566f19-3eb5-436b-904f-fdd540b4fd58
#**********************************************************************************************

az aks get-credentials -g $resourceGroup -n privateCluster1 

kubectl get nodes -o wide

kubectl create deployment hello-world --image=gcr.io/google-samples/hello-app:1.0
kubectl scale --replicas=3 deployment/hello-world

#Check deployments
kubectl get deployments

#Creat a service with internal load balancer
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: hello-world
  annotations:
    service.beta.kubernetes.io/azure-load-balancer-internal: "true" 
    service.beta.kubernetes.io/azure-load-balancer-internal-subnet: 'internalLoadbalancerServicesSubnet'  
  labels:
    app: hello-world
spec:
  type: LoadBalancer
  selector:
    app: hello-world
  ports:
  - port: 8080
    protocol: TCP
    targetPort: 8080
EOF


kubectl get services -o wide 

port=$(kubectl get service hello-world -o jsonpath='{ .spec.ports[].port}') 
loadBalancerIP=$(kubectl get service hello-world -o jsonpath='{ .status.loadBalancer.ingress[].ip}') 

curl http://$loadBalancerIP:$port


