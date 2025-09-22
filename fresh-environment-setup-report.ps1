#!/usr/bin/env pwsh
<#
.SYNOPSIS
Fresh Power Platform Environment Setup Report - Woodgrove-Test

.DESCRIPTION
This script provides a comprehensive report of the freshly created Power Platform environment
and documents the manual steps required to complete the setup for enterprise use.

Environment Created: Woodgrove-Test
Environment ID: bb17c153-32e3-e0cf-92d8-85e1fc62b15c
Creation Method: Bash script (due to PowerShell authentication limitations)
#>

Write-Host "🎉 FRESH POWER PLATFORM ENVIRONMENT CREATED!" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green
Write-Host ""

# Read environment details from .env file
$envFile = "./.env"
$envVars = @{}
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^([^=]+)=(.*)$') {
            $envVars[$matches[1]] = $matches[2]
        }
    }
}

Write-Host "📋 ENVIRONMENT DETAILS" -ForegroundColor Cyan
Write-Host "=====================" -ForegroundColor Cyan
Write-Host "Environment Name: $($envVars['POWER_PLATFORM_ENVIRONMENT_NAME'])" -ForegroundColor White
Write-Host "Environment ID: $($envVars['POWER_PLATFORM_ENVIRONMENT_ID'])" -ForegroundColor White
Write-Host "Environment URL: $($envVars['POWER_PLATFORM_ENVIRONMENT_URL'])" -ForegroundColor White
Write-Host "Location: $($envVars['POWER_PLATFORM_LOCATION'])" -ForegroundColor White
Write-Host "Azure Region: $($envVars['AZURE_LOCATION'])" -ForegroundColor White
Write-Host ""

Write-Host "✅ COMPLETED AUTOMATED SETUP" -ForegroundColor Green
Write-Host "============================" -ForegroundColor Green
Write-Host "✓ Azure CLI authentication verified" -ForegroundColor Green
Write-Host "✓ Power Platform environment created successfully" -ForegroundColor Green
Write-Host "✓ Environment ID generated and saved to .env file" -ForegroundColor Green
Write-Host "✓ Base environment ready for customization" -ForegroundColor Green
Write-Host ""

Write-Host "⚠️  REQUIRED MANUAL STEPS" -ForegroundColor Yellow
Write-Host "========================" -ForegroundColor Yellow
Write-Host ""

Write-Host "🔹 STEP 1: ENABLE DATAVERSE DATABASE" -ForegroundColor Magenta
Write-Host "-----------------------------------" -ForegroundColor Magenta
Write-Host "1. Open: https://admin.powerplatform.microsoft.com/" -ForegroundColor White
Write-Host "2. Navigate to: Environments" -ForegroundColor White
Write-Host "3. Find and click: $($envVars['POWER_PLATFORM_ENVIRONMENT_NAME'])" -ForegroundColor Yellow
Write-Host "4. Click: Settings (top menu)" -ForegroundColor White
Write-Host "5. Under Resources, click: Dynamics 365 apps" -ForegroundColor White
Write-Host "6. Click: 'Create my database'" -ForegroundColor White
Write-Host "7. Configure:" -ForegroundColor White
Write-Host "   - Language: English (United States)" -ForegroundColor Gray
Write-Host "   - Currency: USD (or your preferred currency)" -ForegroundColor Gray
Write-Host "   - Enable sample apps: No (recommended)" -ForegroundColor Gray
Write-Host "   - Deploy sample apps: No (recommended)" -ForegroundColor Gray
Write-Host "8. Click: 'Create my database'" -ForegroundColor White
Write-Host "9. Wait: 10-15 minutes for database provisioning" -ForegroundColor White
Write-Host ""

Write-Host "🔹 STEP 2: ENABLE MANAGED ENVIRONMENT (RECOMMENDED)" -ForegroundColor Magenta
Write-Host "------------------------------------------------" -ForegroundColor Magenta
Write-Host "1. In the same environment settings page" -ForegroundColor White
Write-Host "2. Click: Features (left navigation)" -ForegroundColor White
Write-Host "3. Find: Managed Environment section" -ForegroundColor White
Write-Host "4. Toggle: 'Enable Managed Environment' to ON" -ForegroundColor White
Write-Host "5. Configure additional features as needed:" -ForegroundColor White
Write-Host "   - Data loss prevention policies" -ForegroundColor Gray
Write-Host "   - IP firewall restrictions" -ForegroundColor Gray
Write-Host "   - Customer-managed key (if required)" -ForegroundColor Gray
Write-Host "6. Click: Save" -ForegroundColor White
Write-Host ""

Write-Host "🔹 STEP 3: VERIFY CONFIGURATION" -ForegroundColor Magenta
Write-Host "------------------------------" -ForegroundColor Magenta
Write-Host "After completing the manual steps above:" -ForegroundColor White
Write-Host "1. Return to the environment details page" -ForegroundColor White
Write-Host "2. Verify Dataverse database is showing as 'Ready'" -ForegroundColor White
Write-Host "3. Note the Dataverse instance URL for integration" -ForegroundColor White
Write-Host "4. Update this project's .env file with Dataverse details" -ForegroundColor White
Write-Host ""

