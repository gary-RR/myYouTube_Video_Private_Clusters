param location string=resourceGroup().location
param vnetName string
param managedKubeNetworkIdentityName string
param apiServerSubnetName string
param clusterSubnetName string
param internalLoadbalancerServicesSubnetName string

var networkContributoreRoleId=subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4d97b98b-1d4f-4787-a291-c67834d212e7')

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: managedKubeNetworkIdentityName
  location: location 
  
}

resource vnet 'Microsoft.Network/virtualNetworks@2021-05-01'  existing = {
  name: vnetName 
}

resource apiServerSubnet 'Microsoft.Network/virtualNetworks/subnets@2020-11-01' existing = {
  name: apiServerSubnetName
  parent: vnet
}

resource clusterSubnet 'Microsoft.Network/virtualNetworks/subnets@2020-11-01' existing = {
  name: clusterSubnetName
  parent: vnet
}


resource internalLbSubnet 'Microsoft.Network/virtualNetworks/subnets@2020-11-01' existing = {
  name: internalLoadbalancerServicesSubnetName
  parent: vnet
}



resource apiServerNetworkContributorAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('networkContributorAssignment1')
  scope: apiServerSubnet
  properties: {
    roleDefinitionId: networkContributoreRoleId 
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal' 
  }
}

resource clusterNetworkContributorAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('networkContributorAssignment2')
  scope: clusterSubnet
  properties: {
    roleDefinitionId: networkContributoreRoleId 
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal' 
  }
}


resource internalLoadbalancerContributorAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('networkContributorAssignment3')
  scope: internalLbSubnet
  properties: {
    roleDefinitionId: networkContributoreRoleId 
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal' 
  }
}


output principalId string=managedIdentity.id
