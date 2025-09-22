# Cleanup Script Improvements

## Summary of Changes Made to 5-Cleanup.sh

Based on the successful manual resolution of enterprise policy unlinking issues, the following improvements have been implemented in the cleanup script:

### 1. Power Platform Access Token Correction

**Problem**: The script was using an incorrect resource endpoint for Power Platform access tokens.

**Solution**: Updated the `get_power_platform_access_token` function to use the correct resource endpoint:

```bash
# Before (incorrect):
local resource="https://api.bap.microsoft.com/"

# After (correct):
local resource="https://service.powerapps.com/"
```

**Rationale**: This matches the resource endpoint that was proven to work during manual testing and follows the pattern used in the original PowerShell scripts.

### 2. Enhanced Environment ID Fallback Mechanism

**Problem**: Script could fail if environment ID lookup failed.

**Solution**: Added fallback mechanism to use `POWER_PLATFORM_ENVIRONMENT_ID` from .env file:

```bash
# Fallback to environment variable if API lookup fails
if [[ -z "$environment_id" && -n "$POWER_PLATFORM_ENVIRONMENT_ID" ]]; then
    environment_id="$POWER_PLATFORM_ENVIRONMENT_ID"
    log_info "Using environment ID from configuration: $environment_id"
fi
```

### 3. Correct API Version and Endpoint

**Problem**: Script was using newer API versions that didn't work correctly.

**Solution**: Updated to use the proven API version and endpoint pattern:

```bash
# Use the API version that works (from original PowerShell scripts)
local api_version="2019-10-01"
local unlink_url="https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/environments/$environment_id/enterprisePolicies/NetworkInjection/unlink?api-version=$api_version"
```

### 4. Correct Request Body Construction

**Problem**: Request body wasn't properly formatted for the API.

**Solution**: Updated to use the correct format with SystemId:

```bash
# Get the policy system ID for the unlink operation
policy_system_id=$(az resource show --ids "$enterprise_policy_id" --query "properties.systemId" -o tsv 2>/dev/null || echo "")
if [[ -n "$policy_system_id" && "$policy_system_id" != "null" ]]; then
    body=$(jq -n --arg systemId "$policy_system_id" '{SystemId: $systemId}')
    log_info "Using enterprise policy system ID: $policy_system_id"
else
    log_warning "No system ID found for enterprise policy. Will try to unlink anyway."
fi
```

### 5. Improved Operation Polling

**Enhancement**: The existing polling logic was already good, but now it works with the correct API endpoints:

- Polls operation status correctly using the operation-location header
- Handles different operation states (Running, Succeeded, Failed)
- Has appropriate timeout and retry logic
- Provides clear logging throughout the process

### 6. Maintained Fallback Strategies

**Enhancement**: The script maintains multiple fallback approaches:

1. **Primary**: Power Platform API with correct authentication and body format
2. **Secondary**: Azure Resource Manager API for policy operations
3. **Tertiary**: Direct environment deletion as last resort

### Testing Results

The manual testing proved that these changes work correctly:

- ✅ Power Platform access token generation successful
- ✅ Enterprise policy unlinking successful (HTTP 202 response)
- ✅ Operation polling successful (all stages: Validate, Prepare, Run, Finalize)
- ✅ Enterprise policy resource deletion successful

### Key Technical Details

1. **API Version**: `2019-10-01` (not `2023-06-01`)
2. **Resource Endpoint**: `https://service.powerapps.com/` for access tokens
3. **Request Body**: Must include `SystemId` field with the enterprise policy's system identifier
4. **Authentication**: Power Platform access token (not Azure Resource Manager token)

### Expected Behavior

With these improvements, the cleanup script should now:

1. Successfully authenticate with Power Platform APIs
2. Correctly identify and unlink enterprise policies from environments
3. Properly handle asynchronous operations with polling
4. Successfully delete enterprise policy resources
5. Provide clear logging and error handling throughout the process

### Files Modified

- `5-Cleanup.sh`: Main cleanup script with corrected API implementation
- This document: Summary of changes for future reference

### Next Steps

The script is now ready for testing with real environments. The corrected implementation should resolve the enterprise policy unlinking issues that were encountered previously.
