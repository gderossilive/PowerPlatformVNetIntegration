// Minimal managed identity for azd compatibility
param identityName string
param location string
param environmentName string

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: identityName
  location: location
  tags: {
    'azd-env-name': environmentName
  }
}

output clientId string = identity.properties.clientId
output principalId string = identity.properties.principalId
