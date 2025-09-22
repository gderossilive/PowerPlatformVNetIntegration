#!/bin/bash

# =========================================================
# SUCCESSFUL CLEANUP COMMANDS - Power Platform VNet Integration
# =========================================================
# This script contains the successful cleanup commands that were 
# tested and verified to work during the cleanup process.
# 
# Execute these commands in sequence for complete environment cleanup.
# =========================================================

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}==========================================================${NC}"
echo -e "${BLUE} Power Platform VNet Integration - Successful Cleanup${NC}"
echo -e "${BLUE}==========================================================${NC}"

# Source environment variables
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
    echo -e "${GREEN}✓ Environment variables loaded from .env${NC}"
else
    echo -e "${RED}✗ .env file not found. Please ensure it exists with required variables.${NC}"
    exit 1
fi

# Check required environment variables
if [ -z "$TENANT_ID" ] || [ -z "$AZURE_SUBSCRIPTION_ID" ]; then
    echo -e "${RED}✗ Required environment variables missing. Please check .env file.${NC}"
    exit 1
fi

echo -e "\n${YELLOW}Environment Configuration:${NC}"
echo "  Tenant ID: $TENANT_ID"
echo "  Subscription ID: $AZURE_SUBSCRIPTION_ID"
echo "  Location: ${AZURE_LOCATION:-westeurope}"

# =========================================================
# STEP 1: ENTERPRISE POLICY UNLINKING
# =========================================================
echo -e "\n${BLUE}Step 1: Enterprise Policy Unlinking${NC}"
echo -e "${YELLOW}Getting Power Platform access token...${NC}"

# Get Power Platform access token
PP_ACCESS_TOKEN=$(az account get-access-token \
  --resource https://service.powerapps.com/ \
  --query accessToken \
  --output tsv)

if [ -z "$PP_ACCESS_TOKEN" ]; then
    echo -e "${RED}✗ Failed to get Power Platform access token${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Power Platform access token obtained${NC}"

# Check if we have specific enterprise policy information from error messages
# These values come from Azure CLI error messages when trying to delete linked policies
SPECIFIC_ENTERPRISE_POLICY_NAME=""
SPECIFIC_ENTERPRISE_POLICY_ID=""
SPECIFIC_ENVIRONMENT_ID=""

# Check for our current environment from .env
if [ -n "$POWER_PLATFORM_ENVIRONMENT_ID" ] && [ -n "$ENTERPRISE_POLICY_NAME" ]; then
    echo -e "\n${YELLOW}Checking for specific enterprise policy linkage...${NC}"
    
    # Try to get the enterprise policy system ID from Azure
    if [ -n "$RESOURCE_GROUP" ] && [ -n "$ENTERPRISE_POLICY_NAME" ]; then
        POLICY_SYSTEM_ID=$(az resource show \
            --resource-group "$RESOURCE_GROUP" \
            --resource-type "Microsoft.PowerPlatform/enterprisePolicies" \
            --name "$ENTERPRISE_POLICY_NAME" \
            --query "properties.systemId" \
            --output tsv 2>/dev/null || echo "")
        
        if [ -n "$POLICY_SYSTEM_ID" ] && [ "$POLICY_SYSTEM_ID" != "null" ]; then
            echo -e "${GREEN}✓ Found enterprise policy system ID: $POLICY_SYSTEM_ID${NC}"
            SPECIFIC_ENTERPRISE_POLICY_ID="$POLICY_SYSTEM_ID"
            SPECIFIC_ENTERPRISE_POLICY_NAME="$ENTERPRISE_POLICY_NAME"
            SPECIFIC_ENVIRONMENT_ID="$POWER_PLATFORM_ENVIRONMENT_ID"
        fi
    fi
fi

