# Power Platform Virtual Network Integration with Azure API Management

## Overview
This repository provides **complete end-to-end automation** for Power Platform virtual network integration with Azure API Management (APIM). The solution includes everything from Power Platform environment creation through Copilot Studio configuration, delivering a fully automated pipeline for secure, enterprise-grade integration scenarios.

## 🚀 Complete Automation Pipeline

This solution provides **5 automated scripts** that handle the entire deployment lifecycle:

| Script | Purpose | Description |
|--------|---------|-------------|
| **0-CreatePowerPlatformEnvironment.ps1** | Environment Setup | Creates Power Platform environment with Dataverse |
| **1-InfraSetup.ps1** | Infrastructure | Deploys Azure infrastructure (VNets, APIM, Private Endpoints) |
| **2-SubnetInjectionSetup.ps1** | Network Integration | Links enterprise policy for VNet connectivity |
| **3-CreateCustomConnector.ps1** | API Integration | Creates custom connectors from APIM APIs |
| **4-SetupCopilotStudio.ps1** | AI Assistant | Configures Copilot Studio with connector integration |
| **5-Cleanup.ps1** | Resource Cleanup | Safely removes all deployed resources |

## Architecture
The solution creates a comprehensive enterprise architecture:

- **🏢 Power Platform Environment**: Automated environment creation with Dataverse integration
- **🌐 Dual-Region VNets**: Primary (West Europe) and Secondary (North Europe) virtual networks for high availability
- **🔒 Private Connectivity**: Dedicated subnets for Power Platform injection and private endpoints
- **📡 Azure API Management**: APIM instance with private endpoint connectivity and disabled public access
- **⚖️ Enterprise Governance**: Power Platform enterprise policy for subnet injection and compliance
- **🔌 Custom Connectors**: Automated connector creation from APIM APIs with authentication
- **🤖 Copilot Studio Integration**: AI assistant configuration with sample topics and workflows
- **🛡️ End-to-End Security**: Private network isolation, managed identities, and enterprise policies

## Prerequisites
- **Azure Subscription**: Contributor role access for resource deployment
- **Azure CLI**: Latest version installed and configured (`az login`)
- **PowerShell Core 7+**: Cross-platform PowerShell (`pwsh` command available)
- **Power Platform Admin**: Admin permissions in target tenant
- **Azure Developer CLI**: (`azd`) for streamlined deployments

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
pwsh ./0-CreatePowerPlatformEnvironment.ps1
pwsh ./1-InfraSetup.ps1
pwsh ./2-SubnetInjectionSetup.ps1

