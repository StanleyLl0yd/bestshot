#Requires -Version 7.0
<#
 Locally uploads a keystore and credentials as GitHub Actions Secrets.
 No secret is printed, written to temporary files or passed in process arguments.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repo = 'StanleyLl0yd/bestshot'
$environment = 'bestshot-android-signing'
$gh = (Get-Command gh -ErrorAction Stop).Source

function Set-BestShotSecret {
    param([string]$Name, [string]$Value)
    if ([string]::IsNullOrEmpty($Value)) { throw "Empty value for $Name" }
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $gh
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    foreach ($arg in @('secret','set',$Name,'-R',$repo,'-e',$environment)) {
        $psi.ArgumentList.Add($arg)
    }
    $proc = [System.Diagnostics.Process]::Start($psi)
    if ($null -eq $proc) { throw 'Could not launch gh' }
    try {
        $proc.StandardInput.Write($Value)
        $proc.StandardInput.Close()
        $proc.WaitForExit()
        if ($proc.ExitCode -ne 0) { throw "GitHub CLI failed to set $Name" }
    } finally {
        $proc.Dispose()
    }
}

function Set-BestShotPassword {
    param([string]$Name, [string]$Prompt)
    $secure = Read-Host -Prompt $Prompt -AsSecureString
    $ptr = [IntPtr]::Zero
    $text = $null
    try {
        $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
        $text = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
        Set-BestShotSecret -Name $Name -Value $text
    } finally {
        $text = $null
        if ($ptr -ne [IntPtr]::Zero) {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
        }
        $secure.Dispose()
    }
}

Write-Host 'BestShot: securely register Android signing secrets.'
Write-Host 'Do not send a keystore or its passwords in chat.'
& $gh auth status
if ($LASTEXITCODE -ne 0) { throw 'First run: gh auth login' }

# Provision a main-only GitHub Environment before uploading a private key.
$endpoint = "repos/$repo/environments/$environment"
$existingEnvironment = & $gh api $endpoint 2>$null
if ($LASTEXITCODE -ne 0) {
    & $gh api --method PUT $endpoint -F 'wait_timer=0' -F 'deployment_branch_policy[protected_branches]=false' -F 'deployment_branch_policy[custom_branch_policies]=true' --silent
    if ($LASTEXITCODE -ne 0) { throw 'Cannot create restricted signing environment' }
}
$environmentInfo = (& $gh api $endpoint) | ConvertFrom-Json
if ($LASTEXITCODE -ne 0 -or -not $environmentInfo.deployment_branch_policy.custom_branch_policies) {
    throw 'Signing environment does not enforce branch restrictions'
}
$policyEndpoint = "$endpoint/deployment-branch-policies"
$allowedBranches = @(& $gh api $policyEndpoint --jq '.branch_policies[].name')
if ($LASTEXITCODE -ne 0) { throw 'Cannot read signing environment branch policy' }
if ($allowedBranches.Count -eq 0) {
    & $gh api --method POST $policyEndpoint -f name=main -f type=branch --silent
    if ($LASTEXITCODE -ne 0) { throw 'Cannot restrict signing environment to main' }
} elseif ($allowedBranches.Count -ne 1 -or $allowedBranches[0] -ne 'main') {
    throw 'Signing environment must allow only main'
}
$confirmedBranches = @(& $gh api $policyEndpoint --jq '.branch_policies[].name')
if ($LASTEXITCODE -ne 0 -or $confirmedBranches.Count -ne 1 -or $confirmedBranches[0] -ne 'main') {
    throw 'Signing environment branch-policy verification failed'
}
Write-Host 'Verified main-only GitHub signing environment.'

$enteredPath = (Read-Host 'Full path to local .jks, .keystore or .p12').Trim('"')
$filePath = (Resolve-Path -LiteralPath $enteredPath -ErrorAction Stop).Path
if (-not (Test-Path -LiteralPath $filePath -PathType Leaf)) {
    throw 'The keystore file is not readable'
}
$bytes = [IO.File]::ReadAllBytes($filePath)
$encoded = $null
try {
    $encoded = [Convert]::ToBase64String($bytes)
    if ($encoded.Length -gt 48000) { throw 'Encoded key exceeds GitHub Secret size limit' }
    Set-BestShotSecret -Name 'BESTSHOT_ANDROID_KEYSTORE_BASE64' -Value $encoded
} finally {
    [Array]::Clear($bytes, 0, $bytes.Length)
    $bytes = $null
    $encoded = $null
}

$alias = Read-Host 'Key alias inside keystore'
Set-BestShotSecret -Name 'BESTSHOT_ANDROID_KEY_ALIAS' -Value $alias
$alias = $null

Set-BestShotPassword -Name 'BESTSHOT_ANDROID_STORE_PASSWORD' -Prompt 'Keystore password'
Set-BestShotPassword -Name 'BESTSHOT_ANDROID_KEY_PASSWORD' -Prompt 'Key password (repeat if same)'

Write-Host 'Registered names only (secret values cannot be read back):'
& $gh secret list -R $repo -e $environment
if ($LASTEXITCODE -ne 0) { throw 'Could not list registered secrets' }
# Delete earlier repository-level copies after environment secrets are stored.
$names = @('BESTSHOT_ANDROID_KEYSTORE_BASE64', 'BESTSHOT_ANDROID_KEY_ALIAS',
    'BESTSHOT_ANDROID_STORE_PASSWORD', 'BESTSHOT_ANDROID_KEY_PASSWORD')
$oldSecrets = @(& $gh secret list -R $repo --json name --jq '.[].name')
if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect repository-scoped secret names' }
foreach ($name in $names) {
    if ($oldSecrets -contains $name) {
        & $gh secret delete $name -R $repo
        if ($LASTEXITCODE -ne 0) { throw "Could not remove old repository-scoped secret $name" }
    }
}
Write-Host 'Done. Keep an encrypted offline backup of the original key and passwords.'
Write-Host 'Signing can be run manually on main after the PR has passed review.'
