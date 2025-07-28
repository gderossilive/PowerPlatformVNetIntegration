/* Parameters */
@minLength(1)
@maxLength(50)
@description('Name of the Power Platform environment to integrate with the network resources')
param powerPlatformEnvironmentName string

@allowed([
  'primary'
  'secondary'
])
@description('Category of the network resources to configure')
param networkCategory string

@allowed([
  'WE'
  'NE'
])
@description('Suffix for the resources in the case of multiple networks')
param locationSuffix string = 'WE'

@allowed([
  'westeurope'
  'northeurope'
])
@description('Location for all resources')
param location string = 'westeurope'

@description('Address prefixes for the virtual network')
param vnetAddressPrefixes string = '10.10.0.0/23'

@description('Address prefixes for the subnet used for injection')
param injectionSnetAddressPrefixes string = '10.10.0.0/24'

@description('Address prefixes for the subnet used for private endpoints')
param privateEndpointsSnetAddressPrefixes string = '10.10.1.0/24'

@description('Environment name for resource tagging')
param environmentName string = ''

@description('Resource token for unique naming')
param resourceToken string

/* Resources */
// Virtual Network
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2024-01-01' = {
  name: 'az-vnet-${resourceToken}'
  location: location
  tags: {
    'azd-env-name': environmentName
  }
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefixes
      ]
    }
  }
}

// Network Security Groups
resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2020-06-01' = {
  name: 'az-nsg-${resourceToken}'
  location: location
  tags: {
    'azd-env-name': environmentName
  }
  properties: {
    securityRules: []
  }
}

// Subnet
// With delegations to the Microsoft.PowerPlatform/enterprisePolicies service
resource injectionSnet 'Microsoft.Network/virtualNetworks/subnets@2024-01-01' = {
  name: 'snet-injection-${resourceToken}'
  parent: virtualNetwork
  properties: {
    addressPrefix: injectionSnetAddressPrefixes
    delegations: [
      {
        name: 'enterprisePolicies'
        properties: {
          serviceName: 'Microsoft.PowerPlatform/enterprisePolicies'
        }
      }
    ]
    serviceEndpoints: []
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Disabled'
    networkSecurityGroup: {
      id: networkSecurityGroup.id
    }
  }
}

// Private Endpoint Subnet
resource privateEndpointSnet 'Microsoft.Network/virtualNetworks/subnets@2024-01-01' = {
  name: 'snet-pe-${resourceToken}'
  parent: virtualNetwork
  dependsOn: [
    injectionSnet
  ]
  properties: {
    addressPrefix: privateEndpointsSnetAddressPrefixes
    delegations: []
    serviceEndpoints: []
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Disabled'
    networkSecurityGroup: {
      id: networkSecurityGroup.id
    }
  }
}

/* Outputs */
output vnetId string = virtualNetwork.id
output vnetName string = virtualNetwork.name
output injectionSnetId string = injectionSnet.id
output injectionSnetName string = injectionSnet.name
output privateEndpointSnetId string = privateEndpointSnet.id
output privateEndpointSnetName string = privateEndpointSnet.name
