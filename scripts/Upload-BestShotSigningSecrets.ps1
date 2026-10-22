#Requires -Version 7.0
<#
 Locally uploads a keystore and credentials as GitHub Actions Secrets.
 No secret is printed, written to temporary files or passed in process arguments.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repo = 'StanleyLl0yd/bestshot'
$gh = (Get-Command gh -ErrorAction Stop).Source

function Set-BestShotSecret {
    param([string]$Name, [string]$Value)
    if ([string]::IsNullOrEmpty($Value)) { throw "Empty value for $Name" }
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $gh
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    foreach ($arg in @('secret','set',$Name,'-R',$repo)) {
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
& $gh secret list -R $repo
if ($LASTEXITCODE -ne 0) { throw 'Could not list registered secrets' }
Write-Host 'Done. Keep an encrypted offline backup of the original key and passwords.'
Write-Host 'Signing can be run manually on main after the PR has passed review.'
