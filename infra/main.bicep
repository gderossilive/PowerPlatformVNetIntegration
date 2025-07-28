/* Deployment scope */
targetScope = 'subscription'

/* Parameters */
@description('Environment name for resource tagging')
param environmentName string = ''

@description('Resource group name')
param resourceGroupName string

@minLength(1)
@maxLength(50)
@description('Name of the Power Platform environment group considered for the VNet integration enterprise policy')
param environmentGroupName string

@allowed([
  'eastus'
  'westus'
  'southafricanorth'
  'southafricawest'
  'uksouth'
  'ukwest'
  'japaneast'
  'japanwest'
  'centralindia'
  'southindia'
  'francecentral'
  'francesouth'
  'westeurope'
  'northeurope'
  'germanynorth'
  'germanywestcentral'
  'switzerlandnorth'
  'switzerlandwest'
  'canadacentral'
  'canadaeast'
  'brazilsouth'
  'southcentralus'
  'australiasoutheast'
  'australiaeast'
  'eastasia'
  'southeastasia'
  'uaecentral'
  'uaenorth'
  'koreasouth'
  'koreacentral'
  'norwaywest'
  'norwayeast'
  'singapore'
  'swedencentral'
])
@description('Primary location for all resources')
param azureLocation string

@allowed([
  'unitedstates'
  'canada'
  'uk'
  'japan'
  'southafrica'
  'india'
  'france'
  'europe'
  'germany'
  'switzerland'
  'brazil'
  'australia'
  'asia'
  'uae'
  'korea'
  'norway'
  'singapore'
  'sweden'
])
@description('Location for the Enterprise policy')
param enterprisePolicyLocation string

@description('Boolean to define if the Enterprise Policy resource should be deployed - to avoid errors if the enterprise policy is already linked to Power Platforme environments')
param deployEnterprisePolicy bool = true

@description('Publisher email for APIM')
param apimPublisherEmail string = 'admin@contoso.com'

@description('Publisher name for APIM')
param apimPublisherName string = 'Contoso Admin'

// Removed unused location parameter for clarity

/* Variables */
param timeStamp string = utcNow()
var resourceToken = substring(uniqueString(timeStamp),0,3)
var rgName = '${resourceGroupName}-${resourceToken}'

var failoverLocations = {
  eastus: 'westus'
  westus: 'eastus'
  southafricanorth: 'southafricawest'
  southafricawest: 'southafricanorth'
  uksouth: 'ukwest'
  ukwest: 'uksouth'
  japaneast: 'japanwest'
  japanwest: 'japaneast'
  centralindia: 'southindia'
  southindia: 'centralindia'
  francecentral: 'francesouth'
  francesouth: 'francecentral'
  westeurope: 'northeurope'
  northeurope: 'westeurope'
  germanynorth: 'germanywestcentral'
  germanywestcentral: 'germanynorth'
  switzerlandnorth: 'switzerlandwest'
  switzerlandwest: 'switzerlandnorth'
  canadacentral: 'canadaeast'
  canadaeast: 'canadacentral'
  brazilsouth: 'southcentralus'
  southcentralus: 'brazilsouth'
  australiasoutheast: 'australiaeast'
  australiaeast: 'australiasoutheast'
  eastasia: 'southeastasia'
  southeastasia: 'eastasia'
  uaecentral: 'uaenorth'
  uaenorth: 'uaecentral'
  koreasouth: 'koreacentral'
  koreacentral: 'koreasouth'
  norwaywest: 'norwayeast'
  norwayeast: 'norwaywest'
  singapore: 'southeastasia'
  swedencentral: 'northeurope'
}

var failoverLocation = failoverLocations[azureLocation]

var networksConfiguration = [
  {
    category: 'primary'
    location: azureLocation
    suffix: 'WE'
    vnetAddressPrefixes: '10.10.0.0/23'
    injectionSnetAddressPrefixes: '10.10.0.0/24'
    privateEndpointsSnetAddressPrefixes: '10.10.1.0/24'
  }
  {
    category: 'secondary'
    location: failoverLocation
    suffix: 'NE'
    vnetAddressPrefixes: '10.20.0.0/23'
    injectionSnetAddressPrefixes: '10.20.0.0/24'
    privateEndpointsSnetAddressPrefixes: '10.20.1.0/24'
  }
]

var APIMName = 'az-apim-${resourceToken}'

/* Resources */
// Resource Group
resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: rgName
  location: azureLocation
  tags: {
    'azd-env-name': environmentName
  }
}

