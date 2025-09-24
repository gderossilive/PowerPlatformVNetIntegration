param apimName string
param apiName string = 'petstore'
param apiDisplayName string = 'Petstore Swagger API'
param apiPath string = 'petstore'
param openApiUrl string = 'https://petstore.swagger.io/v2/swagger.json'
param backendUrl string = 'https://petstore.swagger.io/v2'
// Bicep module to import an OpenAPI (Swagger) API into APIM
// Imports the Petstore API from https://petstore.swagger.io/v2 (Swagger 2.0 format)

param userId string // The APIM user ID
param subscriptionName string = 'petstore-subscription-demo'
param subscriptionDisplayName string = 'Petstore Subscription Demo'

// Create backend service configuration
resource backend 'Microsoft.ApiManagement/service/backends@2022-08-01' = {
  name: '${apimName}/${apiName}-backend'
  properties: {
    description: 'Petstore Swagger Backend'
    url: backendUrl
    protocol: 'http'
    title: 'Petstore Backend'
  }
}

resource apiImport 'Microsoft.ApiManagement/service/apis@2022-08-01' = {
  name: '${apimName}/${apiName}'
  properties: {
    displayName: apiDisplayName
    path: apiPath
    format: 'swagger-link-json'
    value: openApiUrl
    protocols: [ 'https' ]
    serviceUrl: backendUrl
  }
  dependsOn: [backend]
}

// Use the separate subscription module to create subscription and retrieve keys
module apiSubscription 'apim-petstore-api-subscription.bicep' = {
  name: 'petstore-subscription'
  params: {
    apimName: apimName
    apiName: apiName
    userId: userId
    subscriptionName: subscriptionName
    subscriptionDisplayName: subscriptionDisplayName
  }
  dependsOn: [apiImport]
}

output apiName string = apiImport.name
output apiId string = apiImport.id
output subscriptionId string = apiSubscription.outputs.subscriptionId
output subscriptionName string = apiSubscription.outputs.subscriptionName
output subscriptionDisplayName string = apiSubscription.outputs.subscriptionDisplayName
