/* Parameters */
@description('Name prefix for container apps resources')
param containerAppsPrefix string

@description('Location for all resources')
param location string

@description('Environment name for resource tagging')
param environmentName string = ''

@description('Private endpoint subnet ID for Container Apps Environment')
param privateEndpointSubnetId string

/* Variables */
var containerAppEnvName = '${containerAppsPrefix}-env'
var containerAppName = '${containerAppsPrefix}-petstore'

/* Resources */

// Log Analytics Workspace
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: '${containerAppsPrefix}-logs'
  location: location
  tags: {
    'azd-env-name': environmentName
  }
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    features: {
      searchVersion: 1
      legacy: 0
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}

// Container Apps Environment with VNet integration
resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: containerAppEnvName
  location: location
  tags: {
    'azd-env-name': environmentName
  }
  properties: {
    vnetConfiguration: {
      infrastructureSubnetId: privateEndpointSubnetId
      internal: true // This makes it only accessible via private IP
    }
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspace.properties.customerId
        sharedKey: logAnalyticsWorkspace.listKeys().primarySharedKey
      }
    }
  }
}

// Petstore Container App
resource petstoreContainerApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: containerAppName
  location: location
  tags: {
    'azd-env-name': environmentName
  }
  properties: {
    managedEnvironmentId: containerAppsEnvironment.id
    configuration: {
      ingress: {
        external: false // Internal ingress only (private IP)
        targetPort: 8080
        traffic: [
          {
            weight: 100
            latestRevision: true
          }
        ]
      }
    }
    template: {
      containers: [
        {
          image: 'swaggerapi/petstore3:unstable'
          name: 'petstore'
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
          env: [
            {
              name: 'SWAGGER_HOST'
              value: 'http://petstore.swagger.io'
            }
            {
              name: 'SWAGGER_BASE_PATH'
              value: '/api/v3'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 3
        rules: [
          {
            name: 'http-scaler'
            http: {
              metadata: {
                concurrentRequests: '10'
              }
            }
          }
        ]
      }
    }
  }
}

/* Outputs */
output containerAppsEnvironmentId string = containerAppsEnvironment.id
output containerAppsEnvironmentName string = containerAppsEnvironment.name
output containerAppsEnvironmentFqdn string = containerAppsEnvironment.properties.defaultDomain
output petstoreContainerAppId string = petstoreContainerApp.id
output petstoreContainerAppName string = petstoreContainerApp.name
output petstoreContainerAppFqdn string = petstoreContainerApp.properties.configuration.ingress.fqdn
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id
