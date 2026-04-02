<#
NOTES
    v1.0 2/26/2025 silversword411 initial version
    v1.1 2/28/2025 silversword411 adding driver removers
    v1.2 5/14/2025 silversword411 Made driver removers a function and test param
    v1.3 7/3/2025 silversword411 adding Universal Device Client Service, Lenovo Fn and function keys service, Lenovo Notebook ITS Service
    v1.4 8/5/2025 silversword411 trackpoint menu
#>

param(
    [switch]$debug,
    [switch]$pnpTest
)

{ { foldercreate } }

if ($debug) {
    $DebugPreference = "Continue"
}
else {
    $DebugPreference = "SilentlyContinue"
    $ErrorActionPreference = 'silentlycontinue'
}

if (-not ((Get-WmiObject -Class Win32_ComputerSystem).Manufacturer -like "*Lenovo*")) {
    Write-Output "Not a Lenovo. Exiting."
    exit 0
}

Foldercreate -Paths "$env:ProgramData\TacticalRMM\temp"

### Uninstall functions


Function Remove-App-MSI-QN([String]$appName) {
    $appCheck = Get-ChildItem -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall, `
        HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall |
    Get-ItemProperty | Where-Object { $_.DisplayName -eq $appName } |
    Select-Object -Property DisplayName, UninstallString

    if ($appCheck) {
        Write-Host "Uninstalling $($appCheck.DisplayName)"
        $uninstallCommand = $appCheck.UninstallString -replace "/I", "/X"
        $uninstallCommand += " /quiet /norestart"

        try {
            Start-Process -FilePath "cmd.exe" -ArgumentList "/c $uninstallCommand" -Wait
            Write-Host "$($appCheck.DisplayName) uninstalled successfully."
        }
        catch {
            Write-Error "Failed to uninstall $($appCheck.DisplayName). Error: $_"
        }
    }
    else {
        Write-Host "$appName is not installed on this computer."
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
            $packageFullName = $package.PackageFullName
            Write-Host "Uninstalling $appName ($packageFullName)"
            Remove-AppxPackage -Package $packageFullName -AllUsers
        }
        
        $provApp = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like $appName }
        if ($provApp) {
            foreach ($provisionedPackage in $provApp) {
                $proPackageFullName = $provisionedPackage.PackageName
                Write-Host "Uninstalling provisioned $appName ($proPackageFullName)"
                Remove-AppxProvisionedPackage -Online -PackageName $proPackageFullName
            }
        }
    }
    else {
        Write-Host "$appName is not installed on this computer"
    }
}


Function Remove-System-App([String]$appName) {
    # Remove installed appx packages for all users
    $appMatches = Get-AppxPackage -AllUsers | Where-Object { $_.Name -like $appName }
    if ($appMatches) {
        foreach ($app in $appMatches) {
            $packageFullName = $app.PackageFullName
            Write-Host "Uninstalling installed system app: $appName ($packageFullName)"
            try {
                Remove-AppxPackage -Package $packageFullName -AllUsers
            }
            catch {
                Write-Error "Failed to remove installed package: $packageFullName. Error: $_"
            }
        }
    }
    else {
        Write-Host "$appName is not installed for any user."
    }

    # Remove provisioned appx packages
    $provAppMatches = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like $appName }
    if ($provAppMatches) {
        foreach ($provApp in $provAppMatches) {
            $provPackageFullName = $provApp.PackageName
            Write-Host "Uninstalling provisioned system app: $appName ($provPackageFullName)"
            try {
                Remove-AppxProvisionedPackage -Online -PackageName $provPackageFullName
            }
            catch {
                Write-Error "Failed to remove provisioned package: $provPackageFullName. Error: $_"
            }
        }
    }
    else {
        Write-Host "$appName is not provisioned on this computer."
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


Function Debug-AppInfo([String]$appName) {
    Write-Host "DEBUG: Checking for app: $appName"

    # Check installed AppxPackage for all users
    $appMatches = Get-AppxPackage -AllUsers | Where-Object { $_.Name -like $appName }
    if ($appMatches) {
        Write-Host "Installed AppxPackages found:"
        $appMatches | Format-Table -Property Name, PackageFullName, Publisher
    }
    else {
        Write-Host "No installed AppxPackages found matching: $appName"
    }

    # Check provisioned packages
    $provAppMatches = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like $appName }
    if ($provAppMatches) {
        Write-Host "Provisioned AppxPackages found:"
        $provAppMatches | Format-Table -Property DisplayName, PackageName
    }
    else {
        Write-Host "No provisioned AppxPackages found matching: $appName"
    }

    # Check MSI/EXE installations in registry
    $appCheck = Get-ChildItem -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall, `
        HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall |
    Get-ItemProperty | Where-Object { $_.DisplayName -like "*$appName*" }
    if ($appCheck) {
        Write-Host "MSI/EXE installations found in registry:"
        $appCheck | Format-Table -Property DisplayName, UninstallString
    }
    else {
        Write-Host "No MSI/EXE installations found in registry matching: $appName"
    }
}

