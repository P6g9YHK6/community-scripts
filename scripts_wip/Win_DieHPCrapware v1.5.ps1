<#
NOTES
    1.0 10/23/2024 silversword411 initial version
    1.1 1/3/2025 silversword411 Adding debug and kill Touchpoint analytics
    1.2 2/9/2025 silversword411 foldercreate and runasuser snippet
    1.3 2/9/2025 silversword411 added Remove-provisionedapp, added some apps, fixed Remove-App
    1.4 9/2/2025 silversword411 added HP enhanced Lighting
    1.5 1/9/2026 silversword411 expanded HP/Poly bloatware removal (HP Sure*, Notifications, Poly Lens/Camera), added targeted HP service disablement, and enhanced debug visibility for HP services

#>

param(
    [switch]$debug
)

{ { foldercreate } }
{ { runasuser } }

if ($debug) {
    $DebugPreference = "Continue"
}
else {
    $DebugPreference = "SilentlyContinue"
    $ErrorActionPreference = 'silentlycontinue'
}

$manufacturer = (Get-WmiObject -Class Win32_ComputerSystem).Manufacturer

if (-not ($manufacturer -like "*HP*" -or $manufacturer -like "*Hewlett-Packard*")) {
    Write-Output "Not an HP. Exiting."
    Write-Output "Manufacturer detected: $manufacturer"
    exit 0
}

Foldercreate -Paths "$env:ProgramData\TacticalRMM\temp"

### Uninstall functions

Function Remove-App-MSI-QN([String]$appName) {
    $appCheck = Get-ChildItem -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall, HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall | Get-ItemProperty | Where-Object { $_.DisplayName -eq $appName } | Select-Object -Property DisplayName, UninstallString
    if ($appCheck -ne $null) {
        Write-host "Uninstalling "$appCheck.DisplayName
        $uninst = $appCheck.UninstallString + " /qn /norestart"
        cmd /c $uninst
    }
    else {
        Write-Host "$appName is not installed on this computer"
    }
}

Function Remove-App-EXE-SILENT([String]$appName) {
    $appCheck = Get-ChildItem -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall, HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall | Get-ItemProperty | Where-Object { $_.DisplayName -eq $appName } | Select-Object -Property DisplayName, UninstallString
    if ($appCheck -ne $null) {
        Write-host "Uninstalling "$appCheck.DisplayName
        $uninst = $appCheck.UninstallString + " -silent"
        cmd /c $uninst
    }
    else {
        Write-Host "$appName is not installed on this computer"
    }
}

Function Remove-App-MSI_EXE-Quiet([String]$appName) {
    $appCheck = Get-ChildItem -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall, HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall | Get-ItemProperty | Where-Object { $_.DisplayName -eq $appName } | Select-Object -Property DisplayName, UninstallString
    if ($appCheck -ne $null) {
        Write-host "Uninstalling "$appCheck.DisplayName
        $uninst = $appCheck.UninstallString[1] + " /qn /restart"
        cmd /c $uninst

    }
    else {
        Write-Host "$appName is not installed on this computer"
    }
}
Function Remove-App-MSI_EXE-S([String]$appName) {
    $appCheck = Get-ChildItem -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall, HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall | Get-ItemProperty | Where-Object { $_.DisplayName -eq $appName } | Select-Object -Property DisplayName, UninstallString
    if ($appCheck -ne $null) {
        Write-host "Uninstalling "$appCheck.DisplayName
        $uninst = $appCheck.UninstallString[1] + " /S"
        cmd /c $uninst

    }
    else {
        Write-Host "$appName is not installed on this computer"
    }
}

Function Remove-App-MSI-I-QN([String]$appName) {
    $appCheck = Get-ChildItem -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall, HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall | Get-ItemProperty | Where-Object { $_.DisplayName -eq $appName } | Select-Object -Property DisplayName, UninstallString
    if ($appCheck -ne $null) {
        Write-host "Uninstalling "$appCheck.DisplayName
        $uninst = $appCheck.UninstallString.Replace("/I", "/X") + " /qn /norestart"
        cmd /c $uninst
    }
    else {
        Write-Host "$appName is not installed on this computer"
    }
}