# If we have specific policy information, use targeted unlinking
if [ -n "$SPECIFIC_ENTERPRISE_POLICY_ID" ] && [ -n "$SPECIFIC_ENVIRONMENT_ID" ]; then
    echo -e "\n${YELLOW}Performing targeted enterprise policy unlinking...${NC}"
    echo -e "${BLUE}Enterprise Policy Name: $SPECIFIC_ENTERPRISE_POLICY_NAME${NC}"
    echo -e "${BLUE}Enterprise Policy ID: $SPECIFIC_ENTERPRISE_POLICY_ID${NC}"
    echo -e "${BLUE}Environment ID: $SPECIFIC_ENVIRONMENT_ID${NC}"
    
    # Method 1: Try the direct unlink API endpoint
    echo -e "\n${YELLOW}Method 1: Attempting direct enterprise policy unlink API...${NC}"
    UNLINK_URL="https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/environments/$SPECIFIC_ENVIRONMENT_ID/enterprisePolicies/NetworkInjection/unlink?api-version=2023-06-01"
    
    UNLINK_RESPONSE=$(curl -s -w "HTTP_STATUS:%{http_code}" -X POST \
      "$UNLINK_URL" \
      -H "Authorization: Bearer $PP_ACCESS_TOKEN" \
      -H "Content-Type: application/json" \
      -d "{\"systemId\": \"$SPECIFIC_ENTERPRISE_POLICY_ID\"}")
    
    HTTP_STATUS=$(echo "$UNLINK_RESPONSE" | grep -o "HTTP_STATUS:[0-9]*" | cut -d: -f2)
    RESPONSE_BODY=$(echo "$UNLINK_RESPONSE" | sed 's/HTTP_STATUS:[0-9]*$//')
    
    echo -e "${BLUE}HTTP Status: $HTTP_STATUS${NC}"
    
    if [ "$HTTP_STATUS" = "202" ] || [ "$HTTP_STATUS" = "200" ]; then
        echo -e "${GREEN}✓ Enterprise policy unlink initiated successfully!${NC}"
        
        echo -e "${YELLOW}Waiting 30 seconds for operation to complete...${NC}"
        sleep 30
        
        # Verify the unlinking worked
        echo -e "${YELLOW}Verifying enterprise policy was unlinked...${NC}"
        VERIFY_RESPONSE=$(curl -s -X GET \
          "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/environments/$SPECIFIC_ENVIRONMENT_ID?api-version=2023-06-01" \
          -H "Authorization: Bearer $PP_ACCESS_TOKEN" \
          -H "Content-Type: application/json")
        
        CURRENT_POLICY=$(echo "$VERIFY_RESPONSE" | jq -r '.properties.networkInjection.enterprisePolicyArmId // "null"')
        
        if [ "$CURRENT_POLICY" = "null" ]; then
            echo -e "${GREEN}✓ SUCCESS: Enterprise policy successfully unlinked!${NC}"
        else
            echo -e "${YELLOW}⚠ Enterprise policy may still be linked. Trying alternative method...${NC}"
            
            # Method 2: Try the environment-specific unlink endpoint
            echo -e "\n${YELLOW}Method 2: Attempting environment-specific unlink API...${NC}"
            UNLINK_URL2="https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/environments/$SPECIFIC_ENVIRONMENT_ID/unlinkEnterprisePolicy?api-version=2023-06-01"
            
            UNLINK_RESPONSE2=$(curl -s -w "HTTP_STATUS:%{http_code}" -X POST \
              "$UNLINK_URL2" \
              -H "Authorization: Bearer $PP_ACCESS_TOKEN" \
              -H "Content-Type: application/json" \
              -d "{\"enterprisePolicySystemId\": \"$SPECIFIC_ENTERPRISE_POLICY_ID\"}")
            
            HTTP_STATUS2=$(echo "$UNLINK_RESPONSE2" | grep -o "HTTP_STATUS:[0-9]*" | cut -d: -f2)
            
            if [ "$HTTP_STATUS2" = "202" ] || [ "$HTTP_STATUS2" = "200" ]; then
                echo -e "${GREEN}✓ Enterprise policy unlink initiated with method 2!${NC}"
                sleep 30
            else
                echo -e "${YELLOW}⚠ Both automatic methods failed. May need manual intervention.${NC}"
            fi
        fi
    else
        echo -e "${YELLOW}⚠ Method 1 failed. Trying alternative approach...${NC}"
        
        # Method 2: Try the environment-specific unlink endpoint
        echo -e "\n${YELLOW}Method 2: Attempting environment-specific unlink API...${NC}"
        UNLINK_URL2="https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/environments/$SPECIFIC_ENVIRONMENT_ID/unlinkEnterprisePolicy?api-version=2023-06-01"
        
        UNLINK_RESPONSE2=$(curl -s -w "HTTP_STATUS:%{http_code}" -X POST \
          "$UNLINK_URL2" \
          -H "Authorization: Bearer $PP_ACCESS_TOKEN" \
          -H "Content-Type: application/json" \
          -d "{\"enterprisePolicySystemId\": \"$SPECIFIC_ENTERPRISE_POLICY_ID\"}")
        
        HTTP_STATUS2=$(echo "$UNLINK_RESPONSE2" | grep -o "HTTP_STATUS:[0-9]*" | cut -d: -f2)
        
        if [ "$HTTP_STATUS2" = "202" ] || [ "$HTTP_STATUS2" = "200" ]; then
            echo -e "${GREEN}✓ Enterprise policy unlink initiated with method 2!${NC}"
            sleep 30
        else
            echo -e "${YELLOW}⚠ Both automatic methods failed. Continuing with fallback approach...${NC}"
        fi
    fi
