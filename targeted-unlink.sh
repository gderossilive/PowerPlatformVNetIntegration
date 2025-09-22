#!/bin/bash

# Targeted Enterprise Policy Unlinking Script
# Based on the specific error message from Azure CLI

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE} Targeted Enterprise Policy Unlinking${NC}"
echo -e "${BLUE}========================================${NC}"

# Specific values from the error message
ENTERPRISE_POLICY_NAME="ep-Fabrikam-Test-y7c"
ENTERPRISE_POLICY_ID="1a78c91c-4a0d-4b1d-b705-78194b71b6f0"
ENVIRONMENT_ID="b7dc0277-b51d-e968-a04e-675cddbd3453"

echo -e "${YELLOW}Target Information:${NC}"
echo "  Enterprise Policy Name: $ENTERPRISE_POLICY_NAME"
echo "  Enterprise Policy ID: $ENTERPRISE_POLICY_ID"  
echo "  Environment ID: $ENVIRONMENT_ID"

# Get Power Platform access token
echo -e "\n${YELLOW}Getting Power Platform access token...${NC}"
PP_ACCESS_TOKEN=$(az account get-access-token \
  --resource https://service.powerapps.com/ \
  --query accessToken \
  --output tsv)

if [ -z "$PP_ACCESS_TOKEN" ]; then
    echo -e "${RED}✗ Failed to get Power Platform access token${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Power Platform access token obtained${NC}"

# Method 1: Try the direct unlink API endpoint
echo -e "\n${YELLOW}Method 1: Attempting direct enterprise policy unlink API...${NC}"
UNLINK_URL="https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/environments/$ENVIRONMENT_ID/enterprisePolicies/NetworkInjection/unlink?api-version=2023-06-01"

echo -e "${BLUE}URL: $UNLINK_URL${NC}"

UNLINK_RESPONSE=$(curl -s -w "HTTP_STATUS:%{http_code}" -X POST \
  "$UNLINK_URL" \
  -H "Authorization: Bearer $PP_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"systemId\": \"$ENTERPRISE_POLICY_ID\"}")

HTTP_STATUS=$(echo "$UNLINK_RESPONSE" | grep -o "HTTP_STATUS:[0-9]*" | cut -d: -f2)
RESPONSE_BODY=$(echo "$UNLINK_RESPONSE" | sed 's/HTTP_STATUS:[0-9]*$//')

echo -e "${BLUE}HTTP Status: $HTTP_STATUS${NC}"
echo -e "${BLUE}Response: $RESPONSE_BODY${NC}"

if [ "$HTTP_STATUS" = "202" ] || [ "$HTTP_STATUS" = "200" ]; then
    echo -e "${GREEN}✓ Enterprise policy unlink initiated successfully!${NC}"
    
    echo -e "${YELLOW}Waiting 30 seconds for operation to complete...${NC}"
    sleep 30
    
    # Verify the unlinking worked
    echo -e "${YELLOW}Verifying enterprise policy was unlinked...${NC}"
    VERIFY_RESPONSE=$(curl -s -X GET \
      "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/environments/$ENVIRONMENT_ID?api-version=2023-06-01" \
      -H "Authorization: Bearer $PP_ACCESS_TOKEN" \
      -H "Content-Type: application/json")
    
    CURRENT_POLICY=$(echo "$VERIFY_RESPONSE" | jq -r '.properties.networkInjection.enterprisePolicyArmId // "null"')
    
    if [ "$CURRENT_POLICY" = "null" ]; then
        echo -e "${GREEN}✓ SUCCESS: Enterprise policy successfully unlinked!${NC}"
        echo -e "${GREEN}✓ You can now proceed with Azure resource cleanup${NC}"
        exit 0
    else
        echo -e "${YELLOW}⚠ Enterprise policy may still be linked. Current policy: $CURRENT_POLICY${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Method 1 failed. Trying alternative approach...${NC}"
fi

# Method 2: Try the environment-specific unlink endpoint
echo -e "\n${YELLOW}Method 2: Attempting environment-specific unlink API...${NC}"
UNLINK_URL2="https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/environments/$ENVIRONMENT_ID/unlinkEnterprisePolicy?api-version=2023-06-01"

echo -e "${BLUE}URL: $UNLINK_URL2${NC}"

UNLINK_RESPONSE2=$(curl -s -w "HTTP_STATUS:%{http_code}" -X POST \
  "$UNLINK_URL2" \
  -H "Authorization: Bearer $PP_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"enterprisePolicySystemId\": \"$ENTERPRISE_POLICY_ID\"}")

HTTP_STATUS2=$(echo "$UNLINK_RESPONSE2" | grep -o "HTTP_STATUS:[0-9]*" | cut -d: -f2)
RESPONSE_BODY2=$(echo "$UNLINK_RESPONSE2" | sed 's/HTTP_STATUS:[0-9]*$//')

echo -e "${BLUE}HTTP Status: $HTTP_STATUS2${NC}"
echo -e "${BLUE}Response: $RESPONSE_BODY2${NC}"

if [ "$HTTP_STATUS2" = "202" ] || [ "$HTTP_STATUS2" = "200" ]; then
    echo -e "${GREEN}✓ Enterprise policy unlink initiated successfully!${NC}"
    
    echo -e "${YELLOW}Waiting 30 seconds for operation to complete...${NC}"
    sleep 30
    
    # Verify the unlinking worked
    echo -e "${YELLOW}Verifying enterprise policy was unlinked...${NC}"
    VERIFY_RESPONSE2=$(curl -s -X GET \
      "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/environments/$ENVIRONMENT_ID?api-version=2023-06-01" \
      -H "Authorization: Bearer $PP_ACCESS_TOKEN" \
      -H "Content-Type: application/json")
    
    CURRENT_POLICY2=$(echo "$VERIFY_RESPONSE2" | jq -r '.properties.networkInjection.enterprisePolicyArmId // "null"')
    
    if [ "$CURRENT_POLICY2" = "null" ]; then
        echo -e "${GREEN}✓ SUCCESS: Enterprise policy successfully unlinked!${NC}"
        echo -e "${GREEN}✓ You can now proceed with Azure resource cleanup${NC}"
        exit 0
    else
        echo -e "${YELLOW}⚠ Enterprise policy may still be linked. Current policy: $CURRENT_POLICY2${NC}"
    fi
else
    echo -e "${RED}✗ Method 2 also failed${NC}"
fi

# Summary
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE} UNLINKING SUMMARY${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "${RED}✗ Automatic unlinking failed${NC}"
echo -e "${YELLOW}Please try manual unlinking via Power Platform Admin Center:${NC}"
echo -e "${BLUE}1.${NC} Go to: ${BLUE}https://admin.powerplatform.microsoft.com/${NC}"
echo -e "${BLUE}2.${NC} Navigate to Environments > Find environment with ID: ${YELLOW}$ENVIRONMENT_ID${NC}"
echo -e "${BLUE}3.${NC} Go to Settings > Network settings"
echo -e "${BLUE}4.${NC} Remove VNet integration"
echo -e "${BLUE}========================================${NC}"

exit 1
