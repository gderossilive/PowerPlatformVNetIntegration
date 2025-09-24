# Power Platform VNet Integration - Troubleshooting Scripts

This directory contains atomic troubleshooting scripts for diagnosing and fixing issues with Power Platform VNet integration. Each script performs a single, specific operation that can be used independently or as part of larger workflows.

## 📁 Directory Structure

```
troubleshooting/
├── auth/                    # Authentication & Prerequisites
├── powerplatform/          # Power Platform Environment Operations
├── enterprise-policy/      # Enterprise Policy Operations
├── azure-infra/           # Azure Infrastructure Operations
├── apim/                  # API Management Operations
├── connectors/            # Custom Connector Operations
├── network/               # Network Integration Testing
├── monitoring/            # Monitoring & Diagnostics
├── utils/                 # Utility Scripts
└── common/                # Shared Functions & Libraries
```

## 🚀 Quick Start

1. **Ensure you're in the project root directory**
2. **Source environment variables**: `source .env`
3. **Run any script**: `./troubleshooting/<category>/<script-name>.sh`
4. **Check logs**: Scripts provide detailed output and error messages

## 📋 Script Categories

### 🔐 Authentication & Prerequisites (`auth/`)

| Script | Purpose | Usage |
|--------|---------|-------|
| `test-auth.sh` | Test Azure CLI and Power Platform authentication | `./auth/test-auth.sh` |
| `test-permissions.sh` | Verify required permissions for all operations | `./auth/test-permissions.sh` |
| `check-prerequisites.sh` | Validate all required tools and configurations | `./auth/check-prerequisites.sh` |

### 🏢 Power Platform Environment Operations (`powerplatform/`)

| Script | Purpose | Usage |
|--------|---------|-------|
| `test-pp-environment.sh` | Test Power Platform environment accessibility and status | `./powerplatform/test-pp-environment.sh [ENV_ID]` |
| `create-pp-environment.sh` | Create a new Power Platform environment only | `./powerplatform/create-pp-environment.sh <name> <region>` |
| `delete-pp-environment.sh` | Delete a Power Platform environment | `./powerplatform/delete-pp-environment.sh <env_id>` |
| `enable-dataverse.sh` | Enable Dataverse database in an environment | `./powerplatform/enable-dataverse.sh <env_id>` |
| `enable-managed-environment.sh` | Enable managed environment features | `./powerplatform/enable-managed-environment.sh <env_id>` |

### 🏛️ Enterprise Policy Operations (`enterprise-policy/`)

| Script | Purpose | Usage |
|--------|---------|-------|
| `create-enterprise-policy.sh` | Create an Azure enterprise policy | `./enterprise-policy/create-enterprise-policy.sh <name> <rg>` |
| `delete-enterprise-policy.sh` | Delete an Azure enterprise policy | `./enterprise-policy/delete-enterprise-policy.sh <policy_id>` |
| `test-enterprise-policy.sh` | Test enterprise policy existence and configuration | `./enterprise-policy/test-enterprise-policy.sh <policy_name>` |
| `link-enterprise-policy.sh` | Link enterprise policy to Power Platform environment | `./enterprise-policy/link-enterprise-policy.sh <policy_id> <env_id>` |
| `unlink-enterprise-policy.sh` | Unlink enterprise policy from Power Platform environment | `./enterprise-policy/unlink-enterprise-policy.sh <policy_id> <env_id>` |
| `test-policy-linkage.sh` | Test if enterprise policy is properly linked to environment | `./enterprise-policy/test-policy-linkage.sh <env_id>` |

### ☁️ Azure Infrastructure Operations (`azure-infra/`)

| Script | Purpose | Usage |
|--------|---------|-------|
| `test-azure-resources.sh` | Test existence and status of all Azure resources | `./azure-infra/test-azure-resources.sh` |
| `test-vnet-connectivity.sh` | Test virtual network and subnet configuration | `./azure-infra/test-vnet-connectivity.sh <vnet_name>` |
| `test-private-dns.sh` | Test private DNS zone configuration | `./azure-infra/test-private-dns.sh <dns_zone>` |
| `create-vnet-subnet.sh` | Create VNet and subnet with proper delegation | `./azure-infra/create-vnet-subnet.sh <vnet_name> <subnet_name>` |
| `delete-azure-resources.sh` | Clean up all Azure resources | `./azure-infra/delete-azure-resources.sh <resource_group>` |

### 🔌 API Management Operations (`apim/`)

