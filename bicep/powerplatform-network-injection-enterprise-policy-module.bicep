/* Parameters */
@minLength(1)
@maxLength(50)
@description('Name of the Power Platform environment group considered in the infrastructure')
param environmentGroupName string

@minLength(1)
@description('Location for all resources')
param location string

@minLength(1)
@maxLength(3)
param suffix string

// Array of objects with the following structure:
/*
{
  id: 'string'
  subnet: {
    name: 'string'
  }
}
*/
@description('Array of objects with the following structure: { id: string; subnet: { name: string; } }')
param vnetSubnets array

/* Resources */
// Enterprise Policy for networkInjection
resource enterprisePolicy 'Microsoft.PowerPlatform/enterprisePolicies@2020-10-30-preview' = {
  name: 'ep-${environmentGroupName}-${suffix}'
  location: location
  kind: 'NetworkInjection'
  properties: {
    networkInjection: {
      virtualNetworks: vnetSubnets
    }
  }
}

/* Outputs */
output enterprisePolicyId string = enterprisePolicy.id
output enterprisePolicyName string = enterprisePolicy.name
