<#
.SYNOPSIS
    Toggles Windows Safe Mode on the next boot based on environment variable state.

.DESCRIPTION
    This script cycles between Safe Mode Minimal, Safe Mode with Networking, 
    Safe Mode with Command Prompt, and Normal boot using a machine-level 
    environment variable 'SAFEBOOT_MODE'. After changing the boot configuration, 
    it automatically restarts the system.

.NOTES
    Author: SAN
    Date: 25.02.26
    #public
    
.EXEMPLE
    SAFEBOOT_MODE=MINIMAL
    SAFEBOOT_MODE=NETWORK
    SAFEBOOT_MODE=CMD
    SAFEBOOT_MODE=NORMAL

.CHANGELOG
    
#>


$toggleVar = "SAFEBOOT_MODE"
$currentMode = $env:SAFEBOOT_MODE

switch ($currentMode) {

    "MINIMAL" {
        Write-Host "Switching to Safe Mode with Networking..."
        bcdedit /set {current} safeboot network | Out-Null
        bcdedit /deletevalue {current} safebootalternateshell 2>$null | Out-Null
        [Environment]::SetEnvironmentVariable($toggleVar, "NETWORK", "Machine")
    }

    "NETWORK" {
        Write-Host "Switching to Safe Mode with Command Prompt..."
        bcdedit /set {current} safeboot minimal | Out-Null
        bcdedit /set {current} safebootalternateshell yes | Out-Null
        [Environment]::SetEnvironmentVariable($toggleVar, "CMD", "Machine")
    }

    "CMD" {
        Write-Host "Returning to Normal Boot..."
        bcdedit /deletevalue {current} safeboot 2>$null | Out-Null
        bcdedit /deletevalue {current} safebootalternateshell 2>$null | Out-Null
        [Environment]::SetEnvironmentVariable($toggleVar, "NORMAL", "Machine")
    }

    "NORMAL" {
        Write-Host "Switching to Safe Mode (Minimal)..."
        bcdedit /set {current} safeboot minimal | Out-Null
        [Environment]::SetEnvironmentVariable($toggleVar, "MINIMAL", "Machine")
    }

    Default {
        Write-Host "Unknown or unset mode. Returning to Normal Boot..."
        bcdedit /deletevalue {current} safeboot 2>$null | Out-Null
        bcdedit /deletevalue {current} safebootalternateshell 2>$null | Out-Null
        [Environment]::SetEnvironmentVariable($toggleVar, "NORMAL", "Machine")
    }
}

Start-Sleep -Seconds 2
Write-Host "Rebooting..."
Restart-Computer -Force