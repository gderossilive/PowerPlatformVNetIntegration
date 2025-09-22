/* Power Platform Environment Module */
/* This module creates a Power Platform environment with Dataverse database */

@description('Power Platform environment display name')
param environmentDisplayName string

@description('Power Platform environment location')
@allowed([
  'europe'
  'unitedstates'
  'asia'
  'australia'
  'india'
  'japan'
  'canada'
  'southamerica'
  'unitedkingdom'
  'france'
  'germany'
  'switzerland'
  'norway'
  'korea'
  'southafrica'
  'uae'
])
param powerPlatformLocation string = 'europe'

@description('Azure region for Power Platform environment alignment')
param azureRegion string

@description('Environment type')
@allowed([
  'Sandbox'
  'Production'
  'Trial'
  'Developer'
])
param environmentType string = 'Sandbox'

@description('Environment description')
param environmentDescription string = 'Power Platform environment for VNet integration with Azure API Management'

@description('Dataverse database language code')
param dataverseLanguageCode string = '1033' // English

@description('Dataverse database currency code')
param dataverseCurrencyCode string = 'USD'

@description('Security group ID for environment access control (optional)')
param securityGroupId string = ''

@description('Custom domain name for the environment (optional)')
param customDomainName string = ''

@description('Enterprise policy ID for VNet integration (optional)')
param enterprisePolicyId string = ''

@description('Enable Dataverse database')
param enableDataverse bool = true

@description('Tags to apply to the environment')
param tags object = {}

/* Variables */
var uniqueName = toLower(replace(replace(environmentDisplayName, ' ', ''), '-', ''))
var domainName = !empty(customDomainName) ? customDomainName : '${uniqueName}${uniqueString(resourceGroup().id)}'

/* Power Platform Environment Resource */
resource powerPlatformEnvironment 'Microsoft.PowerPlatform/environments@2020-10-01' = {
  name: uniqueName
  location: powerPlatformLocation
  tags: tags
  properties: {
    displayName: environmentDisplayName
    description: environmentDescription
    environmentSku: environmentType
    azureRegion: azureRegion
    dataverse: enableDataverse ? {
      languageCode: dataverseLanguageCode
      currencyCode: dataverseCurrencyCode
      securityGroupId: !empty(securityGroupId) ? securityGroupId : null
      domainName: domainName
      version: '9.2'
    } : null
    enterprisePolicy: !empty(enterprisePolicyId) ? {
      id: enterprisePolicyId
    } : null
  }
}

/* Outputs */
@description('The resource ID of the Power Platform environment')
output environmentId string = powerPlatformEnvironment.id

@description('The name of the Power Platform environment')
output environmentName string = powerPlatformEnvironment.name

@description('The display name of the Power Platform environment')
output environmentDisplayName string = powerPlatformEnvironment.properties.displayName

@description('The URL of the Power Platform environment')
output environmentUrl string = powerPlatformEnvironment.properties.environmentUrl

@description('The Dataverse instance URL (if Dataverse is enabled)')
output dataverseUrl string = enableDataverse && powerPlatformEnvironment.properties.dataverse != null ? powerPlatformEnvironment.properties.dataverse.instanceUrl : ''

@description('The Dataverse unique name (if Dataverse is enabled)')
output dataverseUniqueName string = enableDataverse && powerPlatformEnvironment.properties.dataverse != null ? powerPlatformEnvironment.properties.dataverse.uniqueName : ''

@description('The Power Platform environment properties')
output environmentProperties object = powerPlatformEnvironment.properties
