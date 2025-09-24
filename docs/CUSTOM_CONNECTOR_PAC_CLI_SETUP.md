# Power Platform Custom Connector Setup via PAC CLI

This document outlines the successful process we implemented for creating Power Platform custom connectors using the Power Platform CLI (PAC CLI) approach.

> **Script entry point:** Run `./scripts/3-CreateCustomConnector_v2.sh` within the repo after infrastructure deployment to walk through the automated setup and guided manual connection creation.

## Overview

We successfully created a custom connector for the APIM Petstore API using the PAC CLI method, which provides a more direct and reliable approach compared to REST API calls.

## Prerequisites

1. **Power Platform CLI (PAC)**: Install via `dotnet tool install --global Microsoft.PowerPlatform.CLI`
2. **Azure API Management Service**: With published APIs
3. **Power Platform Environment**: Target environment for the connector
4. **Authentication**: PAC CLI authentication to Power Platform

## Successful Implementation Steps

### 1. PAC CLI Authentication

```bash
# Authenticate using device code flow (most reliable in dev containers)
pac auth create --deviceCode --tenant <TENANT_ID>
```

**Key Learning**: Device code authentication works best in containerized environments where interactive browser auth may be problematic.

### 2. Project Structure Setup

```bash
# Create connector project directory
mkdir -p custom-connector/petstore-connector
cd custom-connector/petstore-connector

# Initialize PAC connector project
pac connector init --connection-template ApiKey --generate-settings-file --outputDirectory .
```

**Generated Files**:
- `apiProperties.json` - Connector configuration and authentication
- `settings.json` - Additional settings
- Base structure for `apiDefinition.swagger.json`

### 3. API Definition Preparation

**Critical Discovery**: Power Platform custom connectors only support **Swagger 2.0**, not OpenAPI 3.0.

**Solution**: Used pre-configured Swagger 2.0 definition from `exports/petstore-api-definition-fixed.json`:

```json
{
    "swagger": "2.0",
    "info": {
        "title": "Petstore API",
        "description": "Custom connector for Power Platform integration via Azure API Management.",
        "version": "1.0"
    },
    "host": "az-apim-vdu.azure-api.net",
    "basePath": "/petstore",
    "schemes": ["https"],
    "securityDefinitions": {
        "apiKeyHeader": {
            "type": "apiKey",
            "name": "Ocp-Apim-Subscription-Key",
            "in": "header"
        }
    },
    "security": [{"apiKeyHeader": []}]
}
```

### 4. APIM Authentication Configuration

**apiProperties.json Configuration**:

```json
{
  "properties": {
    "connectionParameters": {
      "api_key": {
        "type": "securestring",
        "uiDefinition": {
          "displayName": "APIM Subscription Key",
          "description": "Enter your Azure API Management subscription key",
          "tooltip": "This key is required to authenticate with the APIM Petstore API",
          "constraints": {
            "tabIndex": 2,
            "clearText": false,
            "required": "true"
          }
        }
      }
    },
    "iconBrandColor": "#007ee5",
    "publisher": "Microsoft Sample",
    "stackOwner": "Microsoft Sample"
  }
}
```

### 5. Custom Connector Creation

```bash
# Create the custom connector
pac connector create \
  --environment https://org6b1eda70.crm4.dynamics.com/ \
  --api-definition-file ./apiDefinition.swagger.json \
  --api-properties-file ./apiProperties.json
```

**Success Result**: `Connector created with ID 2b1a8b3a-8898-f011-b4cc-000d3aa8765c`

## Key Lessons Learned

### 1. OpenAPI Version Compatibility
- **Issue**: OpenAPI 3.0 not supported by Power Platform custom connectors
- **Solution**: Must use Swagger 2.0 format
- **Implementation**: Convert/use pre-existing Swagger 2.0 definitions

### 2. Authentication Methods
- **PAC CLI Auth**: Device code flow most reliable in dev containers
- **APIM Auth**: Use `Ocp-Apim-Subscription-Key` header for APIM integration
- **Environment URL**: Use full environment URL, not just environment name

### 3. File Structure Requirements
- `apiDefinition.swagger.json`: Must be valid Swagger 2.0
- `apiProperties.json`: Defines connection parameters and UI
- `settings.json`: Optional additional configuration

### 4. APIM Integration Points
- **Host**: Must match APIM service name (`{apim-name}.azure-api.net`)
- **Base Path**: Must match APIM API path configuration
- **Security**: Configure for APIM subscription key authentication

## Integration with RunMe.sh

The process has been integrated into the main orchestration script (`RunMe.sh`) with the following features:

### New Function: `setup_custom_connector()`
- Checks for PAC CLI availability
- Validates authentication status
- Uses environment URL from troubleshooting scripts
- Creates connector project structure
- Deploys custom connector automatically

### New Command Line Options
- `--skip-connector`: Skip custom connector creation
- Enhanced error handling and user guidance

### Enhanced Prerequisites
- Added Power Platform CLI to prerequisites
- Updated manual steps to include PAC CLI authentication

## Files Modified/Created

1. **RunMe.sh**: Added `setup_custom_connector()` function and CLI options
2. **custom-connector/petstore-connector/**: Complete connector project structure
3. **exports/petstore-api-definition-fixed.json**: Swagger 2.0 definition template
4. **docs/CUSTOM_CONNECTOR_PAC_CLI_SETUP.md**: This documentation

## Usage Examples

### Full Automated Setup
```bash
./RunMe.sh -n "MyEnvironment" -r westeurope -p europe
```

### Skip Connector Creation
```bash
./RunMe.sh -n "MyEnvironment" -r westeurope -p europe --skip-connector
```

### Manual Connector Creation Only
```bash
# Guided script (recommended)
./scripts/3-CreateCustomConnector_v2.sh --env-file ./your.env

# Raw PAC CLI (advanced fallback)
cd custom-connector/petstore-connector
pac auth create --deviceCode --tenant <TENANT_ID>
pac connector create --environment <ENV_URL> --api-definition-file ./apiDefinition.swagger.json --api-properties-file ./apiProperties.json
```

## Troubleshooting

### Common Issues and Solutions

1. **"OpenApi 3 version is not yet supported"**
   - **Cause**: Using OpenAPI 3.0 definition
   - **Solution**: Convert to Swagger 2.0 format

2. **"No profiles were found"**
   - **Cause**: PAC CLI not authenticated
   - **Solution**: Run `pac auth create --deviceCode --tenant <TENANT_ID>`

3. **"Invalid value for argument"**
   - **Cause**: Using environment name instead of URL
   - **Solution**: Use full environment URL (`https://orgXXXX.crmX.dynamics.com/`)

4. **Authentication Timeout**
   - **Cause**: Interactive auth in dev container
   - **Solution**: Use device code authentication method

## Future Enhancements

1. **Icon Support**: Add custom connector icon file
2. **Script Operations**: Implement custom operations if needed
3. **Solution Integration**: Package connector in Power Platform solution
4. **Testing Automation**: Automated connector testing post-creation
5. **Multi-API Support**: Extend to support multiple APIM APIs

## Conclusion

The PAC CLI approach provides a reliable, scriptable method for creating Power Platform custom connectors with proper APIM integration. This implementation successfully bridges Azure API Management with Power Platform through VNet integration while maintaining security and governance requirements.