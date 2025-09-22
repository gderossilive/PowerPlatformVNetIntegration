# APIM Subnet Configuration Updates

## Summary of Changes

The VNet subnet configuration has been updated to properly support API Management VNet integration with the required delegation and NSG association.

### Changes Made to `infra/vnet-subnet-with-delegation-module.bicep`

#### 1. Added APIM Subnet with Proper Delegation

**Updated the APIM subnet configuration to include:**

- **Delegation to Microsoft.Web/serverFarms**: Required for APIM VNet integration
- **Network Security Group**: Already properly linked to the NSG resource
- **Service Endpoints**: Maintained existing endpoints for Storage, SQL, and KeyVault

```bicep
// API Management Subnet
resource apimSnet 'Microsoft.Network/virtualNetworks/subnets@2024-01-01' = {
  name: 'snet-apim-${locationSuffix}-${networkCategory}-${resourceToken}'
  parent: virtualNetwork
  dependsOn: [
    privateEndpointSnet
  ]
  properties: {
    addressPrefix: apimSnetAddressPrefixes
    delegations: [
      {
        name: 'serverFarms'
        properties: {
          serviceName: 'Microsoft.Web/serverFarms'
        }
      }
    ]
    serviceEndpoints: [
      {
        service: 'Microsoft.Storage'
        locations: [location]
      }
      {
        service: 'Microsoft.Sql'
        locations: [location]
      }
      {
        service: 'Microsoft.KeyVault'
        locations: [location]
      }
    ]
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Disabled'
    networkSecurityGroup: {
      id: networkSecurityGroup.id
    }
  }
}
```

### Key Requirements Addressed

✅ **Microsoft.Web/serverFarms Delegation**: Added delegation to the APIM subnet as required for VNet integration

✅ **Network Security Group Linkage**: APIM subnet is properly linked to the NSG (`networkSecurityGroup.id`)

✅ **Service Endpoints**: Maintained required service endpoints for Storage, SQL, and KeyVault

✅ **Private Endpoint Policies**: Configured appropriately for APIM requirements

### Network Architecture

The updated network configuration now includes:

1. **Injection Subnet** (`snet-injection-*`): Delegated to Microsoft.PowerPlatform/enterprisePolicies
2. **Private Endpoint Subnet** (`snet-pe-*`): For private endpoints without delegation
3. **APIM Subnet** (`snet-apim-*`): Delegated to Microsoft.Web/serverFarms for API Management

### Address Space Allocation

- Primary VNet: `10.0.0.0/16`
  - Injection Subnet: `10.0.1.0/24`
  - Private Endpoint Subnet: `10.0.2.0/24`
  - APIM Subnet: `10.0.3.0/24`

- Secondary VNet: `10.1.0.0/16`
  - Injection Subnet: `10.1.1.0/24`
  - Private Endpoint Subnet: `10.1.2.0/24`
  - APIM Subnet: `10.1.3.0/24`

### Deployment Impact

When deploying this template:

1. The APIM subnet will be created with the proper delegation
2. API Management can be deployed into this subnet with VNet integration
3. The NSG will automatically apply to the APIM subnet
4. Service endpoints will be available for backend service connectivity

### Validation

The Bicep templates have been validated and compile successfully:
- ✅ VNet subnet module compiles without errors
- ✅ Main template compiles without errors
- ⚠️ Pre-existing warnings are unrelated to these changes

This configuration ensures that API Management can be properly integrated into the VNet with all required Azure networking features and security controls.