Function Remove-App([String]$appName) {
    $app = Get-AppxPackage -AllUsers | Where-Object { $_.Name -like $appName }
    if ($app) {
        foreach ($package in $app) {
            Write-Host "Uninstalling $($package.Name)"
            Remove-AppxPackage -Package $package.PackageFullName -AllUsers
        }
        $provApp = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like $appName }
        if ($provApp) {
            foreach ($proPackage in $provApp) {
                Write-Host "Uninstalling provisioned $($proPackage.DisplayName)"
                Remove-AppxProvisionedPackage -Online -PackageName $proPackage.PackageName -AllUsers
            }
        }
    }
    else {
        Write-Host "$appName is not installed on this computer"
    }
}

Function Remove-ProvisionedApp([String]$appName) {
    $provApp = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like $appName }
    if ($provApp) {
        foreach ($proPackage in $provApp) {
            Write-Host "Removing provisioned package: $($proPackage.DisplayName)"
            Remove-AppxProvisionedPackage -Online -PackageName $proPackage.PackageName -ErrorAction SilentlyContinue
        }
    }
    else {
        Write-Host "$appName is not provisioned on this computer"
    }
}


Function Check-UninstallString([String]$appName) {
    $appCheck = Get-ChildItem -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall, HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall | Get-ItemProperty | Where-Object { $_.DisplayName -eq $appName } | Select-Object -Property DisplayName, UninstallString
    if ($appCheck -ne $null) {
        Write-host $appCheck.DisplayName $appCheck.UninstallString
    }
    else {
        Write-Host "$appName is not installed on this computer"
    }
}

