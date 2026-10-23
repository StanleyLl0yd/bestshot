#Requires -Version 7.0
<#
 Download latest successful signed BestShot test candidate and verify SHA-256.
 The user signing keystore is never accessed.
#>
[CmdletBinding()]
param([string]$DestinationDirectory)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$repo = 'StanleyLl0yd/bestshot'
$gh = (Get-Command gh -ErrorAction Stop).Source

Write-Host '[INFO] BestShot signed Android APK/AAB downloader'
& $gh auth status
if ($LASTEXITCODE -ne 0) { throw 'Run gh auth login first.' }

$json = & $gh run list -R $repo --workflow android-signed.yml --branch main --limit 50 --json databaseId,headSha,status,conclusion
if ($LASTEXITCODE -ne 0) { throw 'Cannot read signed build history.' }
$runs = @(($json -join [Environment]::NewLine) | ConvertFrom-Json)
$chosen = $runs | Where-Object {
    $_.status -eq 'completed' -and $_.conclusion -eq 'success' -and
    $_.headSha -match '^[0-9a-fA-F]{40}$'
} | Select-Object -First 1
if ($null -eq $chosen) { throw 'No successful signed candidate was found.' }

$head = [string]$chosen.headSha
$runId = [string]$chosen.databaseId
$name = "bestshot-android-signed-$head"
if ([string]::IsNullOrWhiteSpace($DestinationDirectory)) {
    $DestinationDirectory = Join-Path (Join-Path $HOME 'Downloads') ("BestShot-" + $head.Substring(0, 8))
}
$destination = [IO.Path]::GetFullPath($DestinationDirectory)
if (Test-Path -LiteralPath $destination) {
    throw "Directory already exists: $destination. Specify a different -DestinationDirectory."
}
New-Item -ItemType Directory -Path $destination | Out-Null
Write-Host "[INFO] Actions run #$runId; commit $head"

try {
    & $gh run download $runId -R $repo --name $name --dir $destination
    if ($LASTEXITCODE -ne 0) { throw 'Could not download the signed artifact.' }

    $all = @(Get-ChildItem -LiteralPath $destination -File -Recurse)
    $apks = @($all | Where-Object Name -eq 'app-release.apk')
    $aabs = @($all | Where-Object Name -eq 'app-release.aab')
    $sums = @($all | Where-Object Name -eq 'SIGNED-SHA256SUMS.txt')
    if ($apks.Count -ne 1 -or $aabs.Count -ne 1 -or $sums.Count -ne 1) {
        throw 'Expected exactly one signed APK, AAB and SHA256 manifest.'
    }

    $entries = @{}
    foreach ($line in [IO.File]::ReadAllLines($sums[0].FullName)) {
        if ($line -notmatch '^([0-9a-fA-F]{64})\s+\*?(.+?)\s*$') {
            throw 'Malformed SHA256SUMS record.'
        }
        $key = $Matches[2].Replace('\', '/')
        if ($entries.ContainsKey($key)) { throw 'Duplicate SHA256 record.' }
        $entries[$key] = $Matches[1].ToLowerInvariant()
    }
    foreach ($pair in @(
        @{ Label = 'APK'; File = $apks[0]; Key = 'apk/release/app-release.apk' }
        @{ Label = 'AAB'; File = $aabs[0]; Key = 'bundle/release/app-release.aab' }
    )) {
        if (-not $entries.ContainsKey($pair.Key)) { throw "Missing $($pair.Label) checksum." }
        $actual = (Get-FileHash -LiteralPath $pair.File.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actual -cne $entries[$pair.Key]) {
            throw "$($pair.Label) checksum mismatch; do not install."
        }
        Write-Host "[VERIFIED] $($pair.Label): SHA-256 matches"
    }
    $certs = @($all | Where-Object Name -eq 'SIGNING-CERTIFICATE-SHA256.txt')
    if ($certs.Count -gt 1) { throw 'Multiple fingerprint reports.' }
    if ($certs.Count -eq 1) {
        $fingerprint = [IO.File]::ReadAllText($certs[0].FullName).Trim()
        if ($fingerprint -notmatch '^APK signing certificate SHA-256:\s*([0-9a-fA-F]{64})$') {
            throw 'Malformed public certificate fingerprint.'
        }
        Write-Host "[INFO] Public signing certificate SHA-256: $($Matches[1])"
    } else {
        Write-Warning 'The older candidate has no public certificate fingerprint report.'
    }
    Write-Host '[OK] Signed candidate checksums verified against GitHub Actions.'
    Write-Host ('[APK] ' + $apks[0].FullName)
    Write-Host ('[AAB] ' + $aabs[0].FullName)
    Write-Host '[INFO] Debug-signed app may need to be uninstalled before installing this candidate.'
    Write-Host '[INFO] Checksums do not independently prove signature authenticity; CI verified the APK/AAB signatures.'
} catch {
    Write-Warning 'Do not install files from this unverified or incomplete download.'
    throw
}
