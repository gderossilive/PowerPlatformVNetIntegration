# Prerequisite: to be logged in to Azure CLI with an account with the Power Platform Administrator role or a service principal registered with 'pac admin register'

# 1. Get access token for Power Platform Admin API
$powerPlatformAdminApiUrl = "https://api.bap.microsoft.com/" # URL of the Power Platform Admin API
$powerPlatformAdminApiToken = az account get-access-token --resource $powerPlatformAdminApiUrl --query accessToken --output tsv 

# 2. Link Power Platform network injection enterprise policy to environment
$ApiVersion = "2019-10-01" # Version of the Power Platform Admin API to use to link / unlink an enterprise policy to a Power Platform environment

$body = [pscustomobject]@{
  "SystemId" = az resource show --ids $enterprisePolicyId --query "properties.systemId" -o tsv
}

$linkEnterprisePolicyUri = "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/environments/$powerPlatformEnvironmentId/enterprisePolicies/NetworkInjection/link?&api-version=$ApiVersion"

$linkEnterprisePolicyResult = iwr -Uri $linkEnterprisePolicyUri -Authentication OAuth -Token $(ConvertTo-SecureString $powerPlatformAdminApiToken -AsPlainText -Force) -Method Post -ContentType "application/json" -Body ($body | ConvertTo-Json) -UseBasicParsing

# Potential errors:
# Environment not Managed: "The following Power Platform environments are not managed: azureRegion, environmentId, protectionLevel and cannot be connected to the VNet Integration Enterprise Policy"
# Environment not in the same region than the enterprise policy: "The following Power Platform environments are in non-allowed Azure regions: azureRegion, environmentId, protectionLevel and cannot be connected to the VNet Integration Enterprise Policy"