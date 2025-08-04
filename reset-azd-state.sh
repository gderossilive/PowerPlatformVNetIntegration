#!/bin/bash
# Reset azd state script

echo "🧹 Resetting azd state..."
source .env

# Option 1: Delete specific environment
echo "Removing $POWER_PLATFORM_ENVIRONMENT_NAME environment..."
rm -rf .azure/$POWER_PLATFORM_ENVIRONMENT_NAME/

# Option 2: Reset entire azd project state
echo "Removing all azd state..."
rm -rf .azure/

# Option 3: Clean global azd cache (optional)
echo "Cleaning global azd cache..."
rm -rf ~/.azd/auth_cache/
rm -rf ~/.azd/templates/

echo "✓ azd state reset complete"
echo "You can now run 'azd init' to start fresh"
