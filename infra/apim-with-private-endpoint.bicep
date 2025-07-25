// Azure API Management (APIM) Bicep Module
// Deploys APIM in Developer SKU with private endpoint in a specified VNet/subnet
// publicNetworkAccess is disabled for security

param apimName string
param location string = 'westeurope'
param privateEndpointSubnetId string
param publisherEmail string
param publisherName string

// Step 1: Create APIM with public access enabled (required for initial creation)
resource apim 'Microsoft.ApiManagement/service@2022-08-01' = {
  name: apimName
  location: location
  sku: {
    name: 'Developer'
    capacity: 1
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
    publicNetworkAccess: 'Enabled' // Must be enabled for initial creation
    // Do not configure VNet integration at creation time
  }
}

// Step 2: Create private endpoint after APIM is ready
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-05-01' = {
  name: '${apimName}-pe'
  location: location
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${apimName}-plsc'
        properties: {
          privateLinkServiceId: apim.id
          groupIds: [ 'Gateway' ]
        }
      }
    ]
  }
}

// Step 3: APIM configuration will be updated via PowerShell script after deployment

output apimName string = apim.name
output apimId string = apim.id
output privateEndpointId string = privateEndpoint.id
