param apimName string
param apiName string = 'petstore'
param apiDisplayName string = 'Petstore Swagger API'
param apiPath string = 'petstore'
param openApiUrl string = 'https://petstore3.swagger.io/api/v3/openapi.json'
// Bicep module to import an OpenAPI (Swagger) API into APIM
// Imports the Petstore API from https://petstore3.swagger.io/api/v3


param userId string // The APIM user ID for 'gderossi'
param subscriptionName string = 'petstore-subscription-gderossi'
param subscriptionDisplayName string = 'Petstore Subscription for gderossi'

resource apiImport 'Microsoft.ApiManagement/service/apis@2022-08-01' = {
  name: '${apimName}/${apiName}'
  properties: {
    displayName: apiDisplayName
    path: apiPath
    format: 'openapi'
    value: openApiUrl
    protocols: [ 'https' ]
  }
  dependsOn: []
}

resource apiSubscription 'Microsoft.ApiManagement/service/subscriptions@2022-08-01' = {
  name: '${apimName}/${subscriptionName}'
  properties: {
    displayName: subscriptionDisplayName
    scope: '/apis/${apiName}'
    ownerId: userId
    state: 'active'
    allowTracing: false
  }
  dependsOn: [apiImport]
}


output apiName string = apiImport.name
output apiId string = apiImport.id
output subscriptionId string = apiSubscription.id
output primaryKey string = apiSubscription.properties.primaryKey
output secondaryKey string = apiSubscription.properties.secondaryKey