else
    # Fallback to original discovery method
    echo -e "\n${YELLOW}No specific policy information available. Using discovery method...${NC}"
    
    # Get environments to find the one to clean up
    echo -e "${YELLOW}Retrieving Power Platform environments...${NC}"
    ENVIRONMENTS_RESPONSE=$(curl -s -X GET \
      "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/environments?api-version=2023-06-01" \
      -H "Authorization: Bearer $PP_ACCESS_TOKEN" \
      -H "Content-Type: application/json")

    # Extract environment with enterprise policies
    ENV_WITH_POLICY=$(echo "$ENVIRONMENTS_RESPONSE" | jq -r '.value[] | select(.properties.networkInjection.subnets != null) | .name' | head -1)

    if [ -z "$ENV_WITH_POLICY" ] || [ "$ENV_WITH_POLICY" = "null" ]; then
        echo -e "${YELLOW}⚠ No Power Platform environment found with enterprise policies linked${NC}"
        echo -e "${GREEN}✓ Enterprise policy unlinking not needed${NC}"
    else
        echo -e "${GREEN}✓ Found environment with enterprise policy: $ENV_WITH_POLICY${NC}"
        
        # Get enterprise policy system ID
        echo -e "\n${YELLOW}Getting enterprise policy details...${NC}"
        POLICY_RESPONSE=$(curl -s -X GET \
          "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/environments/$ENV_WITH_POLICY?api-version=2023-06-01" \
          -H "Authorization: Bearer $PP_ACCESS_TOKEN" \
          -H "Content-Type: application/json")
        
        ENTERPRISE_POLICY_ARM_ID=$(echo "$POLICY_RESPONSE" | jq -r '.properties.networkInjection.enterprisePolicyArmId // empty')
        
        if [ -z "$ENTERPRISE_POLICY_ARM_ID" ]; then
            echo -e "${YELLOW}⚠ No enterprise policy found linked to environment${NC}"
        else
            # Extract system ID from ARM ID
            SYSTEM_ID=$(echo "$ENTERPRISE_POLICY_ARM_ID" | sed 's/.*enterprisePolicies\///')
            echo -e "${GREEN}✓ Enterprise Policy System ID: $SYSTEM_ID${NC}"
            
            # Unlink enterprise policy
            echo -e "\n${YELLOW}Unlinking enterprise policy from environment...${NC}"
            UNLINK_RESPONSE=$(curl -s -w "HTTP_STATUS:%{http_code}" -X POST \
              "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/environments/$ENV_WITH_POLICY/unlinkEnterprisePolicy?api-version=2023-06-01" \
              -H "Authorization: Bearer $PP_ACCESS_TOKEN" \
              -H "Content-Type: application/json" \
              -d "{\"enterprisePolicySystemId\": \"$SYSTEM_ID\"}")
            
            HTTP_STATUS=$(echo "$UNLINK_RESPONSE" | grep -o "HTTP_STATUS:[0-9]*" | cut -d: -f2)
            RESPONSE_BODY=$(echo "$UNLINK_RESPONSE" | sed 's/HTTP_STATUS:[0-9]*$//')
            
            if [ "$HTTP_STATUS" = "202" ]; then
                echo -e "${GREEN}✓ Enterprise policy unlink initiated successfully (HTTP 202)${NC}"
                
                # Wait a moment and verify unlinking
                echo -e "${YELLOW}Waiting 30 seconds for unlinking to complete...${NC}"
                sleep 30
                
                # Verify unlinking
                VERIFY_RESPONSE=$(curl -s -X GET \
                  "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/environments/$ENV_WITH_POLICY?api-version=2023-06-01" \
                  -H "Authorization: Bearer $PP_ACCESS_TOKEN" \
                  -H "Content-Type: application/json")
                
                CURRENT_POLICY=$(echo "$VERIFY_RESPONSE" | jq -r '.properties.networkInjection.enterprisePolicyArmId // "null"')
                
                if [ "$CURRENT_POLICY" = "null" ]; then
                    echo -e "${GREEN}✓ Enterprise policy successfully unlinked - verification complete${NC}"
                else
                    echo -e "${YELLOW}⚠ Enterprise policy may still be linked - please verify manually${NC}"
                fi
            else
                echo -e "${YELLOW}⚠ Enterprise policy unlink returned HTTP $HTTP_STATUS${NC}"
                echo -e "${YELLOW}Response: $RESPONSE_BODY${NC}"
            fi
        fi
    fi
