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
- PowerShell 5.1 or later (PowerShell Core 7+ recommended)
- Power Platform admin permissions
- Azure PowerShell modules for Power Platform cmdlets

## Development Environment

### Dev Container Setup
This repository includes a complete development environment configuration using VS Code Dev Containers. The dev container automatically installs and configures all necessary tools.

**Included Tools:**
- **PowerShell Core (pwsh)**: Latest PowerShell 7+ for cross-platform scripting
- **Azure CLI**: For Azure resource management and authentication
- **Azure Bicep**: For Infrastructure as Code template authoring
- **Azure Developer CLI (azd)**: For streamlined Azure deployments
- **Ubuntu 24.04 LTS**: As the base container environment

**Getting Started with Dev Container:**
1. Open this repository in VS Code
2. When prompted, click "Reopen in Container" or use `Ctrl+Shift+P` → "Dev Containers: Reopen in Container"
3. Wait for the container to build (first time may take a few minutes)
4. Once ready, all tools will be available in the integrated terminal

**Using PowerShell in the Dev Container:**
```bash
# Start PowerShell session
pwsh

# Run PowerShell scripts directly
pwsh ./1-InfraCreation.ps1
pwsh ./2-SubnetInjectionSetup.ps1

# Execute PowerShell commands
pwsh -c "Get-Date"
```

**Manual Installation (if not using dev container):**
If you prefer to set up the environment manually, ensure you have:
- PowerShell Core 7+ installed (`pwsh` command available)
- Azure CLI with login configured (`az login`)
- Azure Bicep CLI extension (`az bicep install`)
- Appropriate PowerShell modules for Power Platform operations

## Recent Updates & Fixes

### Latest Changes (July 2025)
- ✅ **Fixed Dev Container Configuration**: Added PowerShell Core support to `.devcontainer/devcontainer.json`
- ✅ **Cross-Platform Compatibility**: Updated PowerShell scripts for Linux/Unix environments
- ✅ **Azure CLI Integration**: Enhanced authentication checks and error handling
- ✅ **Bicep Template Fixes**: 
  - Fixed Sweden central region failover location mapping
  - Resolved parameter mismatches in `main.parameters.json`
  - Added missing enterprise policy name output
- ✅ **azd Integration**: Updated PowerShell scripts to work with Azure Developer CLI deployment model
- ✅ **Network Configuration**: Resolved subnet IP range validation issues

### Breaking Changes
- **PowerShell Execution**: Scripts now use `pwsh` (PowerShell Core) instead of Windows PowerShell
- **azd Deployment**: Infrastructure deployment now uses `azd up` instead of direct `az deployment` commands
- **Parameter Structure**: Simplified parameter files to match Bicep template definitions

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

### Prerequisites
Before running the deployment scripts, ensure you have:
1. **Azure CLI Authentication**: Run `az login` to authenticate
2. **PowerShell Core Available**: The dev container includes `pwsh` automatically
3. **Environment Variables Configured**: Update the `.env` file with your values

### Step 1: Infrastructure Creation
Run the infrastructure creation script using PowerShell Core:

```bash
# Ensure you're logged into Azure CLI
az login

# Run the infrastructure deployment script
pwsh ./1-InfraCreation.ps1
```

This script performs the following actions:
1. **Cross-Platform Setup**: Automatically detects Linux/macOS and skips Windows-specific commands
2. **Azure Authentication Check**: Verifies Azure CLI login status before proceeding
3. **Subscription Context**: Sets the correct Azure subscription from environment variables
4. **Resource Provider Registration**: Ensures Microsoft.PowerPlatform provider is registered
5. **Azure Developer CLI Deployment**: Uses `azd up` to deploy all infrastructure:
   - Primary and secondary virtual networks with subnets
   - Azure API Management instance with private endpoints
   - Enterprise policy for Power Platform (with subnet delegation)
6. **APIM Configuration**: Updates APIM to disable public access and configure private connectivity
7. **Environment Variables Update**: Updates the `.env` file with deployment outputs

