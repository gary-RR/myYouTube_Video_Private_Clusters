param location string=resourceGroup().location
param appName string

@allowed( [
  'yes' 
  'no'
])
param createGateway string

param vnetAddressPrefixes string
param frontendSubnetAddressPrefixes string
param backendSubnetAddressPrefixes string
param gatewaySubnetAddressPrefixes string
param bastionHostAddressPrefixes string
param apiServerSubnetAddressPrefixes string
param clusterSubnetAddressPrefixes string
param internalLoadbalancerServicesSubnetAddressPrefixes string
param vpnClientAddressPrefix string

var tenanatID=subscription().tenantId
// The following returns "https://login.microsoftonline.com" which is a best practice raher hard coding it
var aadTenantURL=environment().authentication.loginEndpoint
var aadTenant='${aadTenantURL}${tenanatID}'

var aadIssuer='https://sts.windows.net/${tenanatID}/'

// Audience: The Application ID of the "Azure VPN" Microsoft Entra Enterprise App.
// Azure Public: 41b23e61-6c1e-4545-b367-cd054e0ed4b4
// Azure Government: 51bb15d4-3a4f-4ebf-9dca-40096fe32426
// Azure Germany: 538ee9e6-310a-468d-afef-ea97365856a9
// Microsoft Azure operated by 21Vianet: 49f817b6-84ae-4cc0-928c-73f27289b3aa
var aadAudience='41b23e61-6c1e-4545-b367-cd054e0ed4b4'

var resourceNameSuffix=uniqueString(resourceGroup().id)
var vnetName= 'vnet-${appName}-${resourceNameSuffix}'
var frontendSubnetName='frontendSubnet'
var backendSubnetName='backendSubnet'
var gatewaySubnetName='gatewaySubnet'
var bastionHostAddressSubnetName='AzureBastionSubnet'
var apiServerSubnetName='apiServerSubnet'
var clusterSubnetName='clusterSubnet'
var internalLoadbalancerServicesSubnetName='internalLoadbalancerServicesSubnet'
var gatewayPublicIPName='pip-gateway-${appName}-${resourceNameSuffix}'
var vpnGateWayName='vpn-${appName}-${resourceNameSuffix}'


resource vnet 'Microsoft.Network/virtualNetworks@2023-04-01' = {
  name: vnetName
  location: location  
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefixes
      ]
    }
    subnets: [
      {
        name: frontendSubnetName
        properties: {
          addressPrefix:  frontendSubnetAddressPrefixes          
        }        
      }
      {
        name: backendSubnetName
        properties: {
          addressPrefix:  backendSubnetAddressPrefixes
        }
      }
      {
        name: gatewaySubnetName
        properties: {
          addressPrefix:  gatewaySubnetAddressPrefixes
        }
      }
      {
        name: bastionHostAddressSubnetName
        properties: {
          addressPrefix:  bastionHostAddressPrefixes
        }
      }
      {
        name: apiServerSubnetName
        properties: {
          addressPrefix:  apiServerSubnetAddressPrefixes
          delegations: [
            {
              id: 'api-server'
              name: 'ipServer'
              properties: {
                serviceName: 'Microsoft.ContainerService/managedClusters'
              }
            }
             
          ]
        }
      }
      {
        name: clusterSubnetName
        properties: {
          addressPrefix:  clusterSubnetAddressPrefixes
        }
      }
      {
        name: internalLoadbalancerServicesSubnetName
        properties: {
          addressPrefix:  internalLoadbalancerServicesSubnetAddressPrefixes
        }
      }
    ]
  }
}

resource gatewayPublicAddress 'Microsoft.Network/publicIPAddresses@2023-05-01' = if(createGateway=='yes') {
  name: gatewayPublicIPName
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

resource vpnGateway 'Microsoft.Network/virtualNetworkGateways@2021-05-01' = if(createGateway=='yes') {
  name: vpnGateWayName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'default'        
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: gatewayPublicAddress.id
          }
          subnet: {
            id: vnet.properties.subnets[2].id 
          }
        }
      }
    ]
    gatewayType: 'Vpn'
    vpnType: 'RouteBased'
    sku: {
      name: 'VpnGw2'
      tier: 'VpnGw2'
    }
    enableBgp: false
    activeActive: false
    vpnClientConfiguration: {
      vpnClientAddressPool: {
        addressPrefixes: [
          vpnClientAddressPrefix 
        ]
      }
      vpnClientProtocols: [
        'OpenVPN'
      ]
      vpnAuthenticationTypes: [
        'AAD'
      ]
      vpnClientRootCertificates: []
      vpnClientRevokedCertificates: []      
      radiusServers: []
      vpnClientIpsecPolicies: []
      aadTenant: aadTenant
      aadAudience: aadAudience
      aadIssuer: aadIssuer
    }    
  }
}


output gatewayId string = ((createGateway=='yes') ? vpnGateway.id : '') 
output vnetName string=vnetName
output vpnGateWayName string=vpnGateWayName
output bastionHostSubnetId string=vnet.properties.subnets[3].id
output apiServerSubnetId string=vnet.properties.subnets[4].id
output clusterSubnetId string=vnet.properties.subnets[5].id
output bastionHostAddressSubnetName string=bastionHostAddressSubnetName