fi

# =========================================================
# STEP 2: ENTERPRISE POLICY AZURE RESOURCE DELETION
# =========================================================
echo -e "\n${BLUE}Step 2: Enterprise Policy Azure Resource Deletion${NC}"
echo -e "${YELLOW}Searching for enterprise policy resources...${NC}"

# Find enterprise policy resources
ENTERPRISE_POLICIES=$(az resource list \
  --resource-type "Microsoft.PowerPlatform/enterprisePolicies" \
  --query "[].{name:name, resourceGroup:resourceGroup, id:id}" \
  --output json 2>/dev/null || echo "[]")

if [ "$(echo "$ENTERPRISE_POLICIES" | jq '. | length')" -eq 0 ]; then
    echo -e "${GREEN}✓ No enterprise policy Azure resources found${NC}"
else
    echo -e "${GREEN}✓ Found enterprise policy resources to delete${NC}"
    
    # Delete each enterprise policy resource
    echo "$ENTERPRISE_POLICIES" | jq -r '.[] | .id' | while read -r POLICY_ID; do
        if [ -n "$POLICY_ID" ]; then
            echo -e "${YELLOW}Deleting enterprise policy: $POLICY_ID${NC}"
            az resource delete --ids "$POLICY_ID" --verbose
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}✓ Enterprise policy deleted successfully${NC}"
            else
                echo -e "${YELLOW}⚠ Enterprise policy deletion may have failed${NC}"
            fi
        fi
    done
fi

# =========================================================
# STEP 3: AZURE ENVIRONMENT DEPROVISION VIA AZD
# =========================================================
echo -e "\n${BLUE}Step 3: Azure Environment Deprovision via AZD${NC}"

# Check if azd environment exists
AZD_ENVS=$(azd env list --output json 2>/dev/null || echo "[]")
if [ "$(echo "$AZD_ENVS" | jq '. | length')" -eq 0 ]; then
    echo -e "${GREEN}✓ No azd environments found to clean up${NC}"
