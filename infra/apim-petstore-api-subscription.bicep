// Bicep module to add a subscription key to an APIM API for a specific user
// This module creates a subscription for the Petstore API and assigns it to the user 'gderossi'

param apimName string
param apiName string = 'petstore'
param userId string // The APIM user ID for 'gderossi'
param subscriptionName string = 'petstore-subscription-gderossi'
param subscriptionDisplayName string = 'Petstore Subscription for gderossi'

resource apiSubscription 'Microsoft.ApiManagement/service/subscriptions@2022-08-01' = {
  name: '${apimName}/${subscriptionName}'
  properties: {
    displayName: subscriptionDisplayName
    scope: '/apis/${apiName}'
    ownerId: userId
    state: 'active'
    allowTracing: false
  }
}

output subscriptionId string = apiSubscription.id
output primaryKey string = apiSubscription.properties.primaryKey
output secondaryKey string = apiSubscription.properties.secondaryKey