Remove-App "*LenovoCompanion*"
#Remove-AppxProvisionedPackage -Online -PackageName "*LenovoCompanion*"
Remove-App "*LenovoUtility*"
Remove-App "E0469640.TrackPointQuickMenu"
Remove-App "MirametrixInc.GlancebyMirametrix"
Remove-App "*LenovoSmartCommunication"

#Get-Service -Name ImControllerService
$lenovoNowUninstaller = "C:\Program Files (x86)\Lenovo\LenovoNow\unins000.exe"
if (Test-Path $lenovoNowUninstaller) {
    Start-Process -FilePath $lenovoNowUninstaller -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART" -Wait -NoNewWindow
}
else {
    Write-Host "Lenovo Now uninstaller not found at $lenovoNowUninstaller"
}

$lenovoSmartMeetingUninstaller = "C:\Program Files\Lenovo\Lenovo Smart Meeting Components\unins000.exe"
if (Test-Path $lenovoSmartMeetingUninstaller) {
    Start-Process -FilePath $lenovoSmartMeetingUninstaller -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART" -Wait -NoNewWindow
}
else {
    Write-Host "Lenovo Smart Meeting Components uninstaller not found at $lenovoSmartMeetingUninstaller"
}

<#
# https://pcsupport.lenovo.com/us/en/products/desktops-and-all-in-ones/thinkcentre-m-series-desktops/thinkcentre-m90/solutions/ht513363
# pnputil /enum-drivers >c:\driver.log
pnputil /delete-driver oem0.inf /uninstall
pnputil /delete-driver oem51.inf /uninstall
pnputil /delete-driver oem61.inf /uninstall
pnputil /delete-driver oem49.inf /uninstall
pnputil /delete-driver oem1.inf /uninstall
pnputil /delete-driver oem53.inf /uninstall
pnputil /delete-driver oem54.inf /uninstall
pnputil /delete-driver oem50.inf /uninstall
pnputil /delete-driver oem57.inf /uninstall
pnputil /delete-driver oem41.inf /uninstall
#>

# Disable Lenovo Notebook ITS Service
Stop-Service -Name LITSSVC -Force
Set-Service -Name LITSSVC -StartupType Disabled

# Disable Lenovo Fn and function keys service
# Disable Lenovo Fn and function keys service
$serviceName = "LenovoFnAndFunctionKeys"
$service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

if ($service) {
    if ($service.Status -eq "Running") {
        Write-Host "Stopping $serviceName service..."
        Stop-Service -Name $serviceName -Force
    }
    Write-Host "Disabling $serviceName service..."
    Set-Service -Name $serviceName -StartupType Disabled
}
else {
    Write-Host "$serviceName service not found."
}

# UDCService Universal Device Client Service
Stop-Service -Name UDCService -Force
Set-Service -Name UDCService -StartupType Disabled

