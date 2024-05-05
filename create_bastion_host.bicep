param location string = resourceGroup().location
param vnetName string
param bastionSubnetName string
param bastionHostName string

resource bastion 'Microsoft.Network/bastionHosts@2023-09-01' = {
  name: bastionHostName  
  location: location
  sku: {
    name: 'Standard'
  }  
  properties: {    
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, bastionSubnetName)
          }
          publicIPAddress: {
            id: bastionPublicAddress.id
          } 
        }
      }
    ]
    disableCopyPaste: false
    enableTunneling: true    
  }
}

resource bastionPublicAddress 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
  name: 'bastionPublicIP'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'  
  }
}

output bastionInfo object = {
  value: {
    name: bastion.name
    location: bastion.location
    subnetId: bastion.properties.ipConfigurations[0].properties.subnet.id
  }
}