# Execute PowerShell commands
pwsh -c "Get-Date"
```

**Manual Installation (if not using dev container):**
If you prefer to set up the environment manually, ensure you have:
- PowerShell Core 7+ installed (`pwsh` command available)
- Azure CLI with login configured (`az login`)
- Azure Developer CLI (`azd`) installed
- Azure Bicep CLI extension (`az bicep install`)
- Appropriate PowerShell modules for Power Platform operations

## Recent Updates & Fixes

### Latest Changes (September 2025)
- ✅ **Complete Automation Pipeline**: Full end-to-end automation from environment creation to Copilot Studio
  - New `0-CreatePowerPlatformEnvironment.ps1` for automated Power Platform environment creation
  - Enhanced `3-CreateCustomConnector.ps1` for programmatic custom connector creation
  - New `4-SetupCopilotStudio.ps1` for AI assistant configuration with connector integration
  - Updated `5-Cleanup.ps1` for comprehensive resource cleanup
- ✅ **Enhanced Script Documentation**: Professional-grade PowerShell documentation with comprehensive help
  - Complete `.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.EXAMPLE` sections for all scripts
  - Cross-platform compatibility notes and platform-specific guidance
  - Integration examples and troubleshooting guides
- ✅ **Power Platform Integration**: Deep integration with Power Platform services
  - Automated environment creation with Dataverse support
  - Custom connector creation using Power Platform APIs
  - Copilot Studio bot creation and topic configuration
  - Enterprise policy management and VNet integration
- ✅ **Cross-Platform Excellence**: Full Linux, macOS, and Windows support
  - PowerShell Core 7+ for consistent cross-platform experience
  - Azure CLI integration for all Azure operations
  - Dev container support for consistent development environment
- ✅ **Modern DevOps Practices**: Azure Developer CLI integration and streamlined workflows
  - `azd` integration for infrastructure deployment
  - Environment file management and variable propagation
  - Comprehensive error handling and validation

### Previous Changes (July 2025)
- ✅ **Comprehensive Cleanup Script**: Added `5-Cleanup.ps1` for safe removal of all deployed resources
- ✅ **Enhanced Script Documentation**: Added comprehensive comment-based help to all PowerShell scripts
- ✅ **Improved Code Maintainability**: Enhanced comments throughout all scripts for better understanding
- ✅ **Fixed Dev Container Configuration**: Added PowerShell Core support to `.devcontainer/devcontainer.json`
- ✅ **Cross-Platform Compatibility**: Updated PowerShell scripts for Linux/Unix environments
- ✅ **Azure CLI Integration**: Enhanced authentication checks and error handling
- ✅ **Bicep Template Fixes**: Fixed region mapping and parameter mismatches
- ✅ **azd Integration**: Updated PowerShell scripts to work with Azure Developer CLI deployment model

## Environment Configuration

### 1. Environment Variables (.env file)
Create a `.env` file in the root directory with the following variables:

```env
TENANT_ID=86d068c0-1c9f-4b9e-939d-15146ccf2ad6
AZURE_SUBSCRIPTION_ID=06dbbc7b-2363-4dd4-9803-95d07f1a8d3e
AZURE_LOCATION=westeurope
POWER_PLATFORM_ENVIRONMENT_NAME=Woodgrove-Prod
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

## Complete Deployment Process

### Prerequisites
Before running the deployment scripts, ensure you have:
1. **Azure CLI Authentication**: Run `az login` to authenticate
2. **PowerShell Core Available**: The dev container includes `pwsh` automatically
3. **Environment Variables Configured**: Update the `.env` file with your values

### Step 0: Power Platform Environment Creation
Create the Power Platform environment that will be used for VNet integration:

```bash
# Create Power Platform environment with Dataverse
pwsh ./0-CreatePowerPlatformEnvironment.ps1

# Create production environment without confirmations
pwsh ./0-CreatePowerPlatformEnvironment.ps1 -EnvironmentType Production -EnableDataverse $true -Force

# Use custom environment file
pwsh ./0-CreatePowerPlatformEnvironment.ps1 -EnvFile "./environments/production.env"
```

This script performs the following actions:
1. **Environment Variables Loading**: Loads configuration from the `.env` file
2. **Azure Authentication Check**: Verifies Azure CLI login status and Power Platform permissions
3. **Environment Creation**: Creates new Power Platform environment via REST API
4. **Dataverse Provisioning**: Optionally provisions Dataverse database for full capabilities
5. **Location Validation**: Validates Power Platform regions and maps to Azure regions
6. **Environment File Updates**: Updates the `.env` file with environment details

**Environment Types Supported:**
- **Production**: For live workloads
- **Sandbox**: For testing and development (default)
- **Trial**: For evaluation scenarios
- **Developer**: For individual development

### Step 1: Infrastructure Creation
Deploy the Azure infrastructure using the enhanced script:

```bash
# Run the infrastructure deployment script
pwsh ./1-InfraSetup.ps1

# Use custom environment file
pwsh ./1-InfraSetup.ps1 -EnvFile "./environments/production.env"
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

### Step 2: Subnet Injection Setup
Configure Power Platform VNet integration:

```bash
# Run the subnet injection setup script
pwsh ./2-SubnetInjectionSetup.ps1

# Use custom environment file
pwsh ./2-SubnetInjectionSetup.ps1 -EnvFile "./config/production.env"
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

### Step 3: Custom Connector Creation
Create custom connectors from APIM APIs:

