#!/bin/bash
export MSYS_NO_PATHCONV=1
location='centralus' #'westus3'
env='test'
resourceGroup='rs-AKS-Private-Cloud-'$env
managedKubeNetworkIdentityName='kubeNetworkManager-'$env
sshkey_name='jumpBoxSshKey'

#*********************Register the 'EnableAPIServerVnetIntegrationPreview' feature flag (Do this only if 'aks cluster with API Server VNet Integration IS STILL IN BETA')******

#1- Register the EnableAPIServerVnetIntegrationPreview feature flag using the az feature register command. It takes a few minutes for the status to show Registered.
az feature register --namespace "Microsoft.ContainerService" --name "EnableAPIServerVnetIntegrationPreview"


#2- Verify the registration status using the az feature show command:
az feature show --namespace "Microsoft.ContainerService" --name "EnableAPIServerVnetIntegrationPreview"

#3- #When the status reflects Registered, refresh the registration of the Microsoft.ContainerService resource provider using the az provider register command.
az provider register --namespace Microsoft.ContainerService

#*****************************************************************************************************************************************************************************

#*****************************************Create a resource group******************************************************************************************************

az group create --name ${resourceGroup} --location $location --query id --output tsv

#***********************************************************************************************************************************************************************

#*****************************************Create the Vnet and VPN Gateway************************************************************************************************

az deployment group create --resource-group ${resourceGroup}   --template-file create_vnet_and_vpn_gateway.bicep --parameters @create_vnet_and_vpn_gateway_params.json \
                                                                                                                 --parameters createGateway=yes
#Capture the returned values from bicep template execusion
vnetName=$(az deployment group show -g ${resourceGroup}  -n create_vnet_and_vpn_gateway --query "properties.outputs.vnetName.value" -o tsv)
clusterSubnetId=$(az deployment group show -g ${resourceGroup}  -n create_vnet_and_vpn_gateway --query "properties.outputs.clusterSubnetId.value" -o tsv)
apiServerSubnetId=$(az deployment group show -g ${resourceGroup}  -n create_vnet_and_vpn_gateway --query "properties.outputs.apiServerSubnetId.value" -o tsv)
vpnGateWayName=$(az deployment group show -g ${resourceGroup}  -n create_vnet_and_vpn_gateway --query "properties.outputs.vpnGateWayName.value" -o tsv)
bastionHostSubnetId=$(az deployment group show -g ${resourceGroup}  -n create_vnet_and_vpn_gateway --query "properties.outputs.bastionHostSubnetId.value" -o tsv)
bastionSubnetName=$(az deployment group show -g ${resourceGroup}  -n create_vnet_and_vpn_gateway --query "properties.outputs.bastionHostAddressSubnetName.value" -o tsv)

#*************************************************************************************************************************************************************************


#*****************************************Download the VPN cline config file*************************************************************************************************

# Download client VPN config file
clientVPNConfigFileURL=$(az network vnet-gateway vpn-client generate --name $vpnGateWayName --resource-group ${resourceGroup})
clientVPNConfigFileURL="${clientVPNConfigFileURL//\"/}"
echo $clientVPNConfigFileURL
curl -o vpnClientConfig.zip $clientVPNConfigFileURL
unzip -o vpnClientConfig.zip 
#***************************************************************************************************************************************************************************

#***************************************Create a managed identity**********************************************************************************************************

managedKubeNetworkIdentityResourceId=$(az deployment group create --resource-group ${resourceGroup}   --template-file create_managedId_and_grant_subnet_access.bicep \
               --parameters @create_managedId_and_grant_subnet_access_params.json --parameters vnetName=$vnetName --query "properties.outputs.principalId.value" -o tsv)

echo $managedKubeNetworkIdentityResourceId

#*****************************************************************************************************************************************************************************

#********************************Create a private AKS manged cluster**********************************************************************************************************

az aks create -n privateCluster1 \
-g $resourceGroup  \
-l $location \
--network-plugin azure \
--enable-private-cluster \
--enable-apiserver-vnet-integration \
--vnet-subnet-id $clusterSubnetId \
--apiserver-subnet-id $apiServerSubnetId \
--assign-identity $managedKubeNetworkIdentityResourceId \
--service-cidr 10.0.0.0/24 \
--generate-ssh-keys 

#***************************************************************************************************************************************************************************

#***************************Create a key for vm authentication****************************************************************************************************************

az sshkey create --name $sshkey_name --resource-group $resourceGroup

#****************************************************************************************************************************************************************************

#**************************Create an Ububtu vm "jomp bix"********************************************************************************************************************

#The reson why a jump box is required is that the API Serve name in the config file can only be resolved in the Vnet.
az deployment group create --resource-group ${resourceGroup}   --template-file create_vm.bicep --parameters @create_vm_params.json \
                           --parameters vnetName=${vnetName} sshKeyName=$sshkey_name 

vmPrivateIPAddress=$(az deployment group show -g ${resourceGroup}  -n create_vm --query "properties.outputs.vmPrivateIPAddress.value" -o tsv)

vmId=$(az deployment group show -g ${resourceGroup}  -n create_vm --query "properties.outputs.vmId.value" -o tsv)


#ssh into the vm
ssh -i ~/.ssh/1714931795_3918278 gary@$vmPrivateIPAddress

#*****************************************************************************************************************************************************************************

#************************************Create an Azure Bastion host. This is optional in case you don't want to set up a VPN Gateway*********************************************

#This requires "standard sku" with "Native client support" enabled.
bastionHostname='bas-'$vnetName

az deployment group create --resource-group ${resourceGroup}   --template-file create_bastion_host.bicep \
                                           --parameters vnetName=$vnetName bastionSubnetName=$bastionSubnetName bastionHostName=$bastionHostname

#Install ssh extension (need to run it only once)
az extension add -n ssh

az network bastion ssh --name $bastionHostname --resource-group ${resourceGroup} --target-resource-id $vmId \
                       --auth-type "ssh-key" --username "gary" --ssh-key '~/.ssh/1714931795_3918278'

#****************************************************************************************************************************************************************************


#*************************Clean up********************************************************************************************************************************************

#Clean up
az group delete --name ${resourceGroup} --yes --no-wait

