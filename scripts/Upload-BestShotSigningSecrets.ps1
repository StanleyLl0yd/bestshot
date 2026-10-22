#Requires -Version 7.0
<#
 BestShot: upload a local Android signing key into main-only GitHub
 Environment Secrets. The keystore is never committed or sent to chat.
 Requires PowerShell 7+, GitHub CLI, and repository admin access.
#>
[CmdletBinding()]
param(
    [string]$KeystorePath
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$repo = 'StanleyLl0yd/bestshot'
$environment = 'bestshot-android-signing'
$gh = (Get-Command gh -ErrorAction Stop).Source
$secretNames = @(
    'BESTSHOT_ANDROID_KEYSTORE_BASE64'
    'BESTSHOT_ANDROID_STORE_PASSWORD'
    'BESTSHOT_ANDROID_KEY_ALIAS'
    'BESTSHOT_ANDROID_KEY_PASSWORD'
)

function Select-BestShotKeystore {
    param([string]$RequestedPath)

    if (-not [string]::IsNullOrWhiteSpace($RequestedPath)) {
        $cleanPath = $RequestedPath.Trim().Trim('"')
        $chosen = Get-Item -LiteralPath $cleanPath -ErrorAction Stop
        if ($chosen -isnot [IO.FileInfo]) { throw 'The supplied keystore path is not a file.' }
        if ($chosen.Extension -notin @('.jks', '.keystore', '.p12', '.pfx')) {
            throw 'Expected a .jks, .keystore, .p12 or .pfx file.'
        }
        return $chosen
    }

    # Search next to this script and in Downloads (including when they are identical).
    $folders = @($PSScriptRoot, (Join-Path $HOME 'Downloads')) |
        Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Container) } |
        Select-Object -Unique
    $found = @(
        foreach ($folder in $folders) {
            Get-ChildItem -LiteralPath $folder -File -ErrorAction Stop |
                Where-Object { $_.Extension -in @('.jks', '.keystore', '.p12', '.pfx') }
        }
    )
    $found = @($found | Sort-Object -Property FullName -Unique)

    if ($found.Count -eq 1) {
        Write-Host ('Found keystore automatically: ' + $found[0].Name)
        return $found[0]
    }

    if ($found.Count -gt 1) {
        Write-Host 'Multiple signing keystores found:'
        for ($i = 0; $i -lt $found.Count; $i++) {
            Write-Host ('  {0}. {1}' -f ($i + 1), $found[$i].FullName)
        }
        while ($true) {
            $answer = Read-Host ('Select keystore number (1-{0})' -f $found.Count)
            $number = 0
            if ([int]::TryParse($answer, [ref]$number) -and $number -ge 1 -and $number -le $found.Count) {
                return $found[$number - 1]
            }
            Write-Warning 'Enter a number from the list.'
        }
    }

    Write-Warning 'No .jks/.keystore/.p12/.pfx files found beside the script or in Downloads.'
    $entered = Read-Host 'Full path to the signing keystore'
    if ([string]::IsNullOrWhiteSpace($entered)) {
        throw 'No keystore selected. No signing secret was uploaded.'
    }
    return (Select-BestShotKeystore -RequestedPath $entered)
}

function Set-BestShotSecret {
    param([string]$Name, [string]$Value)
    if ([string]::IsNullOrEmpty($Value)) { throw "Empty value for $Name" }

    # gh CLI encrypts the secret before uploading. Pass the value via STDIN,
    # never via command-line arguments, temporary files, or PowerShell history.
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $gh
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    foreach ($argument in @('secret', 'set', $Name, '-R', $repo, '-e', $environment)) {
        $psi.ArgumentList.Add($argument)
    }
    $process = [System.Diagnostics.Process]::Start($psi)
    if ($null -eq $process) { throw 'Could not launch gh secret set.' }
    try {
        $process.StandardInput.Write($Value)
        $process.StandardInput.Close()
        $process.WaitForExit()
        if ($process.ExitCode -ne 0) { throw "Failed to save $Name." }
    } finally {
        $process.Dispose()
    }
}

function Set-BestShotSecureSecret {
    param([string]$Name, [System.Security.SecureString]$SecureValue)

    if ($null -eq $SecureValue -or $SecureValue.Length -eq 0) {
        throw "Empty password for $Name."
    }
    $ptr = [IntPtr]::Zero
    $plain = $null
    try {
        $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureValue)
        $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
        Set-BestShotSecret -Name $Name -Value $plain
    } finally {
        $plain = $null
        if ($ptr -ne [IntPtr]::Zero) {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
        }
    }
}

Write-Host 'BestShot: local Android signing-key setup.'
Write-Host 'Do not send the key, alias password, or keystore password in chat.'
& $gh auth status
if ($LASTEXITCODE -ne 0) { throw 'Please run gh auth login first.' }

$selected = Select-BestShotKeystore -RequestedPath $KeystorePath
if ($selected.Length -le 0) { throw 'Selected keystore is empty.' }
if ([math]::Ceiling($selected.Length / 3) * 4 -gt 48000) {
    throw 'Keystore exceeds GitHub Secret size limit after Base64 encoding.'
}
Write-Host ('Selected: {0} ({1} bytes)' -f $selected.FullName, $selected.Length)

