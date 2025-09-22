/* Parameters */
@description('Name prefix for function app resources')
param functionAppPrefix string

@description('Location for all resources')
param location string

@description('Environment name for resource tagging')
param environmentName string = ''

// Function App subnet ID parameter removed - VNet integration configured post-deployment

@description('Storage account name for function app')
param storageAccountName string

// Removed Application Insights parameter to minimize costs

/* Variables */
var functionAppName = '${functionAppPrefix}-petstore'
var appServicePlanName = '${functionAppPrefix}-plan'

/* Resources */

// App Service Plan for Function App (Premium EP1 - minimum for reliable VNet integration)
resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: appServicePlanName
  location: location
  tags: {
    'azd-env-name': environmentName
  }
  sku: {
    name: 'EP1'
    tier: 'ElasticPremium'
    size: 'EP1'
    family: 'EP'
    capacity: 1
  }
  properties: {
    reserved: false
    maximumElasticWorkerCount: 20
  }
}

// Storage Account for Function App  
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  tags: {
    'azd-env-name': environmentName
  }
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'Storage'
  properties: {
    supportsHttpsTrafficOnly: true
    defaultToOAuthAuthentication: false
    allowBlobPublicAccess: true // Temporarily allow public access for deployment
    minimumTlsVersion: 'TLS1_2'
    networkAcls: {
      bypass: 'AzureServices'
      virtualNetworkRules: []
      ipRules: []
      defaultAction: 'Allow' // Allow all access during deployment
    }
  }
}

// File Services for Storage Account
resource fileServices 'Microsoft.Storage/storageAccounts/fileServices@2023-05-01' = {
  name: 'default'
  parent: storageAccount
  properties: {}
}

// File Share for Function App Content
resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-05-01' = {
  name: toLower(functionAppName)
  parent: fileServices
  properties: {
    shareQuota: 5120 // 5GB quota
    enabledProtocols: 'SMB'
  }
}

// Removed Application Insights and Log Analytics Workspace to minimize costs

// Function App with simplified configuration for deployment
resource functionApp 'Microsoft.Web/sites@2023-12-01' = {
  name: functionAppName
  location: location
  tags: {
    'azd-env-name': environmentName
  }
  kind: 'functionapp'
  properties: {
    serverFarmId: appServicePlan.id
    reserved: false
    httpsOnly: true
    // VNet integration will be configured post-deployment to avoid storage access issues
    siteConfig: {
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=${environment().suffixes.storage}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=${environment().suffixes.storage}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(functionAppName)
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        // Application Insights removed to minimize costs
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'node'
        }
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '~18'
        }
      ]
      cors: {
        allowedOrigins: ['*']
        supportCredentials: false
      }
      use32BitWorkerProcess: false
      netFrameworkVersion: 'v6.0'
      functionAppScaleLimit: 200
      minimumElasticInstanceCount: 0
    }
  }
}

// Role assignment removed for initial deployment - can be added post-deployment

/* Outputs */
output functionAppId string = functionApp.id
output functionAppName string = functionApp.name
output functionAppDefaultHostName string = functionApp.properties.defaultHostName
output functionAppUrl string = 'https://${functionApp.properties.defaultHostName}'
output storageAccountId string = storageAccount.id
output storageAccountName string = storageAccount.name
// Removed Application Insights and Log Analytics outputs to minimize costs