**Key Improvements:**
- **Platform Detection**: Uses PowerShell Core's `$IsLinux`/`$IsMacOS` variables for cross-platform compatibility
- **Error Handling**: Comprehensive error checking with meaningful exit codes
- **Azure Developer CLI Integration**: Leverages `azd` for streamlined deployment experience
- **Output Mapping**: Automatically maps azd outputs to expected variable structure

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

## API Management - Importing and Publishing APIs

### Importing the Petstore API Sample

After the infrastructure deployment is complete, you can test the APIM instance by importing and publishing the Petstore API sample. This follows the Microsoft Learn guidance for [importing and publishing APIs](https://learn.microsoft.com/en-us/azure/api-management/import-and-publish).

#### Using Azure Portal

1. **Navigate to APIM Instance**:
   - Go to the Azure Portal
   - Find your APIM instance (name will be in the format `apim-{uniqueId}-xwz`)
   - Open the API Management service

2. **Import the Petstore API**:
   - In the left menu, select **APIs**
   - Click **+ Add API**
   - Choose **OpenAPI** specification
   - Use the following settings:
     - **OpenAPI specification URL**: `https://petstore3.swagger.io/api/v3/openapi.json`
     - **Display name**: `Petstore API`
     - **Name**: `petstore-api`
     - **API URL suffix**: `petstore`
     - **Products**: Select **Unlimited** (for testing)

3. **Test the API**:
   - After import, select the Petstore API
   - Choose an operation (e.g., **GET /pet/findByStatus**)
   - Click **Test** tab
   - Provide required parameters
   - Click **Send** to test

#### Using Azure CLI

Alternatively, you can import the API using Azure CLI commands:

```powershell
# Get the APIM name from your .env file or deployment outputs
$apimName = $env:APIM_NAME
$resourceGroup = $env:RESOURCE_GROUP

# Import the Petstore API
az apim api import `
    --resource-group $resourceGroup `
    --service-name $apimName `
    --api-id "petstore-api" `
    --display-name "Petstore API" `
    --path "petstore" `
    --specification-url "https://petstore3.swagger.io/api/v3/openapi.json" `
    --specification-format "OpenApi"

# Create a subscription for testing (optional)
az apim product api add `
    --resource-group $resourceGroup `
    --service-name $apimName `
    --product-id "unlimited" `
    --api-id "petstore-api"
```

#### Testing Through Private Endpoint

Since the APIM instance is configured with a private endpoint and public access disabled, you'll need to test from within the virtual network or configure appropriate network access:

1. **From Azure Portal**: The Azure Portal can access the APIM management plane
2. **From Virtual Network**: Deploy a test VM in the same VNet to test the API calls
3. **VPN/ExpressRoute**: Use existing connectivity to the Azure VNet

#### API Security and Subscriptions

Once imported, you can configure additional security:

1. **Subscription Keys**: Create subscription keys for API access control
2. **Policies**: Apply rate limiting, authentication, and transformation policies
3. **Products**: Group APIs into products with specific access controls
4. **OAuth/JWT**: Configure advanced authentication mechanisms

**Example Test Call** (from within the VNet):
```bash
# Get subscription key from APIM portal first
curl -X GET "https://{your-apim-name}.azure-api.net/petstore/pet/findByStatus?status=available" \
     -H "Ocp-Apim-Subscription-Key: {your-subscription-key}"
```

This provides a complete testing scenario to validate that your APIM instance is properly configured and can serve APIs through the private endpoint connectivity.

## Power Apps Custom Connector Integration

### Creating a Custom Connector from APIM

After successfully importing and testing APIs in your APIM instance, you can create custom connectors in Power Apps to consume these APIs. This follows the Microsoft Learn guidance for [exporting APIs to Power Platform](https://learn.microsoft.com/en-us/azure/api-management/export-api-power-platform).

#### Prerequisites

Before creating the custom connector, ensure:
- ✅ **Power Platform Environment**: Your Power Platform environment is properly configured and linked to the enterprise policy
- ✅ **API Management**: APIM instance is deployed with APIs imported (e.g., Petstore API)
- ✅ **Network Integration**: VNet integration is established between Power Platform and Azure
- ✅ **Permissions**: You have appropriate permissions in both Azure and Power Platform

#### Method 1: Export from Azure API Management

1. **Navigate to APIM Instance**:
   ```powershell
   # Open APIM in Azure Portal using your deployed instance
   $apimName = $env:APIM_NAME
   Write-Host "Navigate to: https://portal.azure.com -> $apimName"
   ```

2. **Export to Power Platform**:
   - In APIM, go to **APIs** section
   - Select your API (e.g., **Petstore API**)
   - Click **Export** in the top menu
   - Choose **Power Apps and Power Automate**
   - Configure export settings:
     - **Display name**: `Petstore Connector`
     - **Environment**: Select your Power Platform environment
     - **API URL**: Will use the private endpoint URL automatically

3. **Complete the Export**:
   - Review the API definition
   - Click **Export** to create the custom connector
   - The connector will be created in your Power Platform environment

#### Method 2: Manual Custom Connector Creation

If you prefer more control over the connector creation:

1. **Get the API Definition**:
   ```powershell
   # Export API definition from APIM
   $resourceGroup = $env:RESOURCE_GROUP
   $apimName = $env:APIM_NAME
   
   # Export the OpenAPI definition
   az apim api export `
     --resource-group $resourceGroup `
     --service-name $apimName `
     --api-id "petstore-api" `
     --format "openapi+json" `
     --export-to "petstore-api-definition.json"
   ```

2. **Create Custom Connector in Power Apps**:
   - Navigate to [Power Apps](https://make.powerapps.com)
   - Select your environment (linked to the enterprise policy)
   - Go to **Data** > **Custom connectors**
   - Click **+ New custom connector** > **Import an OpenAPI file**
   - Upload the exported JSON definition
   - Configure connector properties:
     - **Host**: Your APIM gateway URL (private endpoint)
     - **Base URL**: `/petstore` (or your API path)

3. **Configure Security**:
   - Choose **API Key** authentication
   - Set **Parameter label**: `Ocp-Apim-Subscription-Key`
   - Set **Parameter name**: `Ocp-Apim-Subscription-Key`
   - Set **Parameter location**: `Header`

4. **Test the Connector**:
   - Go to **Test** tab
   - Provide the subscription key from APIM
   - Test an operation (e.g., **findPetsByStatus**)
   - Verify connectivity through the private network

#### Method 3: Using Power Platform CLI

For automated deployment scenarios:

```powershell
# Install Power Platform CLI if not already installed
# winget install Microsoft.PowerPlatformCLI

# Authenticate to Power Platform
pac auth create --url "https://[your-environment].crm.dynamics.com"

# Create custom connector from APIM
pac connector create `
  --settings-file "connector-settings.json" `
  --definition-file "petstore-api-definition.json" `
  --environment [your-environment-id]
```

#### Network Integration Benefits

With the VNet integration established through your enterprise policy:

1. **Private Connectivity**: Custom connectors can access APIM through private endpoints
2. **Enhanced Security**: Traffic remains within your Azure virtual network
3. **Performance**: Reduced latency through private network paths
4. **Compliance**: Meets enterprise security requirements for data isolation

#### Using the Custom Connector in Power Apps

Once created, you can use the connector in your Power Apps:

1. **Create a New App**:
   - Go to **Apps** in Power Apps portal
   - Create a **Canvas app** or **Model-driven app**

2. **Add Data Source**:
   - In the app designer, click **Data** > **Add data**
   - Search for your custom connector (`Petstore Connector`)
   - Add it to your app

3. **Use in Formulas**:
   ```powerFX
   // Example: Get pets by status
   'Petstore Connector'.findPetsByStatus({status: "available"})
   
   // Display in a gallery
   Gallery1.Items = 'Petstore Connector'.findPetsByStatus({status: "available"}).value
   ```

4. **Handle Authentication**:
   - When first using the connector, you'll be prompted for the subscription key
   - This establishes the connection for future use

#### Troubleshooting Custom Connectors

**Common Issues:**
- **Connection Timeout**: Verify private endpoint connectivity and DNS resolution
- **Authentication Errors**: Check APIM subscription key validity and permissions
- **API Not Found**: Ensure API is properly imported and published in APIM
- **Network Issues**: Verify enterprise policy is correctly linked to environment

**Validation Steps:**
```powershell
# Check enterprise policy status
$policyName = $env:ENTERPRISE_POLICY_NAME
$resourceGroup = $env:RESOURCE_GROUP
az resource show --name $policyName --resource-group $resourceGroup --resource-type "Microsoft.PowerPlatform/enterprisePolicies"

# Verify APIM API availability
az apim api list --resource-group $resourceGroup --service-name $env:APIM_NAME --output table
```

This integration demonstrates the complete end-to-end scenario: from Azure infrastructure through API management to Power Platform consumption, all secured through private network connectivity.

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

### Recent Issues & Solutions

#### 1. **Set-ExecutionPolicy Error on Linux**
**Error**: `Operation is not supported on this platform`
**Solution**: ✅ Fixed - Script now detects Linux/macOS and skips Windows-specific commands

#### 2. **Azure CLI Authentication Issues**
**Error**: `Please run 'az login' to setup account`
**Solution**: ✅ Fixed - Added automatic authentication checks with helpful error messages

#### 3. **Subnet Range Outside VNet Error**
**Error**: `Subnet 'snet-injection-xx' is not valid because its IP address range is outside the IP address range of virtual network`
**Solution**: ✅ Fixed - Corrected Sweden region failover mapping and parameter validation

#### 4. **azd Command Syntax Errors**
**Error**: `unknown flag: --location`
**Solution**: ✅ Fixed - Updated to use correct `azd up --environment` syntax

#### 5. **Parameter Mismatch Errors**
**Error**: Deployment fails with undefined parameter references
**Solution**: ✅ Fixed - Cleaned up `main.parameters.json` to match `main.bicep` parameters exactly

### Legacy Issues

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
- Resource group contains all expected resources with consistent naming (suffix from `uniqueString()`)

### Current Configuration Notes

**Modern Development Environment:**
- PowerShell Core 7+ for cross-platform compatibility
- Azure Developer CLI (azd) for streamlined deployments
- VS Code Dev Container with all tools pre-configured
- Ubuntu 24.04 LTS base environment

**Dynamic Resource Naming:**
- Resource group suffix is generated using `uniqueString()` function
- All resources use this consistent suffix for easy identification
- Format: `{environmentName}-{3-char-hash}`

**Simplified APIM Setup:**
- APIM public access is disabled post-deployment
- VNet integration is not configured (using `None` setting)
- Private endpoint provides secure connectivity without complex VNet integration

**Regional Failover Support:**
- Fixed Sweden Central region mapping (now points to North Europe)
- All supported Azure regions have proper failover pairs defined
- Automatic secondary region selection based on primary region

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

### Current Implementation (July 2025)
- The infrastructure uses a simplified APIM deployment approach with private endpoints but without VNet integration
- Dynamic suffix using `uniqueString()` function ensures unique resource names across deployments
- Cross-platform PowerShell Core support enables development on Windows, Linux, and macOS
- Azure Developer CLI (azd) integration provides streamlined deployment experience
- The solution supports both primary and secondary regions for high availability
- Environment variables are automatically updated after successful deployment
- The `2-SubnetInjectionSetup.ps1` script uses modular functions for better maintainability and error handling
- Enterprise policy linking is handled separately from infrastructure deployment for better separation of concerns

### Development Environment Features
- **Dev Container**: Complete development environment with all tools pre-installed
- **PowerShell Core**: Cross-platform scripting with `pwsh` command
- **Azure CLI**: Integrated authentication and resource management
- **Azure Bicep**: Infrastructure as Code with IntelliSense support
- **azd Integration**: Simplified deployment workflows

### Compatibility Notes
- **PowerShell**: Requires PowerShell Core 7+ (`pwsh`) for cross-platform support
- **Azure CLI**: Must be logged in (`az login`) before running deployment scripts
- **azd**: Uses Azure Developer CLI for deployment orchestration
- **Bicep**: Latest Bicep CLI extension recommended for template validation