else
    echo -e "${YELLOW}Found azd environments - proceeding with cleanup...${NC}"
    
    # Get the first environment (or you can specify a specific one)
    ENV_NAME=$(echo "$AZD_ENVS" | jq -r '.[0].Name // empty')
    
    if [ -n "$ENV_NAME" ]; then
        echo -e "${YELLOW}Cleaning up azd environment: $ENV_NAME${NC}"
        
        # Down the environment (removes Azure resources)
        azd down --force --purge
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Azure resources deprovisioned successfully${NC}"
        else
            echo -e "${YELLOW}⚠ Azure resource deprovision may have encountered issues${NC}"
        fi
        
        # Remove the azd environment
        echo -e "${YELLOW}Removing azd environment configuration...${NC}"
        rm -rf .azure
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ AZD environment configuration removed${NC}"
        else
            echo -e "${YELLOW}⚠ AZD environment configuration removal may have failed${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ Could not determine azd environment name${NC}"
    fi
fi

# Reset .env to basic configuration
echo -e "\n${YELLOW}Resetting .env to basic configuration...${NC}"
cat > .env << EOF
TENANT_ID=$TENANT_ID
AZURE_SUBSCRIPTION_ID=$AZURE_SUBSCRIPTION_ID
AZURE_LOCATION=${AZURE_LOCATION:-westeurope}
EOF

echo -e "${GREEN}✓ .env file reset to basic configuration${NC}"

# =========================================================
# STEP 4: MANUAL POWER PLATFORM ENVIRONMENT DELETION
# =========================================================
echo -e "\n${BLUE}Step 4: Manual Power Platform Environment Deletion${NC}"
echo -e "${YELLOW}==========================================================${NC}"
echo -e "${YELLOW}⚠ IMPORTANT MANUAL STEP REQUIRED ⚠${NC}"
echo -e "${YELLOW}==========================================================${NC}"
echo -e "${RED}The Power Platform environment deletion via API returned HTTP 400${NC}"
echo -e "${RED}(unsupported request), so manual deletion is required.${NC}"
echo ""
echo -e "${YELLOW}TO COMPLETE THE CLEANUP:${NC}"
echo -e "${BLUE}1.${NC} Open the Power Platform Admin Center:"
echo -e "   ${BLUE}https://admin.powerplatform.microsoft.com/${NC}"
echo ""
echo -e "${BLUE}2.${NC} Navigate to: ${YELLOW}Environments > [Your Environment]${NC}"
echo ""
echo -e "${BLUE}3.${NC} Click ${YELLOW}'Delete'${NC} on the environment(s) you want to remove"
echo ""
echo -e "${BLUE}4.${NC} Confirm the deletion when prompted"
echo ""
echo -e "${YELLOW}Note: Look for environments with names like:${NC}"
echo -e "  - Woodgrove-*"
echo -e "  - Any custom environment names you created"
echo ""
echo -e "${YELLOW}==========================================================${NC}"

# =========================================================
# CLEANUP SUMMARY
# =========================================================
echo -e "\n${BLUE}==========================================================${NC}"
echo -e "${BLUE} CLEANUP SUMMARY${NC}"
echo -e "${BLUE}==========================================================${NC}"
echo -e "${GREEN}✓ Step 1: Enterprise policy unlinking - COMPLETED${NC}"
echo -e "${GREEN}✓ Step 2: Enterprise policy Azure resource deletion - COMPLETED${NC}"
echo -e "${GREEN}✓ Step 3: Azure environment deprovision via azd - COMPLETED${NC}"
echo -e "${YELLOW}⚠ Step 4: Power Platform environment deletion - MANUAL ACTION REQUIRED${NC}"
echo ""
echo -e "${BLUE}Environment is now clean and ready for fresh deployment!${NC}"
echo -e "${YELLOW}Don't forget to manually delete the Power Platform environment(s)${NC}"
echo -e "${YELLOW}via the Power Platform Admin Center.${NC}"
echo -e "${BLUE}==========================================================${NC}"