# Fail closed: configure/verify the allowed branch before accepting secrets.
$endpoint = "repos/$repo/environments/$environment"
$null = & $gh api $endpoint 2>$null
if ($LASTEXITCODE -ne 0) {
    & $gh api --method PUT $endpoint -F 'wait_timer=0' -F 'deployment_branch_policy[protected_branches]=false' -F 'deployment_branch_policy[custom_branch_policies]=true' --silent
    if ($LASTEXITCODE -ne 0) { throw 'Cannot create restricted signing environment.' }
}
$envInfo = (& $gh api $endpoint) | ConvertFrom-Json
if ($LASTEXITCODE -ne 0 -or -not $envInfo.deployment_branch_policy.custom_branch_policies) {
    throw 'The signing environment does not enforce custom branch restrictions.'
}
$policyEndpoint = "$endpoint/deployment-branch-policies"
$policies = (& $gh api ($policyEndpoint + '?per_page=100')) | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) { throw 'Cannot read deployment branch policies.' }
if ($policies.total_count -eq 0) {
    & $gh api --method POST $policyEndpoint -f name=main -f type=branch --silent
    if ($LASTEXITCODE -ne 0) { throw 'Cannot restrict the environment to main.' }
}
$policies = (& $gh api ($policyEndpoint + '?per_page=100')) | ConvertFrom-Json
if ($LASTEXITCODE -ne 0 -or $policies.total_count -ne 1 -or
    $policies.branch_policies[0].name -cne 'main' -or
    $policies.branch_policies[0].type -ne 'branch') {
    throw 'Signing environment must permit exactly the main branch.'
}
Write-Host 'GitHub signing environment restricted to main: OK.'

$alias = (Read-Host 'Signing key alias (for example, key0)').Trim()
if ([string]::IsNullOrWhiteSpace($alias)) {
    throw 'Key alias is empty. Nothing was uploaded.'
}
$storePassword = Read-Host 'Keystore password' -AsSecureString
if ($null -eq $storePassword -or $storePassword.Length -eq 0) {
    throw 'Keystore password is empty. Nothing was uploaded.'
}
$keyPassword = $null
$reuseStorePassword = $false
try {
    $keyPassword = Read-Host 'Key password (Enter = same as keystore password)' -AsSecureString
    if ($null -eq $keyPassword -or $keyPassword.Length -eq 0) {
        if ($null -ne $keyPassword) { $keyPassword.Dispose() }
        $keyPassword = $storePassword
        $reuseStorePassword = $true
        Write-Host 'Using the keystore password for the key.'
    }

    # Gather and validate all inputs first. Only then start secret uploads.
    $bytes = [IO.File]::ReadAllBytes($selected.FullName)
    $base64 = $null
    try {
        $base64 = [Convert]::ToBase64String($bytes)
        if ($base64.Length -gt 48000) { throw 'Encoded key exceeds GitHub Secret limit.' }
        Set-BestShotSecret -Name 'BESTSHOT_ANDROID_KEYSTORE_BASE64' -Value $base64
    } finally {
        [Array]::Clear($bytes, 0, $bytes.Length)
        $bytes = $null
        $base64 = $null
    }
    Set-BestShotSecureSecret -Name 'BESTSHOT_ANDROID_STORE_PASSWORD' -SecureValue $storePassword
    Set-BestShotSecret -Name 'BESTSHOT_ANDROID_KEY_ALIAS' -Value $alias
    Set-BestShotSecureSecret -Name 'BESTSHOT_ANDROID_KEY_PASSWORD' -SecureValue $keyPassword
} finally {
    if ($null -ne $keyPassword -and -not $reuseStorePassword) {
        $keyPassword.Dispose()
    }
    if ($null -ne $storePassword) { $storePassword.Dispose() }
    $alias = $null
}

$registered = @(& $gh secret list -R $repo -e $environment --json name --jq '.[].name')
if ($LASTEXITCODE -ne 0) { throw 'Could not check environment secret names.' }
foreach ($name in $secretNames) {
    if ($registered -notcontains $name) { throw "Secret $name is missing after upload." }
}

# Never leave older repository-wide secrets accessible to normal workflows.
$old = @(& $gh secret list -R $repo --json name --jq '.[].name')
if ($LASTEXITCODE -ne 0) { throw 'Could not inspect repository-level secret names.' }
foreach ($name in $secretNames) {
    if ($old -contains $name) {
        & $gh secret delete $name -R $repo
        if ($LASTEXITCODE -ne 0) { throw "Could not delete old repository-scoped secret $name." }
    }
}

Write-Host 'SUCCESS: all 4 BestShot signing secrets are present in the main-only environment.'
Write-Host 'Keep an independent encrypted backup of the keystore, alias and passwords.'
Write-Host 'After signed-build workflow reaches main, run:'
Write-Host '  gh workflow run android-signed.yml -R StanleyLl0yd/bestshot --ref main'