```bash
# Create connector for default Petstore API
pwsh ./3-CreateCustomConnector.ps1

# Create connector for custom API
pwsh ./3-CreateCustomConnector.ps1 -ApiId "my-api" -ConnectorName "My Business API Connector" -Force

# Use custom environment file and subscription name
pwsh ./3-CreateCustomConnector.ps1 -EnvFile "./production.env" -SubscriptionName "prod-connector-key"
```

This script performs the following actions:
1. **API Definition Export**: Exports OpenAPI definitions from Azure API Management
2. **Subscription Management**: Creates dedicated APIM subscription keys for authentication
3. **Connector Creation**: Uses Power Platform APIs to create custom connectors programmatically
4. **Security Configuration**: Sets up API key authentication automatically
5. **Connection Configuration**: Configures connector properties and connection parameters

### Step 4: Copilot Studio Integration
Configure Copilot Studio with custom connector integration:

```bash
# Setup Copilot Studio with default connector
pwsh ./4-SetupCopilotStudio.ps1

# Setup with custom connector and bot name
pwsh ./4-SetupCopilotStudio.ps1 -ConnectorName "My Business API Connector" -CopilotName "Business Assistant"

# Setup without sample topics
pwsh ./4-SetupCopilotStudio.ps1 -CreateSampleTopics:$false -Force
```

This script performs the following actions:
1. **Connector Validation**: Validates custom connector availability in the Power Platform environment
2. **Bot Creation**: Creates or updates Copilot Studio bots programmatically
3. **Connector Integration**: Links custom connectors to the bot
4. **Sample Topics**: Creates example topics demonstrating API usage
5. **Authentication Setup**: Configures connector authentication flows

### Step 5: Environment Cleanup (Optional)
When you need to remove all deployed resources:

```bash
# Interactive cleanup with confirmation prompts
pwsh ./5-Cleanup.ps1

# Automated cleanup without confirmations (use with caution)
pwsh ./5-Cleanup.ps1 -Force

# Keep resource group but remove all resources
pwsh ./5-Cleanup.ps1 -KeepResourceGroup

# Skip Power Platform unlinking (Azure resources only)
pwsh ./5-Cleanup.ps1 -SkipPowerPlatform
```

This script safely removes all infrastructure and configurations:
1. **Power Platform Configuration**: Unlinks enterprise policy from environment
2. **Azure Infrastructure**: Removes all Azure resources using `azd down` or direct resource group deletion
3. **Environment File**: Optionally removes the configuration file
4. **Comprehensive Reporting**: Detailed summary of completed operations and any issues

## Complete Automation Workflow

The complete end-to-end automation workflow:

```bash
# Complete deployment pipeline
pwsh ./0-CreatePowerPlatformEnvironment.ps1  # Create Power Platform environment
pwsh ./1-InfraSetup.ps1                      # Deploy Azure infrastructure
pwsh ./2-SubnetInjectionSetup.ps1            # Configure VNet integration
pwsh ./3-CreateCustomConnector.ps1           # Create custom connectors
pwsh ./4-SetupCopilotStudio.ps1              # Setup Copilot Studio integration

# Test the integration
# 1. Go to https://copilotstudio.microsoft.com
# 2. Select your environment
# 3. Open your bot and test with sample phrases
# 4. Go to https://make.powerapps.com to use custom connectors in Power Apps

# Complete cleanup when done
pwsh ./5-Cleanup.ps1
```

## API Management - Importing and Publishing APIs

### Importing the Petstore API Sample

