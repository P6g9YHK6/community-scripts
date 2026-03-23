<#
NOTES
    v1.0 10/23/2024 silversword411 initial version
    v1.1 10/29/2024 silversword411 Adding old powerdirector apps
    v1.2 12/13/2024 silversword411 Removing system apps
    v1.3 1/29/2025 silversword411 DellInc.PartnerPromo, DellWatchdogTimer
    v1.4 2/9/2025 silversword411 foldercreate and runasuser snippet
    v1.5 2/17/2025 silversword411 added Dell Update universal

#>

param(
    [switch]$debug
)

{ { foldercreate } }

if ($debug) {
    $DebugPreference = "Continue"
}
else {
    $DebugPreference = "SilentlyContinue"
    $ErrorActionPreference = 'silentlycontinue'
}

if (-not ((Get-WmiObject -Class Win32_ComputerSystem).Manufacturer -like "*Dell*")) {
    Write-Output "Not a Dell. Exit"
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


Remove-App-MSI-I-QN "Dell Trusted Device Agent"
Remove-App-MSI-QN "Dell Update for Windows Universal"
Remove-App-EXE-S-QUOTES "Dell Pair"
Remove-App-MSI-QN "Dell SupportAssist"
Remove-App-MSI-QN "Dell Digital Delivery"
Remove-App-MSI_EXE-S "Dell SupportAssist Remediation"
Remove-App "DellInc.DellDigitalDelivery"
Remove-App "*DellInc.DellCustomerConnect"
Remove-App "*DellInc.PartnerPromo"
Remove-App "*DellWatchdogTimer"
#Remove-App "*DellInc.MyDell"
Remove-App "DellInc.DellUpdate"
Remove-App "DB6EA5DB.PowerMediaPlayerforDell"
Remove-App "DB6EA5DB.Power2GoforDell"
Remove-App "DB6EA5DB.PowerDirectorforDell"
Remove-App "DB6EA5DB.MediaSuiteEssentialsforDell"
Remove-App-MSI-QN "Dell Digital Delivery Services"
Remove-App-EXE-S-QUOTES "Dell Display Manager 2.2"
Remove-App-EXE-S-QUOTES "Dell Peripheral Manager"
Remove-App-MSI-I-QN "Dell Core Services"
# Remove-App-MSI-I-QN "Dell Optimizer" Doesn't work on EHILL2025
# Remove-App-EXE-S-QUOTES "MyDell" Doesn't work on EHILL2025 not a silent uninstaller and linked with Optimizer
Remove-System-App "5A894077.McAfeeSecurity"
Remove-System-App "DellInc.DellProductRegistration"
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
