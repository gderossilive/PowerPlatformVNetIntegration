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
3. **Resource Group Creation**: Creates a resource group with a fixed suffix ("xwz" for consistency)
4. **Infrastructure Deployment**: Deploys all Azure resources using Bicep templates:
   - Primary and secondary virtual networks with subnets
   - Azure API Management instance
   - Private endpoints
   - Enterprise policy for Power Platform (with subnet delegation)
5. **APIM Configuration**: Updates APIM to disable public access and remove VNet integration
6. **Environment Variables Update**: Updates the `.env` file with deployment outputs

**Key APIM Configuration Changes:**
- Sets `--public-network-access false` to disable public access
- Uses `--virtual-network None` to remove VNet integration (simplified approach)
- Waits 120 seconds for private endpoint provisioning before configuration updates

### Step 2: Subnet Injection Setup
Run the subnet injection setup script:

```powershell
.\2-SubnetInjectionSetup.ps1
```

This script performs the following actions:
1. **Environment Loading**: Loads configuration from the `.env` file using helper functions
2. **Azure Authentication**: Ensures proper Azure login and subscription context
3. **Enterprise Policy Linking**: Links the enterprise policy to the Power Platform environment using:
   - Power Platform Admin API authentication with automatic token refresh
   - Environment ID resolution by display name via REST API
   - Enterprise policy SystemId extraction from Azure Resource Manager
   - API-based linking operation with proper headers and JSON payload
4. **Operation Monitoring**: Polls the linking operation until completion with configurable timeouts

**Enhanced Features:**
- **Modular Functions**: Well-structured helper functions for better maintainability
- **Error Handling**: Comprehensive error handling with status code validation
- **Token Management**: Automatic token refresh for long-running operations
- **Operation Polling**: Robust polling mechanism with configurable intervals and retries
- **Strict Mode**: Uses PowerShell strict mode for better error detection

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
3. **APIM Configuration Update**: PowerShell script updates APIM to:
   - Disable public access (`--public-network-access false`)
   - Remove VNet integration (`--virtual-network None`) for simplified setup
4. **Enterprise Policy**: Created during Bicep deployment with proper subnet delegation
5. **Policy Linking**: Separate script links enterprise policy to Power Platform environment

**Key Design Decisions:**
- **Fixed Suffix**: Uses "xwz" suffix for all resources to ensure consistent naming
- **Simplified APIM**: Removes complex VNet integration while maintaining private endpoint connectivity
- **Modular Approach**: Separates infrastructure creation from Power Platform environment linking

## Troubleshooting

### Common Issues

1. **APIM Deployment Errors**: 
   - Ensure APIM is created with public access enabled initially
   - Private endpoint must be created before updating APIM configuration
   - Current approach uses simplified configuration (`--virtual-network None`)

2. **APIM Configuration Updates**:
   - Script waits 120 seconds for private endpoint to be ready before APIM updates
   - Public access is disabled (`--public-network-access false`)
   - VNet integration is removed (`--virtual-network None`) for simplified deployment

3. **Enterprise Policy Linking Issues**:
   - Verify Power Platform environment exists and display name matches exactly
   - Check that enterprise policy was created successfully in Step 1
   - Ensure proper API permissions for Power Platform Admin API access

4. **Subnet Delegation Issues**:
   - Subnets are automatically delegated during Bicep deployment
   - Verify subnets have sufficient IP address space
   - Check that subnets are properly configured in the VNet modules

### Validation

After deployment, verify:
- APIM instance is created and public access is disabled
- Private endpoint exists and is connected to APIM
- Enterprise policy is linked to Power Platform environment
- Resource group contains all expected resources with consistent naming (suffix "xwz")

### Current Configuration Notes

**Fixed Naming Convention:**
- Resource group suffix is hardcoded to "xwz" for consistency
- All resources use this consistent suffix for easy identification

**Simplified APIM Setup:**
- APIM public access is disabled post-deployment
- VNet integration is not configured (using `None` setting)
- Private endpoint provides secure connectivity without complex VNet integration

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
- The infrastructure uses a simplified APIM deployment approach with private endpoints but without VNet integration
- Fixed suffix "xwz" is used for all resource names to ensure consistency across deployments
- The solution supports both primary and secondary regions for high availability
- Environment variables are automatically updated after successful deployment
- The `2-SubnetInjectionSetup.ps1` script uses modular functions for better maintainability and error handling
- Enterprise policy linking is handled separately from infrastructure deployment for better separation of concerns