Function Remove-App-EXE-S-QUOTES([String]$appName) {
    $appCheck = Get-ChildItem -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall, HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall | Get-ItemProperty | Where-Object { $_.DisplayName -eq $appName } | Select-Object -Property DisplayName, UninstallString
    if ($appCheck -ne $null) {
        Write-host "Uninstalling "$appCheck.DisplayName
        $uninst = "`"" + $appCheck.UninstallString + "`"" + " /S"
        cmd /c $uninst
    }
    else {
        Write-Host "$appName is not installed on this computer"
    }
}

Function Remove-App-MSI-ByName-QN([string]$appName) {
    $appCheck = Get-ChildItem -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall, HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall |
    Get-ItemProperty |
    Where-Object { $_.DisplayName -eq $appName } |
    Select-Object -First 1 -Property DisplayName, UninstallString

    if (-not $appCheck) {
        Write-Host "$appName is not installed on this computer"
        return
    }

    $u = $appCheck.UninstallString
    if ($u -is [array]) { $u = $u | Select-Object -First 1 }

    # Pull the product code out of the uninstall string
    if ($u -match '\{[0-9A-Fa-f\-]{36}\}') {
        $guid = $matches[0]
        Write-Host "Uninstalling $($appCheck.DisplayName) ($guid)"
        Start-Process -FilePath "msiexec.exe" -ArgumentList "/x$guid /qn /norestart" -Wait
    }
    else {
        Write-Host "Uninstall string for $($appCheck.DisplayName) does not look like an MSI GUID: $u"
    }
}


Remove-App "*McAfeeWPSSparsePackage"
Remove-App "AD2F1837.myHP"
Remove-App "AD2F1837.HPSystemEventUtility"
Remove-App "AD2F1837.OMENCommandCenter"
Remove-App "AD2F1837.HPSystemInformation"
Remove-App "C27EB4BA.DropboxOEM"
Remove-App "PricelinePartnerNetwork*"
Remove-App "*McAfeeSecurity"
Remove-App "*HPJumpStarts"
Remove-App "*HPInc.EnergyStar"
Remove-App "*HPPrivacySettings"
Remove-ProvisionedApp "*Dropbox*"
Remove-ProvisionedApp "*HPPrinterControl"
Remove-ProvisionedApp "*HPPrivacySettings"
Remove-ProvisionedApp "*HPSupportAssistant"
Remove-App "AD2F1837.HPEnhance"
Remove-ProvisionedApp "AD2F1837.HPEnhance"
Remove-App-MSI-ByName-QN "HP Sure Recover"
Remove-App-MSI-QN "HP Sure Run Module"
Remove-App-MSI-QN "HP Notifications"
Remove-App-MSI-QN "Poly Lens Desktop"
Remove-App-MSI-I-QN "Poly Lens Control Service"
Remove-App-MSI-QN "Poly Camera Pro Compatibility Add-on"

## Manually Kill services

# HP Services Scan
Stop-Service -Name "hpsvcsscan" -ErrorAction SilentlyContinue
Set-Service  -Name "hpsvcsscan" -StartupType Disabled -ErrorAction SilentlyContinue

# HP SFU Service
Stop-Service -Name "SFUService" -ErrorAction SilentlyContinue
Set-Service  -Name "SFUService" -StartupType Disabled -ErrorAction SilentlyContinue

# Optional: HP Audio Analytics
Stop-Service -Name "HPAudioAnalytics" -ErrorAction SilentlyContinue
Set-Service  -Name "HPAudioAnalytics" -StartupType Disabled -ErrorAction SilentlyContinue

# Optional: HP Hotkey UWP
Stop-Service -Name "HotKeyServiceUWP" -ErrorAction SilentlyContinue
Set-Service  -Name "HotKeyServiceUWP" -StartupType Disabled -ErrorAction SilentlyContinue

# Optional: HP LAN/WLAN/WWAN Switching
Stop-Service -Name "LanWlanWwanSwitchingServiceUWP" -ErrorAction SilentlyContinue
Set-Service  -Name "LanWlanWwanSwitchingServiceUWP" -StartupType Disabled -ErrorAction SilentlyContinue


## Remove via AppX SYSTEM
$Bloatware = @(
    # Unnecessary Windows 10 AppX Apps
    #"*DellInc.DellCustomerConnect"
)

foreach ($Bloat in $Bloatware) {
    Get-AppxPackage -Name $Bloat | Remove-AppxPackage
    # This is system wide provisioned packages
    Get-AppxProvisionedPackage -Online | Where-Object DisplayName -like $Bloat | Remove-AppxProvisionedPackage -Online
    Write-Output "Trying to remove $Bloat."
}

# Kill TouchpointAnalytics
Stop-Service -Name "HpTouchpointAnalyticsService"
Set-Service -Name "HpTouchpointAnalyticsService" -StartupType Disabled
#Remove-Service -Name "HpTouchpointAnalyticsService"
& sc.exe delete "HpTouchpointAnalyticsService"
Remove-Item -Path "C:\ProgramData\HP\HP Touchpoint Analytics Client\" -Recurse -Force
Remove-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{E5FB98E0-0784-44F0-8CEC-95CD4690C43F}" -Recurse

if ($Debug) {
    Write-Output "***************** Debugging info *****************"    
    Write-Output "List of User apps from system"
    Get-AppxPackage | Sort-Object -Property Name | 
    Format-Table Name, @{Label = "Publisher"; Expression = { $_.Publisher.Substring(0, [Math]::Min(20, $_.Publisher.Length)) } }

    Write-Output "List of System apps"
    Get-AppxProvisionedPackage -Online | Sort-Object -Property DisplayName | 
    Format-Table DisplayName, @{Label = "Publisher"; Expression = { $_.Publisher.Substring(0, [Math]::Min(20, $_.Publisher.Length)) } }

    # Define registry paths to check for installed programs
    $registryPaths = @(
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )

    # Collect installed programs and their uninstall strings
    $installedPrograms = foreach ($path in $registryPaths) {
        Get-ItemProperty -Path $path |
        Where-Object { $_.DisplayName -and $_.UninstallString } |
        ForEach-Object {
            "Display Name: $($_.DisplayName)"
            "Uninstall String: $($_.UninstallString)"
            ""
        }
    }

    # Display the list
    $installedPrograms

    # -------- HP Services dump (for deciding what to clean up) --------
    Write-Output ""
    Write-Output "================ HP SERVICES (Debug) ================"

    Get-Service |
    Where-Object {
        $_.Name -match '(?i)^hp|hp' -or
        $_.DisplayName -match '(?i)^hp|hp'
    } |
    Sort-Object DisplayName |
    ForEach-Object {
        $svc = $_
        $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$($svc.Name)"
        $imagePath = (Get-ItemProperty $regPath -ErrorAction SilentlyContinue).ImagePath

        [PSCustomObject]@{
            Name        = $svc.Name
            DisplayName = $svc.DisplayName
            Status      = $svc.Status
            StartType   = $svc.StartType
            ImagePath   = $imagePath
        }
    } |
    Out-String -Width 4096 |
    Write-Output

}
