param location string=resourceGroup().location
param adminUsername string
param patchMode string
param rebootSetting string
param sshKeyName string
param vnetName string



var vmWLinuxName='vm-${vnetName}-jumpbox'
var nicNameLinux='nic-${vmWLinuxName}'
var frontendSubnetId=vnet.properties.subnets[0].id 

resource vnet 'Microsoft.Network/virtualNetworks@2021-05-01'  existing = {
  name: vnetName
}

resource sshKey 'Microsoft.Compute/sshPublicKeys@2023-09-01' existing = {
  name: sshKeyName  
}

resource nicLinuxServer1 'Microsoft.Network/networkInterfaces@2020-06-01' =  {
  name: nicNameLinux
  location: location
  properties: {
    ipConfigurations: [
      {
        name: '${vmWLinuxName}vmip'
        properties: {
          privateIPAllocationMethod: 'Dynamic'          
          subnet: {
            id: frontendSubnetId //frontendSubnet.id
          }
        }
      }
    ]
  }  
}

resource ubuntuVM 'Microsoft.Compute/virtualMachines@2023-09-01' =  {
  name: vmWLinuxName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_DS1_v2' // Choose an appropriate VM size
    }
    osProfile: {
      adminUsername: adminUsername      
      computerName: vmWLinuxName
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: sshKey.properties.publicKey //adminPublicKey
            }
          ]
        }
        patchSettings: {
          patchMode: patchMode
          automaticByPlatformSettings: {
            rebootSetting: rebootSetting
          }
        }
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: 'UbuntuServer'
        sku: '18.04-LTS'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nicLinuxServer1.id
          properties: {
            primary: true
          }
        }
      ]
    }
  }
}

output vmPrivateIPAddress string = nicLinuxServer1.properties.ipConfigurations[0].properties.privateIPAddress
output vmId string=ubuntuVM.id

