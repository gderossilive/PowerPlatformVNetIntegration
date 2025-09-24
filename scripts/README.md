# Scripts Overview

This directory contains the automation scripts used to provision, integrate, extend, and tear down the Power Platform + Azure Virtual Network Integration environment.

## ✅ Core Orchestration Flow
These scripts are typically executed in order (or via the top-level `RunMe.sh` orchestrator):

| Order | Script | Type | Purpose |
|-------|--------|------|---------|
| 0 | `0-CreatePowerPlatformEnvironment.sh` | Bash | Creates a new Power Platform environment and records its ID in `.env`. Base environment only (Dataverse manual). |
| 1 | `1-InfraSetup.sh` | Bash | Deploys Azure infrastructure (Resource Group, dual-region VNets, subnets, APIM, enterprise policy, private endpoint). Updates `.env`. |
| 2 | `2-SubnetInjectionSetup.sh` | Bash | Links the enterprise policy to the Power Platform environment (Subnet Injection). Adds/uses SystemId if present. |
| 3 | `3-CreateCustomConnector_v2.sh` | Bash | Deploys the connector via PAC CLI and guides manual connection creation with APIM key discovery. |
| 4 | `4-SetupCopilotStudio.sh` | Bash | Configures Copilot Studio (topics, connections, environment prep). |
| 5 | (Cleanup) Top-level `5-Cleanup.sh` | Bash | Removes Azure infra and guides manual deletion of the PP environment. |

> NOTE: You can run everything with: `./RunMe.sh -n <EnvName> -r westeurope -p europe --force`

## 🔧 Supporting / Specialized PowerShell Scripts
Some legacy and platform-specific operations remain as PowerShell (`pwsh`) scripts:

| Script | Purpose |
|--------|---------|
| `1-SetupSubscriptionForPowerPlatform.ps1` | Prepares Azure subscription (roles, resource providers) for Power Platform features. |
| `2-SetupVnetForSubnetDelegation.ps1` | Legacy helper for delegated subnets prior to consolidated Bicep-based deployment. |
| `3-CreateSubnetInjectionEnterprisePolicy.ps1` | Creates an enterprise policy via PowerShell (alternative to Bicep/runtime creation). |
| `5-NewSubnetInjection.ps1` | Experimental or iterative version of subnet injection linking logic. |

These remain for auditing or hybrid workflows; prefer the Bash equivalents in cross-platform pipelines.

## 📁 Common Module Directory
`common/` contains shared helper assets (functions, JSON payloads, or templates) referenced by one or more scripts.

## 📄 Environment File (`.env`)
Scripts read/write the root `.env` file. Typical keys after full deployment:
```
TENANT_ID=
AZURE_SUBSCRIPTION_ID=
AZURE_LOCATION=
POWER_PLATFORM_ENVIRONMENT_NAME=
POWER_PLATFORM_LOCATION=
POWER_PLATFORM_ENVIRONMENT_ID=
RESOURCE_GROUP=
PRIMARY_VIRTUAL_NETWORK_NAME=
PRIMARY_SUBNET_NAME=
SECONDARY_VIRTUAL_NETWORK_NAME=
SECONDARY_SUBNET_NAME=
ENTERPRISE_POLICY_NAME=
ENTERPRISE_POLICY_SYSTEM_ID=
APIM_NAME=
APIM_ID=
APIM_PRIVATE_DNS_ZONE_ID=
APIM_PRIVATE_DNS_ZONE_NAME=
```

## 🧭 Manual Steps Required
Some operations cannot be (or are not reliably) automated:
1. Enable Dataverse database for the new environment (Admin Center)
2. (Optional) Convert to Managed Environment & configure governance
3. Disable public access on APIM (if automation warnings occurred)
4. Approve private endpoint (if not automatically approved)
5. Validate network injection status (can briefly show Unknown)

## 🚀 Typical End-to-End Flow
```bash
# Run the main orchestrator (handles infrastructure and custom connector if PAC CLI is authenticated)
./RunMe.sh -n Fabrikam-Test -r westeurope -p europe --force

# Perform manual Dataverse + Managed Environment setup (see output instructions)

# If custom connector creation was skipped, authenticate PAC CLI and run manually
pac auth create --deviceCode
./scripts/3-CreateCustomConnector_v2.sh

# Continue with Copilot Studio setup
./scripts/4-SetupCopilotStudio.sh

# (Later) Clean up when done
./5-Cleanup.sh
```

## ♻️ Cleanup and Teardown
Run the cleanup script to remove Azure assets:
```bash
./5-Cleanup.sh
```
Then manually delete the Power Platform environment in the Admin Center.

## 🛠 Troubleshooting Tips
| Scenario | Action |
|----------|--------|
| APIM public access not disabled | Manually adjust in Azure Portal > APIM > Networking |
| Subnet injection status Unknown | Wait a few minutes then re-run `2-SubnetInjectionSetup.sh` |
| Environment ID missing | Re-run `0-CreatePowerPlatformEnvironment.sh` and ensure token retrieval succeeded |
| Custom connector fails to reach APIM | Check DNS resolution inside environment & private endpoint state |
| PAC CLI not authenticated | Run `pac auth create --deviceCode` to authenticate with Power Platform |
| Custom connector creation fails | Check PAC CLI auth with `pac auth list` and ensure environment permissions |

## 🔄 Future Enhancements (Ideas)
- Add health verification script (connector test ping)
- Extend `RunMe.sh` with optional phases (connector, Copilot)
- Generate markdown deployment report
- Integrate CI pipeline examples (GitHub Actions/Azure DevOps)

---
Maintained as part of the Power Platform VNet Integration automation toolkit.
