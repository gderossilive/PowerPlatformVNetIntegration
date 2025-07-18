/* Deployment scope */
targetScope = 'resourceGroup'

/* Parameters */
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

@description('Boolean to define if the Key Vault resource should be deployed - to avoid errors if the Key Vault is already created')
param deployKeyVaultForTests bool = true

@minLength(1)
@maxLength(3)
param suffix string 

@description('Base name for all resources')
param baseName string = 'pythonfunc'

@description('Environment name (dev, test, prod)')
param environment string = 'dev'

@description('Location for resources')
param location string = resourceGroup().location

/* Variables */
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
  swedencentral: 'swedencentral'
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

/* Resources */
// Primary and failover VNet and Subnets
module networks 'vnet-subnet-with-delegation-module.bicep' = [for network in networksConfiguration: {
  name: 'network-${network.category}'
  params: {
    powerPlatformEnvironmentName: environmentGroupName
    networkCategory: network.category
    locationSuffix: network.suffix
    location: network.location
    vnetAddressPrefixes: network.vnetAddressPrefixes
    injectionSnetAddressPrefixes: network.injectionSnetAddressPrefixes
    privateEndpointsSnetAddressPrefixes: network.privateEndpointsSnetAddressPrefixes
  }
}]

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
  params: {
    environmentGroupName: environmentGroupName
    location: enterprisePolicyLocation
    vnetSubnets: vnetSubnets
    suffix: suffix // Use the suffix from the primary network
  }
}

// Generate unique names for resources
var functionAppName = '${baseName}-${environment}-func'
var storageAccountName = '${replace(baseName, '-', '')}${environment}sa'



/* Outputs */
output primaryVnetId string = networks[0].outputs.vnetId
output primarySubnetId string = networks[0].outputs.injectionSnetId
output primarySubnetName string = networks[0].outputs.injectionSnetName
output failoverVnetId string = networks[1].outputs.vnetId
output failoverSubnetId string = networks[1].outputs.injectionSnetId
output failoverSubnetName string = networks[1].outputs.injectionSnetName
output enterprisePolicyId string = deployEnterprisePolicy ? enterprisePolicy.outputs.enterprisePolicyId : 'Enterprise Policy not deployed'
output enterprisePolicyName string = deployEnterprisePolicy ? enterprisePolicy.outputs.enterprisePolicyName : 'Enterprise Policy not deployed'
output deployKeyVaultForTests bool = deployKeyVaultForTests