After the infrastructure deployment is complete, you can test the APIM instance by importing and publishing the Petstore API sample. This follows the Microsoft Learn guidance for [importing and publishing APIs](https://learn.microsoft.com/en-us/azure/api-management/import-and-publish).

#### Using Azure CLI

You can import the API using Azure CLI commands:

```bash
# Set variables from your .env file
source .env

# Import the Petstore API
az apim api import \
    --resource-group "$RESOURCE_GROUP" \
    --service-name "$APIM_NAME" \
    --api-id "petstore-api" \
    --display-name "Petstore API" \
    --path "petstore" \
    --specification-url "https://petstore3.swagger.io/api/v3/openapi.json" \
    --specification-format "OpenApi"

# Create a subscription for the API
az apim product api add \
    --resource-group "$RESOURCE_GROUP" \
    --service-name "$APIM_NAME" \
    --product-id "unlimited" \
    --api-id "petstore-api"
```

#### Testing Through Private Endpoint

Since the APIM instance is configured with a private endpoint and public access disabled, you'll need to test from within the virtual network or configure appropriate network access:

1. **From Azure Portal**: The Azure Portal can access the APIM management plane
2. **From Virtual Network**: Deploy a test VM in the same VNet to test the API calls
3. **VPN/ExpressRoute**: Use existing connectivity to the Azure VNet

## Power Apps and Copilot Studio Integration

### Using Custom Connectors in Power Apps

Once created, you can use the custom connectors in your Power Apps:

1. **Create a New App**:
   - Go to **Apps** in Power Apps portal
   - Create a **Canvas app** or **Model-driven app**

2. **Add Data Source**:
   - In the app designer, click **Data** > **Add data**
   - Search for your custom connector (e.g., `Petstore Connector`)
   - Add it to your app

3. **Use in Formulas**:
   ```powerFX
   // Example: Get pets by status
   'Petstore Connector'.findPetsByStatus({status: "available"})
   
   // Display in a gallery
   Gallery1.Items = 'Petstore Connector'.findPetsByStatus({status: "available"}).value
   ```

### Testing Copilot Studio Integration

After setting up Copilot Studio integration:

1. **Test in Copilot Studio**:
   - Use the **Test copilot** panel
   - Type: "Show me available pets"
   - Verify the API call works through your private network

2. **Sample Test Phrases**:
   - "Show me available pets"
   - "What pets are available?"
   - "Find pets for adoption"

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

## Troubleshooting

### Recent Issues & Solutions

#### 1. **Set-ExecutionPolicy Error on Linux**
**Error**: `Operation is not supported on this platform`
**Solution**: ✅ Fixed - All scripts now detect Linux/macOS and skip Windows-specific commands

#### 2. **Azure CLI Authentication Issues**
**Error**: `Please run 'az login' to setup account`
**Solution**: ✅ Fixed - Added automatic authentication checks with helpful error messages

#### 3. **Power Platform Environment Not Found**
**Error**: `Power Platform environment 'EnvironmentName' not found`
**Solution**: ✅ Fixed - Use `0-CreatePowerPlatformEnvironment.ps1` to create the environment first

#### 4. **Custom Connector Creation Failed**
**Error**: Various connector creation errors
**Solution**: ✅ Fixed - Added `3-CreateCustomConnector.ps1` for automated connector creation

#### 5. **Copilot Studio Integration Issues**
**Error**: Bot creation or connector linking failures
**Solution**: ✅ Fixed - Added `4-SetupCopilotStudio.ps1` for automated integration

### Legacy Issues (Previously Fixed)

1. **APIM Deployment Errors**: ✅ Fixed with simplified configuration approach
2. **Subnet Range Outside VNet Error**: ✅ Fixed with corrected region failover mapping
3. **azd Command Syntax Errors**: ✅ Fixed with updated command syntax
4. **Parameter Mismatch Errors**: ✅ Fixed with cleaned up parameter files
5. **Get-AzResource Not Recognized**: ✅ Fixed by replacing with Azure CLI equivalents

### Validation

After deployment, verify:
- Power Platform environment exists and is accessible
- APIM instance is created and public access is disabled
- Private endpoint exists and is connected to APIM
- Enterprise policy is linked to Power Platform environment
- Custom connectors are created and functional
- Copilot Studio bot is configured and responsive

## File Structure

```
├── 0-CreatePowerPlatformEnvironment.ps1  # Power Platform environment creation script
├── 1-InfraSetup.ps1                      # Main infrastructure deployment script
├── 2-SubnetInjectionSetup.ps1            # Enterprise policy linking script
├── 3-CreateCustomConnector.ps1           # Custom connector creation script
├── 4-SetupCopilotStudio.ps1              # Copilot Studio integration script
├── 5-Cleanup.ps1                         # Complete cleanup and removal script
├── .env                                   # Environment variables
├── azure.yaml                            # Azure Developer CLI configuration
├── infra/                                # Bicep templates
│   ├── main.bicep
│   ├── apim-with-private-endpoint.bicep
│   ├── vnet-subnet-with-delegation-module.bicep
│   └── powerplatform-network-injection-enterprise-policy-module.bicep
├── orig-scripts/                         # Original Microsoft scripts
└── scripts/                              # Additional utility scripts
```

## Getting Help

### PowerShell Script Documentation

All PowerShell scripts include comprehensive comment-based help documentation. You can access detailed information about each script using PowerShell's built-in help system:

```powershell
# View basic help for any script
Get-Help ./0-CreatePowerPlatformEnvironment.ps1

# View detailed help with examples
Get-Help ./1-InfraSetup.ps1 -Full

# View help for specific parameters
Get-Help ./3-CreateCustomConnector.ps1 -Parameter ApiId

# Show parameter information
Get-Help ./4-SetupCopilotStudio.ps1 -Parameter ConnectorName
```

### Documentation Features
- **Comprehensive Descriptions**: Detailed explanations of what each script accomplishes
- **Parameter Documentation**: Complete parameter descriptions with validation requirements
- **Multiple Examples**: Practical usage examples for different scenarios
- **Prerequisites**: Clear listing of required tools and permissions
- **Cross-Platform Notes**: Platform-specific guidance for Windows, Linux, and macOS
- **API References**: Links to relevant Microsoft Learn documentation

## References
- [Microsoft Learn: Set up virtual network support for Power Platform](https://learn.microsoft.com/en-us/power-platform/admin/vnet-support-setup-configure?tabs=new#set-up-virtual-network-support)
- [GitHub: Power Platform Admin Scripts](https://github.com/microsoft/PowerApps-Samples/tree/main/power-platform/administration/virtual-network-support)
- [Azure API Management Private Endpoints](https://docs.microsoft.com/en-us/azure/api-management/private-endpoint)
- [Power Platform Custom Connectors](https://learn.microsoft.com/en-us/connectors/custom-connectors/)
- [Copilot Studio Documentation](https://learn.microsoft.com/en-us/microsoft-copilot-studio/)

---

## Notes

### Current Implementation (September 2025)
- **Complete End-to-End Automation**: From Power Platform environment creation through Copilot Studio configuration
- **Professional Script Documentation**: All scripts feature comprehensive comment-based help following Microsoft standards
- **Cross-Platform Excellence**: Full PowerShell Core support with automatic platform detection
- **Modern DevOps Integration**: Azure Developer CLI (azd) integration for streamlined deployment experience
- **Power Platform Deep Integration**: Native API integration for environment, connector, and bot management
- **Enterprise-Grade Security**: Private network isolation, managed identities, and enterprise policies
- **Comprehensive Error Handling**: Robust validation and user-friendly error messages throughout
- **Automated Resource Management**: Dynamic resource naming and automatic environment file updates

### Development Environment Features
- **Dev Container**: Complete development environment with all tools pre-installed
- **PowerShell Core**: Cross-platform scripting with `pwsh` command
- **Azure CLI**: Integrated authentication and resource management
- **Azure Bicep**: Infrastructure as Code with IntelliSense support
- **azd Integration**: Simplified deployment workflows

### Script Execution Flow
All PowerShell scripts follow a consistent, robust execution pattern:

1. **Cross-platform environment detection** with appropriate command handling
2. **Environment variable loading** with comprehensive validation
3. **Azure CLI authentication** with subscription context verification
4. **Resource deployment/configuration** using Azure APIs and PowerShell Core
5. **Operation monitoring** with user-friendly status reporting
6. **Environment file updates** with deployment outputs

### Compatibility Notes
- **PowerShell**: Requires PowerShell Core 7+ (`pwsh`) for cross-platform support
- **Azure CLI**: Must be logged in (`az login`) before running deployment scripts
- **azd**: Uses Azure Developer CLI for deployment orchestration
- **Bicep**: Latest Bicep CLI extension recommended for template validation
- **Operating Systems**: Windows, Linux, and macOS fully supported
