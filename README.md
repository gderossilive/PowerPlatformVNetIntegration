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
├── RunMe.sh                              # Orchestrator: environment + infra + subnet link
├── 0-CreatePowerPlatformEnvironment.ps1  # PowerShell legacy env creation
├── 1-InfraSetup.ps1                      # PowerShell infra deployment
├── 2-SubnetInjectionSetup.ps1            # PowerShell subnet link
├── 3-CreateCustomConnector.ps1           # PowerShell connector creation
├── 4-SetupCopilotStudio.ps1              # PowerShell Copilot integration
├── 5-Cleanup.ps1                         # PowerShell cleanup
├── scripts/                              # Active bash automation scripts
│   ├── 0-CreatePowerPlatformEnvironment.sh
│   ├── 1-InfraSetup.sh
│   ├── 2-SubnetInjectionSetup.sh
│   ├── 3-CreateCustomConnector_v2.sh
│   ├── 4-SetupCopilotStudio.sh
│   ├── 1-SetupSubscriptionForPowerPlatform.ps1
│   ├── 2-SetupVnetForSubnetDelegation.ps1
│   ├── 3-CreateSubnetInjectionEnterprisePolicy.ps1
│   ├── 5-NewSubnetInjection.ps1
│   └── README.md
├── infra/
│   ├── main.bicep
│   ├── apim-with-private-endpoint.bicep
│   ├── vnet-subnet-with-delegation-module.bicep
│   └── powerplatform-network-injection-enterprise-policy-module.bicep
├── azure.yaml
├── .env
├── orig-scripts/
└── docs/
```

> See `scripts/README.md` for detailed script purposes, manual steps, and troubleshooting.

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