| Script | Purpose | Usage |
|--------|---------|-------|
| `test-apim-connectivity.sh` | Test APIM service connectivity and status | `./apim/test-apim-connectivity.sh <apim_name>` |
| `test-apim-api.sh` | Test specific API in APIM | `./apim/test-apim-api.sh <apim_name> <api_id>` |
| `create-apim-subscription.sh` | Create APIM subscription keys | `./apim/create-apim-subscription.sh <apim_name> <sub_name>` |
| `delete-apim-subscription.sh` | Delete APIM subscription keys | `./apim/delete-apim-subscription.sh <apim_name> <sub_name>` |
| `test-apim-backend.sh` | Test APIM backend service connectivity | `./apim/test-apim-backend.sh <apim_name> <backend_url>` |
| `import-api-to-apim.sh` | Import an API to APIM | `./apim/import-api-to-apim.sh <apim_name> <openapi_file>` |
| `export-api-from-apim.sh` | Export API definition from APIM | `./apim/export-api-from-apim.sh <apim_name> <api_id>` |

### 🔗 Custom Connector Operations (`connectors/`)

| Script | Purpose | Usage |
|--------|---------|-------|
| `test-custom-connector.sh` | Test custom connector functionality | `./connectors/test-custom-connector.sh <connector_name>` |
| `create-custom-connector.sh` | Create custom connector only | `./connectors/create-custom-connector.sh <name> <openapi_file>` |
| `delete-custom-connector.sh` | Delete custom connector | `./connectors/delete-custom-connector.sh <connector_id>` |
| `test-connector-auth.sh` | Test custom connector authentication | `./connectors/test-connector-auth.sh <connector_id>` |

### 🌐 Network Integration Testing (`network/`)

| Script | Purpose | Usage |
|--------|---------|-------|
| `test-private-endpoint.sh` | Test private endpoint connectivity | `./network/test-private-endpoint.sh <endpoint_name>` |
| `test-subnet-injection.sh` | Test if subnet injection is working properly | `./network/test-subnet-injection.sh <env_id>` |
| `test-end-to-end-connectivity.sh` | Complete end-to-end connectivity test | `./network/test-end-to-end-connectivity.sh` |
| `test-dns-resolution.sh` | Test DNS resolution for private endpoints | `./network/test-dns-resolution.sh <hostname>` |

### 📊 Monitoring & Diagnostics (`monitoring/`)

| Script | Purpose | Usage |
|--------|---------|-------|
| `get-deployment-status.sh` | Get status of all Azure deployments | `./monitoring/get-deployment-status.sh <resource_group>` |
| `get-pp-environment-info.sh` | Get detailed Power Platform environment information | `./monitoring/get-pp-environment-info.sh <env_id>` |
| `get-enterprise-policy-status.sh` | Get enterprise policy status and linkage info | `./monitoring/get-enterprise-policy-status.sh <policy_name>` |
| `collect-logs.sh` | Collect all relevant logs for troubleshooting | `./monitoring/collect-logs.sh` |
| `health-check.sh` | Overall health check of the entire system | `./monitoring/health-check.sh` |

### 🛠️ Utility Scripts (`utils/`)

| Script | Purpose | Usage |
|--------|---------|-------|
| `update-env-file.sh` | Update .env file with latest deployment outputs | `./utils/update-env-file.sh` |
| `validate-configuration.sh` | Validate all configuration values | `./utils/validate-configuration.sh` |
| `reset-configuration.sh` | Reset to clean state for retry | `./utils/reset-configuration.sh` |

### 📚 Shared Functions & Libraries (`common/`)

| File | Purpose | Usage |
|------|---------|-------|
| `functions.sh` | Common utility functions | Source: `. ./common/functions.sh` |
| `logging.sh` | Logging and output formatting | Source: `. ./common/logging.sh` |
| `config.sh` | Configuration management | Source: `. ./common/config.sh` |

## 🎯 Common Usage Patterns

### 1. **Full Health Check**
```bash
# Check overall system health
./monitoring/health-check.sh

# Check specific components
./auth/test-auth.sh
./azure-infra/test-azure-resources.sh
./enterprise-policy/test-policy-linkage.sh
./apim/test-apim-connectivity.sh
```