Write-Host "📋 WHY MANUAL STEPS ARE REQUIRED" -ForegroundColor Blue
Write-Host "===============================" -ForegroundColor Blue
Write-Host "• Dataverse provisioning requires tenant admin approval workflows" -ForegroundColor White
Write-Host "• Managed environment features need explicit enterprise governance setup" -ForegroundColor White
Write-Host "• API limitations prevent fully automated Dataverse configuration" -ForegroundColor White
Write-Host "• Enterprise security features require manual review and approval" -ForegroundColor White
Write-Host ""

Write-Host "🚀 NEXT STEPS AFTER MANUAL CONFIGURATION" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "Once manual steps are completed, proceed with:" -ForegroundColor White
Write-Host ""
Write-Host "1. Update .env file with Dataverse details:" -ForegroundColor Cyan
Write-Host "   - DATAVERSE_INSTANCE_URL=https://orgXXXXX.crm4.dynamics.com/" -ForegroundColor Gray
Write-Host "   - DATAVERSE_UNIQUE_NAME=orgXXXXX" -ForegroundColor Gray
Write-Host "   - DATAVERSE_DOMAIN_NAME=orgXXXXX" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Run infrastructure setup:" -ForegroundColor Cyan
Write-Host "   ./1-InfraSetup.ps1" -ForegroundColor Yellow
Write-Host ""
Write-Host "3. Configure VNet integration:" -ForegroundColor Cyan
Write-Host "   ./2-SubnetInjectionSetup.ps1" -ForegroundColor Yellow
Write-Host ""
Write-Host "4. Create custom connectors:" -ForegroundColor Cyan
Write-Host "   ./3-CreateCustomConnector.ps1" -ForegroundColor Yellow
Write-Host ""
Write-Host "5. Setup Copilot Studio:" -ForegroundColor Cyan
Write-Host "   ./4-SetupCopilotStudio.ps1" -ForegroundColor Yellow
Write-Host ""

Write-Host "📄 ENVIRONMENT FILE STATUS" -ForegroundColor Blue
Write-Host "==========================" -ForegroundColor Blue
Write-Host "Current .env file contains:" -ForegroundColor White
Get-Content $envFile | ForEach-Object { 
    if ($_ -match '^([^=]+)=(.*)$') {
        Write-Host "✓ $($matches[1])" -ForegroundColor Green
    }
}
Write-Host ""

Write-Host "⏰ ESTIMATED TIME TO COMPLETE MANUAL STEPS" -ForegroundColor Yellow
Write-Host "==========================================" -ForegroundColor Yellow
Write-Host "• Dataverse database creation: 10-15 minutes" -ForegroundColor White
Write-Host "• Managed environment setup: 5-10 minutes" -ForegroundColor White
Write-Host "• Configuration verification: 5 minutes" -ForegroundColor White
Write-Host "• Total estimated time: 20-30 minutes" -ForegroundColor White
Write-Host ""

Write-Host "🎯 SUCCESS CRITERIA" -ForegroundColor Green
Write-Host "==================" -ForegroundColor Green
Write-Host "Environment setup is complete when:" -ForegroundColor White
Write-Host "✓ Environment shows 'Ready' status in admin portal" -ForegroundColor Green
Write-Host "✓ Dataverse database is provisioned and accessible" -ForegroundColor Green
Write-Host "✓ Managed environment features are enabled (if desired)" -ForegroundColor Green
Write-Host "✓ .env file contains all Dataverse connection details" -ForegroundColor Green
Write-Host "✓ Ready to proceed with Azure infrastructure deployment" -ForegroundColor Green
Write-Host ""

Write-Host "🔧 AUTOMATION APPROACH USED" -ForegroundColor Blue
Write-Host "===========================" -ForegroundColor Blue
Write-Host "• Environment Creation: ✅ Automated via bash script" -ForegroundColor Green
Write-Host "• Dataverse Provisioning: ⚠️  Manual (API limitations)" -ForegroundColor Yellow
Write-Host "• Managed Environment: ⚠️  Manual (governance requirements)" -ForegroundColor Yellow
Write-Host "• Infrastructure Deployment: ✅ Automated (next step)" -ForegroundColor Green
Write-Host ""

Write-Host "💡 TROUBLESHOOTING TIPS" -ForegroundColor Cyan
Write-Host "======================" -ForegroundColor Cyan
Write-Host "If you encounter issues:" -ForegroundColor White
Write-Host "• Ensure you have Power Platform Admin rights" -ForegroundColor White
Write-Host "• Verify tenant allows Dataverse database creation" -ForegroundColor White
Write-Host "• Check that your organization hasn't reached environment limits" -ForegroundColor White
Write-Host "• Contact your tenant administrator if manual steps are blocked" -ForegroundColor White
Write-Host ""

Write-Host "🏁 READY TO BEGIN MANUAL CONFIGURATION!" -ForegroundColor Green -BackgroundColor Black
Write-Host "=======================================" -ForegroundColor Green -BackgroundColor Black
Write-Host ""
