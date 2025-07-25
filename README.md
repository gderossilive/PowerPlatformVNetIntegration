# Power Platform Virtual Network Integration with Azure API Management

## Overview
This repository contains scripts and Infrastructure as Code (IaC) templates to set up Power Platform virtual network support with Azure API Management (APIM) integration. The solution deploys a complete infrastructure including virtual networks, subnets, private endpoints, and enterprise policies for Power Platform environments.

## Architecture
The solution creates:
- **Primary and Secondary VNets**: Two virtual networks in different Azure regions for high availability
- **Subnets**: Dedicated subnets for Power Platform injection and private endpoints
- **Azure API Management**: APIM instance with private endpoint connectivity
- **Enterprise Policy**: Power Platform enterprise policy for subnet injection
- **Private Endpoints**: Secure connectivity to Azure services

## Prerequisites
- Azure subscription with Contributor role access
- Azure CLI installed and configured
- PowerShell 5.1 or later
- Power Platform admin permissions
- Azure PowerShell modules for Power Platform cmdlets

## Environment Configuration

### 1. Environment Variables (.env file)
Create a `.env` file in the root directory with the following variables:

```env
TENANT_ID=your-tenant-id
SUBSCRIPTION_ID=your-subscription-id
AZURE_LOCATION=westeurope
POWER_PLATFORM_ENVIRONMENT_NAME=Fabrikam-Prod
POWER_PLATFORM_LOCATION=europe
RESOURCE_GROUP=
PRIMARY_VIRTUAL_NETWORK_NAME=
PRIMARY_SUBNET_NAME=
SECONDARY_VIRTUAL_NETWORK_NAME=
SECONDARY_SUBNET_NAME=
ENTERPRISE_POLICY_NAME=
APIM_NAME=
APIM_ID=
```

**Note**: The empty values will be populated automatically by the deployment scripts.

## Deployment Process

### Step 1: Infrastructure Creation
Run the infrastructure creation script:

```powershell
.\1-InfraCreation.ps1
```

This script performs the following actions:
1. **Authentication**: Logs into Azure using the specified tenant and subscription
2. **Resource Provider Registration**: Ensures Microsoft.PowerPlatform provider is registered
3. **Resource Group Creation**: Creates a resource group with a random suffix
4. **Infrastructure Deployment**: Deploys all Azure resources using Bicep templates:
   - Primary and secondary virtual networks with subnets
   - Azure API Management instance
   - Private endpoints
   - Enterprise policy for Power Platform (with subnet delegation)
5. **APIM Configuration**: Updates APIM to disable public access and enable VNet integration
6. **Environment Variables Update**: Updates the `.env` file with deployment outputs

### Step 2: Subnet Injection Setup
Run the subnet injection setup script:

```powershell
.\2-SubnetInjectionSetup.ps1
```

This script performs the following actions:
1. **Environment Loading**: Loads configuration from the `.env` file
2. **Azure Authentication**: Ensures proper Azure login and subscription context
3. **Enterprise Policy Linking**: Links the enterprise policy to the Power Platform environment using:
   - Power Platform Admin API authentication
   - Environment ID resolution by display name
   - Enterprise policy SystemId extraction
   - API-based linking operation
4. **Operation Monitoring**: Polls the linking operation until completion

**Key Features:**
- Uses Azure REST API calls for Power Platform integration
- Automatic token management and refresh
- Polling mechanism to wait for asynchronous operations
- Comprehensive error handling and status reporting

**Important Notes:**
- The enterprise policy is created during Step 1 with proper subnet delegation
- Step 2 focuses specifically on linking the policy to the Power Platform environment
- The linking operation is asynchronous and requires polling for completion status

## Infrastructure Components

### Bicep Templates (./infra/ directory)

| Template | Purpose |
|----------|---------|
| `main.bicep` | Main orchestration template |
| `vnet-subnet-with-delegation-module.bicep` | Virtual network and subnet creation |
| `apim-with-private-endpoint.bicep` | API Management with private endpoint |
| `powerplatform-network-injection-enterprise-policy-module.bicep` | Enterprise policy creation |

### Key Features

#### Azure API Management
- **SKU**: Developer (suitable for testing and development)
- **Network Configuration**: External VNet integration with private endpoint
- **Public Access**: Disabled after private endpoint setup
- **Location**: West Europe (primary region)

#### Virtual Networks
- **Primary VNet**: 10.10.0.0/23 (West Europe)
  - Injection Subnet: 10.10.0.0/24
  - Private Endpoints Subnet: 10.10.1.0/24
- **Secondary VNet**: 10.20.0.0/23 (North Europe - failover)
  - Injection Subnet: 10.20.0.0/24
  - Private Endpoints Subnet: 10.20.1.0/24

#### Security
- Private endpoints for secure connectivity
- Network isolation through subnet delegation
- Disabled public access on API Management
- Enterprise policies for Power Platform governance

## Deployment Sequence

The deployment follows a specific sequence to handle Azure resource dependencies:

1. **APIM Creation**: Created with public access enabled (required for initial provisioning)
2. **Private Endpoint**: Created after APIM is ready
3. **APIM Update**: PowerShell script updates APIM configuration to disable public access and enable VNet integration
4. **Enterprise Policy**: Created and linked to Power Platform environments

## Troubleshooting

### Common Issues

1. **APIM Deployment Errors**: 
   - Ensure APIM is created with public access enabled initially
   - Private endpoint must be created before updating APIM configuration

2. **Subnet Delegation Issues**:
   - Verify subnets are properly delegated to Microsoft.PowerPlatform/enterprisePolicies
   - Check that subnets have sufficient IP address space

3. **Enterprise Policy Linking**:
   - Ensure proper permissions are granted
   - Verify Power Platform environment exists and is accessible

### Validation

After deployment, verify:
- APIM instance is accessible through private endpoint
- Public access to APIM is disabled
- Enterprise policy is linked to Power Platform environment
- Subnets are properly delegated

## File Structure

```
├── 1-InfraCreation.ps1              # Main infrastructure deployment script
├── 2-SubnetInjectionSetup.ps1       # Enterprise policy linking script
├── .env                             # Environment variables
├── infra/                           # Bicep templates
│   ├── main.bicep
│   ├── apim-with-private-endpoint.bicep
│   ├── vnet-subnet-with-delegation-module.bicep
│   └── powerplatform-network-injection-enterprise-policy-module.bicep
├── orig-scripts/                    # Original Microsoft scripts
└── scripts/                         # Additional utility scripts
```

## References
- [Microsoft Learn: Set up virtual network support for Power Platform](https://learn.microsoft.com/en-us/power-platform/admin/vnet-support-setup-configure?tabs=new#set-up-virtual-network-support)
- [GitHub: Power Platform Admin Scripts](https://github.com/microsoft/PowerApps-Samples/tree/main/power-platform/administration/virtual-network-support)
- [Azure API Management Private Endpoints](https://docs.microsoft.com/en-us/azure/api-management/private-endpoint)

---

## Notes
- The infrastructure uses a three-step deployment approach to handle APIM private endpoint requirements
- Random suffixes are used for resource names to ensure uniqueness
- The solution supports both primary and secondary regions for high availability
- Environment variables are automatically updated after successful deployment