### 2. **Troubleshoot Enterprise Policy Issues**
```bash
# Test policy existence
./enterprise-policy/test-enterprise-policy.sh ep-Woodgrove-Prod-vdu

# Test linkage
./enterprise-policy/test-policy-linkage.sh 872eb56b-eda5-ed1b-b1ba-1232e690864f

# Unlink and relink if needed
./enterprise-policy/unlink-enterprise-policy.sh <policy_id> <env_id>
./enterprise-policy/link-enterprise-policy.sh <policy_id> <env_id>
```

### 3. **Troubleshoot APIM Connectivity**
```bash
# Test APIM service
./apim/test-apim-connectivity.sh az-apim-vdu

# Test specific API
./apim/test-apim-api.sh az-apim-vdu petstore-api

# Test backend connectivity
./apim/test-apim-backend.sh az-apim-vdu https://petstore.swagger.io/v2
```

### 4. **Network Troubleshooting**
```bash
# Test private endpoint
./network/test-private-endpoint.sh az-apim-vdu-pe

# Test DNS resolution
./network/test-dns-resolution.sh az-apim-vdu.azure-api.net

# Full connectivity test
./network/test-end-to-end-connectivity.sh
```

### 5. **Clean Slate Recovery**
```bash
# Reset configuration
./utils/reset-configuration.sh

# Delete and recreate components
./enterprise-policy/unlink-enterprise-policy.sh <policy_id> <env_id>
./enterprise-policy/delete-enterprise-policy.sh <policy_id>
./enterprise-policy/create-enterprise-policy.sh <name> <resource_group>
./enterprise-policy/link-enterprise-policy.sh <new_policy_id> <env_id>
```

## 🔧 Script Features

All scripts include:
- ✅ **Atomic operations** - Single responsibility principle
- ✅ **Detailed logging** - Clear success/failure indicators
- ✅ **Error handling** - Graceful failure with informative messages
- ✅ **Environment isolation** - Safe to run in any environment
- ✅ **Dry-run support** - Preview actions before execution (where applicable)
- ✅ **Common functions** - Shared utilities for consistency

## 📝 Environment Variables

Scripts automatically source configuration from:
1. **Project root `.env` file** - Main configuration
2. **Environment variables** - Override any setting
3. **Script parameters** - Override for single execution

Required variables:
```bash
TENANT_ID=<azure_tenant_id>
AZURE_SUBSCRIPTION_ID=<azure_subscription_id>
AZURE_LOCATION=<azure_region>
POWER_PLATFORM_ENVIRONMENT_NAME=<pp_environment_name>
POWER_PLATFORM_ENVIRONMENT_ID=<pp_environment_id>
RESOURCE_GROUP=<azure_resource_group>
ENTERPRISE_POLICY_NAME=<enterprise_policy_name>
APIM_NAME=<apim_service_name>
```

## 🚨 Error Codes

Scripts use standardized exit codes:
- `0` - Success
- `1` - General error
- `2` - Configuration error
- `3` - Authentication error
- `4` - Permission error
- `5` - Resource not found
- `6` - Network/connectivity error
- `7` - API error
- `10` - Dry-run mode (no action taken)

## 🔍 Debugging

### Enable Debug Mode
```bash
export DEBUG=true
./path/to/script.sh
```

### Collect Diagnostic Information
```bash
# Collect all logs and diagnostic info
./monitoring/collect-logs.sh

# Get detailed status of all components
./monitoring/health-check.sh --verbose
```

### Common Issues and Solutions

| Issue | Symptoms | Solution |
|-------|----------|----------|
| Authentication Failed | 401/403 errors | Run `./auth/test-auth.sh` |
| Enterprise Policy Not Linked | VNet integration not working | Run `./enterprise-policy/test-policy-linkage.sh` |
| APIM API Returns 502 | Gateway errors | Run `./apim/test-apim-backend.sh` |
| Private DNS Not Working | Name resolution fails | Run `./network/test-dns-resolution.sh` |
| Custom Connector Fails | Connection errors | Run `./connectors/test-connector-auth.sh` |

## 📞 Support

For issues with these scripts:
1. **Check logs**: All scripts provide detailed output
2. **Run health check**: `./monitoring/health-check.sh`
3. **Collect diagnostics**: `./monitoring/collect-logs.sh`
4. **Review prerequisites**: `./auth/check-prerequisites.sh`

## 🔄 Contributing

When adding new troubleshooting scripts:
1. Follow the atomic operation principle
2. Use common functions from `./common/`
3. Include comprehensive error handling
4. Update this README with the new script
5. Test in multiple scenarios

---

**Last Updated**: September 23, 2025  
**Version**: 1.0.0