<#
Enhanced enterprise policy unlink / revert test harness.

Features:
 - Parameterized environment & policy selection
 - Auto discovery of policy systemId (regional path & GUID)
 - Matrix testing across API versions & body variants (unlink + revert)
 - Captures status, correlation ID, error code/message per attempt
 - Polling for 202 Accepted long‑running operations (operation-location header)
 - Optional single attempt (default) or full matrix (-Matrix)

Usage examples:
  pwsh ./test-unlink.ps1 -EnvironmentId e44e7751-91ac-ec21-b5e3-19053bb83559 -PolicyName ep-E2E-Test-082141-fqb -ResourceGroup E2E-Test-082141-fqb
  pwsh ./test-unlink.ps1 -EnvironmentId e44e7751-91ac-ec21-b5e3-19053bb83559 -PolicyName ep-E2E-Test-082141-fqb -ResourceGroup E2E-Test-082141-fqb -Mode Unlink -Matrix
  pwsh ./test-unlink.ps1 -EnvironmentId e44e7751-91ac-ec21-b5e3-19053bb83559 -PolicyName ep-E2E-Test-082141-fqb -ResourceGroup E2E-Test-082141-fqb -Mode Both -Matrix

NOTE: Requires Azure CLI authenticated (az login) & sufficient RBAC to read Power Platform enterprise policies.
#>

param(
    [Parameter()][string]$EnvironmentId = "e44e7751-91ac-ec21-b5e3-19053bb83559",
    [Parameter()][string]$PolicyName = "ep-E2E-Test-082141-fqb",
    [Parameter()][string]$ResourceGroup = "E2E-Test-082141-fqb",
    [Parameter()][ValidateSet('Unlink','Revert','Both')][string]$Mode = 'Both',
    [switch]$Matrix,
    [int]$PollSeconds = 600,
    [int]$PollIntervalSeconds = 10
)

function Get-AccessToken {
    az account get-access-token --resource "https://service.powerapps.com/" --query accessToken -o tsv
}

function Get-PolicyResource {
    param([string]$Rg,[string]$Name)
    $json = az resource show -g $Rg -n $Name --resource-type Microsoft.PowerPlatform/enterprisePolicies -o json 2>$null
    if (-not $json) { throw "Unable to fetch enterprise policy $Name in $Rg" }
    return ($json | ConvertFrom-Json)
}

function Invoke-PolicyAction {
    param(
        [string]$EnvironmentId,
        [string]$Action, # Unlink | Revert
        [string]$ApiVersion,
        [hashtable]$Body,
        [string]$VariantName,
        [string]$AccessToken
    )
    $endpoint = "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/environments/$EnvironmentId/enterprisePolicies/NetworkInjection/$($Action.ToLower())?api-version=$ApiVersion"
    $jsonBody = ($Body | ConvertTo-Json -Compress -Depth 5)
    $headers = @{ Authorization = "Bearer $AccessToken" }

    $result = [ordered]@{
        action       = $Action
        apiVersion   = $ApiVersion
        variant      = $VariantName
        status       = $null
        correlationId= $null
        errorCode    = $null
        message      = $null
        operationLoc = $null
    }
    try {
        $response = Invoke-WebRequest -Uri $endpoint -Method Post -Headers $headers -Body $jsonBody -ContentType 'application/json' -ErrorAction Stop
        $result.status = $response.StatusCode.value__
        if ($response.Headers['x-ms-correlation-request-id']) { $result.correlationId = $response.Headers['x-ms-correlation-request-id'] }
        if ($response.StatusCode -eq 202) {
            $opLoc = $response.Headers['Operation-Location']
            if (-not $opLoc) { $opLoc = $response.Headers['operation-location'] }
            $result.operationLoc = $opLoc
            $result.message = 'Accepted (async)'
        } else {
            if ($response.Content) {
                try {
                    $parsed = $response.Content | ConvertFrom-Json -ErrorAction Stop
                    if ($parsed.error) {
                        $result.errorCode = $parsed.error.code
                        $result.message   = $parsed.error.message
                    } else {
                        $result.message = ($response.Content.Substring(0,[Math]::Min($response.Content.Length,120)))
                    }
                } catch { $result.message = 'Non-JSON success content' }
            }
        }
    } catch {
        $webEx = $_.Exception
        if ($webEx.Response) {
            $statusCode = $webEx.Response.StatusCode.value__
            $result.status = $statusCode
            $corr = $webEx.Response.Headers['x-ms-correlation-request-id']
            if ($corr) { $result.correlationId = $corr }
            $stream = $webEx.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($stream)
            $content = $reader.ReadToEnd()
            if ($content) {
                try {
                    $parsedErr = $content | ConvertFrom-Json -ErrorAction Stop
                    if ($parsedErr.error) { $result.errorCode = $parsedErr.error.code; $result.message = $parsedErr.error.message }
                    else { $result.message = ($content.Substring(0,[Math]::Min($content.Length,160))) }
                } catch { $result.message = ($content.Substring(0,[Math]::Min($content.Length,160))) }
            } else { $result.message = $webEx.Message }
        } else {
            $result.status = 0
            $result.message = $webEx.Message
        }
    }
    return [pscustomobject]$result
}

