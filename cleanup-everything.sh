#!/bin/bash
# Complete cleanup script - removes Azure resources and azd state

set -e  # Exit on any error

echo "🗑️  COMPLETE CLEANUP - This will remove EVERYTHING!"
echo "================================================="

# Load environment variables
if [ -f .env ]; then
    echo "Loading environment variables from .env..."
    source .env
else
    echo "⚠️  No .env file found, using azd environment variables"
fi

# Step 1: Remove Azure resources using azd
echo ""
echo "🔥 Step 1: Removing all Azure resources..."
if command -v azd &> /dev/null; then
    # Try azd down first
    echo "Using azd down to remove Azure resources..."
    azd down --force --purge || {
        echo "⚠️  azd down failed, trying alternative cleanup..."
        
        # Fallback: Use Azure CLI to delete resource group
        if [ ! -z "$AZURE_SUBSCRIPTION_ID" ] && [ ! -z "$resourceGroup" ]; then
            echo "Deleting resource group: $resourceGroup"
            az group delete --name "$resourceGroup" --subscription "$AZURE_SUBSCRIPTION_ID" --yes --no-wait
        else
            echo "❌ Could not determine resource group or subscription for cleanup"
        fi
    }
else
    echo "❌ azd not found, skipping Azure resource cleanup"
fi

# Step 2: Remove local azd state
echo ""
echo "🧹 Step 2: Removing local azd state..."
if [ -d ".azure" ]; then
    echo "Removing .azure directory..."
    rm -rf .azure/
    echo "✓ Local azd state removed"
else
    echo "✓ No .azure directory found"
fi

# Step 3: Clean global azd cache
echo ""
echo "🧽 Step 3: Cleaning global azd cache..."
if [ -d "$HOME/.azd" ]; then
    echo "Cleaning global azd cache..."
    rm -rf ~/.azd/auth_cache/ 2>/dev/null || true
    rm -rf ~/.azd/templates/ 2>/dev/null || true
    echo "✓ Global azd cache cleaned"
else
    echo "✓ No global azd cache found"
fi

# Step 4: Clean any remaining state files
echo ""
echo "🧼 Step 4: Cleaning remaining state files..."
# Remove any backup or temporary files
rm -f .env.backup 2>/dev/null || true
rm -f azure.yaml.backup 2>/dev/null || true

echo ""
echo "🎉 CLEANUP COMPLETE!"
echo "==================="
echo "✓ Azure resources removed (or deletion initiated)"
echo "✓ Local azd state cleared"
echo "✓ Global azd cache cleaned"
echo ""
echo "You can now start fresh with 'azd init' if needed."
