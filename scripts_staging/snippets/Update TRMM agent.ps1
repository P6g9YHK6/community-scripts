<#
.SYNOPSIS
    Downloads and installs the latest or specified version of the Tactical RMM agent.

.DESCRIPTION
    This script installs the Tactical RMM agent using either a signed or unsigned installer.

    - If the environment variable `trmm_sign_download_token` is present, a signed download is assumed automatically.
    - If no code signing token is provided, the unsigned installer is downloaded from GitHub.
    - The installer is downloaded to: C:\ProgramData\TacticalRMM\temp
    - The installer is launched in a detached execution context so it survives TRMM agent restarts.

    The code signing token is the one provided by amidaware and can be found in the code signing section of TRMM.

.PARAMETER version
    Version to install. Use "latest" or leave unset to auto-detect latest GitHub release.
    Provided via environment variable: version

.PARAMETER trmm_sign_download_token
    Signed download token (optional).
    Provided via environment variable: trmm_sign_download_token

.PARAMETER trmm_api_target
    API target for signed downloads (required if token is provided otherwise optional).
    Provided via environment variable: trmm_api_target

.EXAMPLE
    version=latest
    trmm_sign_download_token={{global.trmm_sign_download_token}}
    trmm_api_target={{global.RMM_API_URL}}

.NOTES
    Author: SAN
    Date: 29.10.24
    #public

.CHANGELOG
    29.10.24 SAN Initial script with signed and unsigned download support.
    21.12.24 SAN Removed explicit issigned requirement.
    22.12.24 SAN Default to latest when no version is set.
    15.01.26 Updated download path, token handling, and output sanitization.
#>


$version = $env:version
$signedDownloadToken = $env:trmm_sign_download_token
$apiTarget = $env:trmm_api_target
$repoUrl = "https://api.github.com/repos/amidaware/rmmagent/releases/latest"
$downloadDir = "C:\ProgramData\TacticalRMM\temp"
$outputFile = $null


if (-not (Test-Path $downloadDir)) {
    New-Item -Path $downloadDir -ItemType Directory -Force | Out-Null
}

function Get-InstalledVersion {
    $appName = "Tactical RMM Agent"

    $apps = Get-ItemProperty `
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" ,
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" `
        -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like "*$appName*" }

    return $apps.DisplayVersion
}

try {
    $headers = @{ "User-Agent" = "PowerShell Script" }

    if (-not $version) {
        $version = "latest"
    }

    if ($version -eq "latest") {
        Write-Output "Fetching latest Tactical RMM agent version..."
        $response = Invoke-RestMethod -Uri $repoUrl -Headers $headers -ErrorAction Stop
        $version = $response.tag_name.TrimStart('v')
        Write-Output "Latest version resolved: $version"
    } else {
        Write-Output "Requested version: $version"
    }

    $installedVersion = Get-InstalledVersion
    if ($installedVersion) {
        Write-Output "Installed version detected: $installedVersion"
        if ($installedVersion -eq $version) {
            Write-Output "Installed version matches requested version. Exiting."
            exit 0
        }
    } else {
        Write-Output "Tactical RMM Agent not currently installed."
    }

    $outputFile = Join-Path $downloadDir "tacticalagent-v$version.exe"

    if ($signedDownloadToken) {
        if (-not $apiTarget) {
            Write-Output "ERROR: trmm_api_target is required when using signed downloads."
            exit 1
        }

        Write-Output "Signed download detected."
        $downloadUrl = "https://agents.tacticalrmm.com/api/v2/agents?version=$version&arch=amd64&token=$signedDownloadToken&plat=windows&api=$apiTarget"
    } else {
        Write-Output "Unsigned download detected."
        $downloadUrl = "https://github.com/amidaware/rmmagent/releases/download/v$version/tacticalagent-v$version-windows-amd64.exe"
    }

    Write-Output "Downloading agent installer..."
    Invoke-WebRequest -Uri $downloadUrl -OutFile $outputFile -ErrorAction Stop
    Write-Output "Download completed successfully."

    Write-Output "Launching installer in detached context..."

    $processStartInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processStartInfo.FileName = $outputFile
    $processStartInfo.Arguments = "/VERYSILENT"
    $processStartInfo.UseShellExecute = $true
    $processStartInfo.CreateNoWindow = $true
    $processStartInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden

    [System.Diagnostics.Process]::Start($processStartInfo) | Out-Null

    Write-Output "Installer launched successfully. Exiting script."

} catch {
    Write-Output "Fatal error: $($_.Exception.Message)"
    exit 1
}