function Poll-Operation {
    param(
        [string]$OperationLocation,
        [string]$AccessToken,
        [int]$TimeoutSeconds,
        [int]$IntervalSeconds
    )
    if (-not $OperationLocation) { return }
    Write-Host "Polling operation: $OperationLocation" -ForegroundColor Cyan
    $stopWatch = [System.Diagnostics.Stopwatch]::StartNew()
    while ($stopWatch.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
        try {
            $resp = Invoke-RestMethod -Uri $OperationLocation -Headers @{Authorization = "Bearer $AccessToken"}
            $state = $resp.status
            Write-Host ("  Status: {0} Elapsed: {1:n0}s" -f $state, $stopWatch.Elapsed.TotalSeconds)
            if ($state -in @('Succeeded','Failed','Canceled')) { return $resp }
        } catch {
            Write-Host "  Poll error: $($_.Exception.Message)" -ForegroundColor Yellow
        }
        Start-Sleep -Seconds $IntervalSeconds
    }
    Write-Host "Polling timed out after $TimeoutSeconds seconds" -ForegroundColor Yellow
}

Write-Host "== Enterprise Policy Unlink/Revert Test ==" -ForegroundColor Green
Write-Host "Environment: $EnvironmentId" -ForegroundColor Green
Write-Host "Policy: $PolicyName (RG: $ResourceGroup)" -ForegroundColor Green
Write-Host "Mode: $Mode  Matrix: $Matrix" -ForegroundColor Green

$accessToken = Get-AccessToken
if (-not $accessToken) { throw 'Failed to get access token (az login?)' }

$policy = Get-PolicyResource -Rg $ResourceGroup -Name $PolicyName
$policyArmId = $policy.id
$policySystemPath = $policy.properties.systemId
$policySystemGuid = ($policySystemPath -split '/')[-1]

Write-Host "Policy ARM Id: $policyArmId"
Write-Host "Policy System Path: $policySystemPath"
Write-Host "Policy System GUID: $policySystemGuid"

$apiVersions = @('2019-10-01','2022-03-01','2023-06-01','2024-05-01')
$actions = switch ($Mode) { 'Unlink' { @('Unlink') } 'Revert' { @('Revert') } 'Both' { @('Unlink','Revert') } }

# Body variants
$variants = @(
    @{ name = 'guid';        body = @{ SystemId = $policySystemGuid } },
    @{ name = 'systemPath';  body = @{ SystemId = $policySystemPath } },
    @{ name = 'armId';       body = @{ SystemId = $policyArmId } },
    @{ name = 'lower-guid';  body = @{ systemId = $policySystemGuid } },
    @{ name = 'empty';       body = @{} }
)

$results = @()

if ($Matrix) {
    foreach ($action in $actions) {
        foreach ($ver in $apiVersions) {
            foreach ($variant in $variants) {
                Write-Host ("Attempt: {0} {1} {2}" -f $action,$ver,$variant.name) -ForegroundColor Cyan
                $res = Invoke-PolicyAction -EnvironmentId $EnvironmentId -Action $action -ApiVersion $ver -Body $variant.body -VariantName $variant.name -AccessToken $accessToken
                $results += $res
                if ($res.operationLoc) {
                    $final = Poll-Operation -OperationLocation $res.operationLoc -AccessToken $accessToken -TimeoutSeconds $PollSeconds -IntervalSeconds $PollIntervalSeconds
                    if ($final) { $res | Add-Member -NotePropertyName finalStatus -NotePropertyValue $final.status }
                }
            }
        }
    }
} else {
    # Single attempt (unlink preferred first)
    $primaryAction = if ($Mode -eq 'Revert') { 'Revert' } else { 'Unlink' }
    $primaryVariant = $variants | Where-Object { $_.name -eq 'systemPath' }
    Write-Host ("Single attempt: {0} apiVersion=2019-10-01 variant={1}" -f $primaryAction,$primaryVariant.name) -ForegroundColor Cyan
    $res = Invoke-PolicyAction -EnvironmentId $EnvironmentId -Action $primaryAction -ApiVersion '2019-10-01' -Body $primaryVariant.body -VariantName $primaryVariant.name -AccessToken $accessToken
    $results += $res
    if ($res.operationLoc) {
        $final = Poll-Operation -OperationLocation $res.operationLoc -AccessToken $accessToken -TimeoutSeconds $PollSeconds -IntervalSeconds $PollIntervalSeconds
        if ($final) { $res | Add-Member -NotePropertyName finalStatus -NotePropertyValue $final.status }
    }
}

Write-Host "\n=== Summary ===" -ForegroundColor Green
$results | Select-Object action,apiVersion,variant,status,finalStatus,correlationId,errorCode,@{n='message';e={($_.message -replace "\r|\n"," ")}} | Format-Table -AutoSize

Write-Host "\nCorrelation IDs (save for support if needed):" -ForegroundColor Yellow
$results | Where-Object { $_.correlationId } | Select-Object -ExpandProperty correlationId | Sort-Object -Unique | ForEach-Object { Write-Host $_ }

if (-not $Matrix -and $results[0].status -ne 202 -and $results[0].status -ne 200) {
    Write-Host "Hint: Use -Matrix for exhaustive variant testing." -ForegroundColor Yellow
}