var idName = 'id-${resourceToken}'

// Minimal managed identity for azd compatibility (optional, uses user credentials)
module minimalIdentity 'minimal-identity.bicep' = {
  name: 'minimal-identity'
  scope: resourceGroup
  params: {
    identityName: idName
    location: azureLocation
    environmentName: environmentName
  }
}

// Primary and failover VNet and Subnets
module networks 'vnet-subnet-with-delegation-module.bicep' = [for network in networksConfiguration: {
  name: 'network-${network.category}'
  scope: resourceGroup
  params: {
    powerPlatformEnvironmentName: environmentGroupName
    networkCategory: network.category
    locationSuffix: network.suffix
    location: network.location
    vnetAddressPrefixes: network.vnetAddressPrefixes
    injectionSnetAddressPrefixes: network.injectionSnetAddressPrefixes
    privateEndpointsSnetAddressPrefixes: network.privateEndpointsSnetAddressPrefixes
    environmentName: environmentName
    resourceToken: resourceToken
  }
}]

// APIM with private endpoint in West Europe VNet (primary)
module apimWithPrivateEndpoint 'apim-with-private-endpoint.bicep' = {
  name: APIMName
  scope: resourceGroup
  params: {
    apimName: APIMName
    location: azureLocation
    privateEndpointSubnetId: networks[0].outputs.privateEndpointSnetId
    publisherEmail: apimPublisherEmail
    publisherName: apimPublisherName
  }
}

/*
// Import Petstore API into APIM
module apimImportPetstoreApi 'apim-import-petstore-api.bicep' = {
  name: 'import-petstore-api'
  params: {
    apimName: APIMName
    apiName: 'petstore'
    apiDisplayName: 'Petstore Swagger API'
    apiPath: 'petstore'
    openApiUrl: 'https://petstore3.swagger.io/api/v3/openapi.json'
    userId: '/users/gderossi' // You may need to use the full APIM user resource ID
    subscriptionName: 'petstore-subscription-gderossi'
    subscriptionDisplayName: 'Petstore Subscription for gderossi'
  }
  dependsOn: [apimWithPrivateEndpoint]
}

// Add subscription key for user 'gderossi' to Petstore API

*/

// Array of objects for the Enterprise Policy creation
var vnetSubnets = [
  {
    id: networks[0].outputs.vnetId
    subnet: {
      name: networks[0].outputs.injectionSnetName
    }
  }
  {
    id: networks[1].outputs.vnetId
    subnet: {
      name: networks[1].outputs.injectionSnetName
    }
  }
]

// Enterprise Policy for networkInjection
module enterprisePolicy 'powerplatform-network-injection-enterprise-policy-module.bicep' = if (deployEnterprisePolicy) {
  name: 'enterprise-policy'
  scope: resourceGroup
  params: {
    environmentGroupName: environmentGroupName
    location: enterprisePolicyLocation
    vnetSubnets: vnetSubnets
    suffix: resourceToken // Use the suffix from the primary network
  }
}

/* Outputs */
output RESOURCE_GROUP_ID string = resourceGroup.id
output primaryVnetName string = networks[0].outputs.vnetName
output primarySubnetName string = networks[0].outputs.injectionSnetName
output failoverVnetName string = networks[1].outputs.vnetName
output failoverSubnetName string = networks[1].outputs.injectionSnetName
output resourceGroup string = resourceGroup.name

output apimName string = apimWithPrivateEndpoint.outputs.apimName
output apimId string = apimWithPrivateEndpoint.outputs.apimId
output apimPrivateEndpointId string = apimWithPrivateEndpoint.outputs.privateEndpointId
output privateEndpointSubnetId string = networks[0].outputs.privateEndpointSnetId
output enterprisePolicyName string = 'ep-${environmentGroupName}-${resourceToken}'

// Minimal managed identity outputs for azd compatibility
output AZURE_CLIENT_ID string = minimalIdentity.outputs.clientId
output AZURE_PRINCIPAL_ID string = minimalIdentity.outputs.principalId

/*
output petstoreApiName string = apimImportPetstoreApi.outputs.apiName
output petstoreApiId string = apimImportPetstoreApi.outputs.apiId

output petstoreApiSubscriptionId string = apimImportPetstoreApi.outputs.subscriptionId
output petstoreApiPrimaryKey string = apimImportPetstoreApi.outputs.primaryKey
output petstoreApiSecondaryKey string = apimImportPetstoreApi.outputs.secondaryKey
*/
