// Bicep module to add a subscription key to an APIM API for a specific user
// This module creates a subscription for the Petstore API
// Note: Keys should be retrieved via Azure CLI or stored in Key Vault for security

param apimName string
param apiName string = 'petstore'
param userId string
param subscriptionName string = 'petstore-subscription-demo'
param subscriptionDisplayName string = 'Petstore Subscription Demo'

resource apiSubscription 'Microsoft.ApiManagement/service/subscriptions@2022-08-01' = {
  name: '${apimName}/${subscriptionName}'
  properties: {
    displayName: subscriptionDisplayName
    scope: '/apis/${apiName}'
    ownerId: resourceId('Microsoft.ApiManagement/service/users', apimName, userId)
    state: 'active'
    allowTracing: false
  }
}

output subscriptionId string = apiSubscription.id
output subscriptionName string = subscriptionName
output subscriptionDisplayName string = subscriptionDisplayName
