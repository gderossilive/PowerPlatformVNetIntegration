param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [String]$environmentId,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [String]$policyArmId,

    [Parameter(Mandatory=$false)]
    [ValidateSet("tip1", "tip2", "prod")]
    [String]$endpoint
)

# Load thescript
. ".\scripts\common\EnvironmentEnterprisePolicyOperations.ps1"

function NewSubnetInjection {
    if (![bool]$endpoint) {
        $endpoint = "prod"
    }
    LinkPolicyToEnv -policyType vnet -environmentId $environmentId -policyArmId $policyArmId -endpoint $endpoint 
}

NewSubnetInjection