# YMC Lenovo Yoga Mode Control
#Stop-Service -Name YMC -Force
#Set-Service -Name YMC -StartupType Disabled


Function Remove-LenovoPnPDrivers {
    param (
        [switch]$pnpTest
    )

    if ($pnpTest) {
        Write-Output "[DEBUG] pnpTest switch is enabled"
    }
    else {
        Write-Output "[DEBUG] pnpTest switch is NOT enabled"
    }

    $pnputilOutput = pnputil /enum-drivers 2>&1

    # Parse into driver blocks by detecting "Published Name:" as start of each
    $driverBlocks = @()
    $currentBlock = @()

    foreach ($line in $pnputilOutput) {
        if ($line -match "^Published Name:\s+") {
            if ($currentBlock.Count -gt 0) {
                $driverBlocks += , ($currentBlock -join "`n")
                $currentBlock = @()
            }
        }
        $currentBlock += $line
    }

    if ($currentBlock.Count -gt 0) {
        $driverBlocks += , ($currentBlock -join "`n")
    }

    $lenovoDrivers = @()

    foreach ($block in $driverBlocks) {
        if ($pnpTest) {
            #Write-Output "`n[DEBUG] Raw Driver Block:"
            #Write-Output $block
        }

        $publishedName = if ($block -match "Published Name:\s+(oem\d+\.inf)") { $matches[1] } else { $null }
        $providerName = if ($block -match "Provider Name:\s+(.+)") { $matches[1].Trim() } else { $null }

        if ($publishedName -and $providerName -like "*Lenovo*") {
            $lenovoDrivers += $publishedName
        }
    }

    if (-not $lenovoDrivers) {
        Write-Output "No Lenovo drivers found."
        return
    }

    foreach ($inf in $lenovoDrivers) {
        if ($pnpTest) {
            Write-Output "Would remove: $inf"
        }
        else {
            Write-Output "Removing: $inf"
            #pnputil /delete-driver $inf /uninstall /force
        }
    }
}


Remove-LenovoPnPDrivers -pnpTest:$pnpTest


# Checks if ImControllerService exists, stops it if running, and disables startup.
Function Disable-ImControllerService {
    $service = Get-Service -Name ImControllerService -ErrorAction SilentlyContinue

    if ($null -eq $service) {
        Write-Host "ImControllerService not found on this system."
    }
    else {
        if ($service.Status -eq "Running") {
            Write-Host "ImControllerService is running. Stopping service..."
            Stop-Service -Name ImControllerService -Force
        }

        Write-Host "Disabling ImControllerService..."
        Set-Service -Name ImControllerService -StartupType Disabled
        Write-Host "ImControllerService has been stopped (if running) and disabled."
    }
}

# Example usage:
Disable-ImControllerService


#Debug-AppInfo "Dell Digital Delivery"

if ($debug) {
    Write-Output "***************** Debugging info *****************"
    
    Write-Output "`n==== Debug: All Uninstall Items (Wrapped Table) ===="
    Get-ItemProperty `
        HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*, `
        HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* `
        -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName } |
    Sort-Object DisplayName |
    Select-Object DisplayName, UninstallString, Publisher |
    Format-Table -AutoSize -Wrap


    Write-Output "`n==== List of User Apps (Appx) from System (-AllUsers) ===="
    Get-AppxPackage -AllUsers |
    Sort-Object -Property Name |
    Format-Table Name, 
    @{Label = "Publisher"; Expression = { $_.Publisher.Substring(0, [Math]::Min(20, $_.Publisher.Length)) } }

    Write-Output "`n==== List of System Apps (Provisioned) ===="
    Get-AppxProvisionedPackage -Online |
    Sort-Object -Property DisplayName |
    Format-Table DisplayName,
    @{Label = "Publisher"; Expression = { $_.Publisher.Substring(0, [Math]::Min(20, $_.Publisher.Length)) } }
}
