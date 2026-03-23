<#
NOTES
    1.0 10/23/2024 silversword411 initial version
    1.1 1/1/2025 silversword411 adding debug
    1.2 1/29/2025 silversword411 new Remove-App function to support array
    1.3 2/9/2025 silversword411 foldercreate and runasuser snippet
    1.4 2/9/2025 silversword411 adding DieMSAccountNags
    1.5 2/10/2025 Expand -debug section to list all software including registry-based, and updated Remove-M365 to handle wildcards
    1.6 2/17/2025 removing power automate
    1.7 5/7/2025 Added parameters to optionally leave Office, Teams, and OneDrive
    1.8 6/10/2025 Add Microsoft.Edge.GameAssist MicrosoftTeams Microsoft.ZuneVideo (Music & TV)
    1.9 8/5/2025 Start Experiences App
    1.10 11/19/2025 fixed onedrive removal
    1.11 12/16/2025 change leaveoffice to remove everything except en-us
    1.12 1/15/2026 – Fixed OneDrive removal when files are locked by Explorer by force-unloading OneDrive shell components, retrying deletion, and scheduling delete-on-reboot for stubborn per-user OneDrive binaries.
    
#>

param(
    [switch]$debug,
    [switch]$leaveoffice,
    [switch]$leaveteams,
    [switch]$leaveonedrive
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

Foldercreate -Paths "$env:ProgramData\TacticalRMM\temp"

### Uninstall functions
Function Remove-App-MSI-QN([String]$appName) {
    $appCheck = Get-ChildItem `
        -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall, `
        HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall `
    | Get-ItemProperty `
    | Where-Object { $_.DisplayName -eq $appName } `
    | Select-Object -Property DisplayName, UninstallString
    if ($appCheck -ne $null) {
        Write-host "Uninstalling $($appCheck.DisplayName)"
        $uninst = $appCheck.UninstallString + " /qn /norestart"
        cmd /c $uninst
    }
    else {
        Write-Host "$appName is not installed on this computer"
    }
}

Function Remove-App-EXE-SILENT([String]$appName) {
    $appCheck = Get-ChildItem `
        -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall, `
        HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall `
    | Get-ItemProperty `
    | Where-Object { $_.DisplayName -eq $appName } `
    | Select-Object -Property DisplayName, UninstallString
    if ($appCheck -ne $null) {
        Write-host "Uninstalling $($appCheck.DisplayName)"
        $uninst = $appCheck.UninstallString + " -silent"
        cmd /c $uninst
    }
    else {
        Write-Host "$appName is not installed on this computer"
    }
}

Function Remove-App-MSI_EXE-Quiet([String]$appName) {
    $appCheck = Get-ChildItem `
        -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall, `
        HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall `
    | Get-ItemProperty `
    | Where-Object { $_.DisplayName -eq $appName } `
    | Select-Object -Property DisplayName, UninstallString
    if ($appCheck -ne $null) {
        Write-host "Uninstalling $($appCheck.DisplayName)"
        $uninst = $appCheck.UninstallString[1] + " /qn /restart"
        cmd /c $uninst
    }
    else {
        Write-Host "$appName is not installed on this computer"
    }
}

Function Remove-App-MSI_EXE-S([String]$appName) {
    $appCheck = Get-ChildItem `
        -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall, `
        HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall `
    | Get-ItemProperty `
    | Where-Object { $_.DisplayName -eq $appName } `
    | Select-Object -Property DisplayName, UninstallString
    if ($appCheck -ne $null) {
        Write-host "Uninstalling $($appCheck.DisplayName)"
        $uninst = $appCheck.UninstallString[1] + " /S"
        cmd /c $uninst
    }
    else {
        Write-Host "$appName is not installed on this computer"
    }
}

Function Remove-App-MSI-I-QN([String]$appName) {
    $appCheck = Get-ChildItem `
        -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall, `
        HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall `
    | Get-ItemProperty `
    | Where-Object { $_.DisplayName -eq $appName } `
    | Select-Object -Property DisplayName, UninstallString
    if ($appCheck -ne $null) {
        Write-host "Uninstalling $($appCheck.DisplayName)"
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

Function Remove-M365 {
    param (
        [string]$appName
    )

    # Retrieve all matches (including 64-bit and 32-bit registry paths)
    $matches = Get-ItemProperty `
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' `
        -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -like $appName }

    if (-not $matches) {
        Write-Host "$appName is not installed on this computer"
        return
    }

    foreach ($m in $matches) {
        if ($m.UninstallString) {
            $uninstallString = $m.UninstallString + " DisplayLevel=False"
            Write-Host "Uninstalling '$($m.DisplayName)' with command: $uninstallString"
            cmd /c $uninstallString
        }
        else {
            Write-Host "No uninstall string found for '$($m.DisplayName)'"
        }
    }
}

Function Check-UninstallString([String]$appName) {
    $appCheck = Get-ChildItem `
        -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall, `
        HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall `
    | Get-ItemProperty `
    | Where-Object { $_.DisplayName -eq $appName } `
    | Select-Object -Property DisplayName, UninstallString
    if ($appCheck -ne $null) {
        Write-host "$($appCheck.DisplayName) $($appCheck.UninstallString)"
    }
    else {
        Write-Host "$appName is not installed on this computer"
    }
}

Function Remove-App-EXE-S-QUOTES([String]$appName) {
    $appCheck = Get-ChildItem `
        -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall, `
        HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall `
    | Get-ItemProperty `
    | Where-Object { $_.DisplayName -eq $appName } `
    | Select-Object -Property DisplayName, UninstallString
    if ($appCheck -ne $null) {
        Write-host "Uninstalling $($appCheck.DisplayName)"
        $uninst = "`"" + $appCheck.UninstallString + "`"" + " /S"
        cmd /c $uninst
    }
    else {
        Write-Host "$appName is not installed on this computer"
    }
}

function Remove-OfficeC2RLanguagesExceptEnUS {
    param(
        [string]$KeepCulture = 'en-us'
    )

    $keep = $KeepCulture.ToLowerInvariant()
    Write-Output "===== Office C2R language cleanup: keeping $keep, removing other cultures ====="

    $uninstallRoots = @(
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )

    $targets = Get-ItemProperty $uninstallRoots -ErrorAction SilentlyContinue |
    Where-Object {
        $_.DisplayName -match '^(Microsoft 365|Microsoft OneNote)\s-\s[a-z]{2}-[a-z]{2}$' -and
        $_.UninstallString -match '(?i)OfficeClickToRun\.exe'
    }

    if (-not $targets) {
        Write-Output "No Office C2R language entries found to remove."
        return
    }

    foreach ($t in $targets) {
        $name = $t.DisplayName

        # Culture from the DisplayName (most reliable in your case)
        $culture = ([regex]::Match($name, '([a-z]{2}-[a-z]{2})$')).Value.ToLowerInvariant()
        if (-not $culture) { continue }

        if ($culture -eq $keep) {
            Write-Output "Keeping: $name"
            continue
        }

        # Parse: "C:\Path\OfficeClickToRun.exe" <args...>
        $u = $t.UninstallString.Trim()
        $m = [regex]::Match($u, '^\s*"(?<exe>[^"]+)"\s*(?<args>.*)$')
        if (-not $m.Success) {
            Write-Output "Skipping (could not parse uninstall string): $name"
            continue
        }

        $exe = $m.Groups['exe'].Value
        $args = $m.Groups['args'].Value

        if (-not (Test-Path $exe)) {
            Write-Output "Skipping (OfficeClickToRun.exe not found): $exe"
            continue
        }

        # Add DisplayLevel=False if missing
        if ($args -notmatch '(?i)\bDisplayLevel=') {
            $args = "$args DisplayLevel=False"
        }

        Write-Output "Removing: $name"
        Write-Output "Start-Process `"$exe`" $args"

        try {
            $p = Start-Process -FilePath $exe -ArgumentList $args -Wait -PassThru -WindowStyle Hidden
            $exitcode = $p.ExitCode
            Write-Output "ExitCode for $name : $exitcode"
        }
        catch {
            Write-Output "FAILED removing $name : $($_.Exception.Message)"
        }
    }

    Write-Output "===== Office C2R language cleanup done. ====="
}



# Remove built-in apps
Remove-App "*AmazonAlexa*"
Remove-App "*BubbleWitch3Saga*"
Remove-App "*CandyCrush*"
Remove-App "*Facebook*"
Remove-App "*Flipboard*"
Remove-App "*linkedin*"
Remove-App "*PandoraMediaInc*"
Remove-App "*Royal Revolt*"
Remove-App "*Spotify*"
Remove-App "*Sway*"
Remove-App "*Twitter*"
Remove-App "*xbox*"
Remove-App "4DF9E0F8.Netflix"
Remove-App "king.com.*"
Remove-App "Microsoft.BingFinance"
Remove-App "Microsoft.BingFoodAndDrink"
Remove-App "Microsoft.BingHealthAndFitness"
Remove-App "Microsoft.BingSearch"
Remove-App "Microsoft.BingSports"
Remove-App "Microsoft.BingTravel"
Remove-App "Microsoft.GamingApp"
Remove-App "Microsoft.GetHelp"
Remove-App "Microsoft.Getstarted"
Remove-App "Microsoft.Messaging"
Remove-App "Microsoft.MicrosoftOfficeHub"
Remove-App "Microsoft.Edge.GameAssist"
Remove-App "Microsoft.StartExperiencesApp"
Remove-App "Microsoft.ZuneVideo"
Remove-App "Microsoft.Edge.GameAssist"
Remove-App "Microsoft.MinecraftEducationEdition"
Remove-App "Microsoft.OneConnect" # Mobile Plans
Remove-App "Microsoft.OutlookForWindows"
Remove-App "Microsoft.Reader"
Remove-App "Microsoft.SkypeApp"
Remove-App "Microsoft.Wallet"
Remove-App "Microsoft.WindowsFeedbackHub"
Remove-App "Microsoft.WindowsReadingList"
Remove-App "Microsoft.Xbox.TCUI"
Remove-App "Microsoft.YourPhone"
Remove-App "microsoft.windowscommunicationsapps"
Remove-App "Microsoft.Copilot"
Remove-App "Microsoft.MicrosoftPowerBIForWindows"
Remove-App "Outlook (new)"
Remove-App "ZuneMusic"
Remove-App "Microsoft.BingNews"
Remove-App "Microsoft.BingWeather"
Remove-App "*PowerAutomate*"


function Remove-OneDriveCompletely {
    <#
    .SYNOPSIS
        Removes Microsoft OneDrive as completely as practical in unattended/SYSTEM contexts.

    .DESCRIPTION
        Handles common OneDrive install flavors:
          - AppX (Microsoft.OneDriveSync / etc) and provisioned packages
          - OneDriveSetup.exe /uninstall (System32 + SysWOW64)
          - Per-user installs in %LocalAppData%\Microsoft\OneDrive for ALL profiles
          - Program Files installs (x64/x86)
          - ARP entries in HKLM + per-user entries under HKU
          - Explorer namespace pin (optional but enabled by default here)
          - Policies to block re-provisioning / reinstall (DisableFileSyncNGSC)
          - Scheduled tasks and common Run keys that relaunch/reinstall

        Designed to be idempotent and safe to run repeatedly.

    .PARAMETER DisableReinstall
        Writes policy to block OneDrive from running/reinstalling (recommended).

    .PARAMETER RemoveExplorerNamespace
        Removes OneDrive from File Explorer navigation pane.

    .PARAMETER RemoveKnownScheduledTasks
        Disables/removes common OneDrive scheduled tasks.

    .PARAMETER RemoveRunKeys
        Removes Run key entries that auto-start OneDrive for all users.

    .PARAMETER Debug
        Emits more verbose output.

    .NOTES
        - Some changes may require Explorer restart or reboot to fully reflect in UI.
        - If OneDrive is managed by M365/Intune, policy may re-apply. This function tries to enforce block locally.
    #>

    param(
        [switch]$DisableReinstall = $true,
        [switch]$RemoveExplorerNamespace = $true,
        [switch]$RemoveKnownScheduledTasks = $true,
        [switch]$RemoveRunKeys = $true,
        [switch]$Debug
    )

    $ea = if ($Debug) { "Continue" } else { "SilentlyContinue" }
    $ErrorActionPreference = $ea

    function _Log([string]$msg) { Write-Output $msg }

    _Log "===== OneDrive removal starting (running as $([Environment]::UserName)) ====="

    # -------------------------------------------------------------------------
    # 0) Stop processes
    # -------------------------------------------------------------------------
    _Log "Stopping OneDrive-related processes..."
    Get-Process -Name "OneDrive*", "FileCoAuth", "Microsoft.SharePoint" -ErrorAction SilentlyContinue |
    Stop-Process -Force -ErrorAction SilentlyContinue

    # -------------------------------------------------------------------------
    # 1) Remove AppX + provisioned
    # -------------------------------------------------------------------------
    $appxPatterns = @(
        "Microsoft.OneDriveSync",
        "Microsoft.OneDrive",
        "*OneDrive*"
    )

    foreach ($pat in $appxPatterns) {
        $pkgs = Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like $pat }
        foreach ($p in $pkgs) {
            _Log "Removing AppX: $($p.Name) ($($p.PackageFullName))"
            try { Remove-AppxPackage -AllUsers -Package $p.PackageFullName -ErrorAction Stop } catch { _Log "FAILED AppX remove: $($_.Exception.Message)" }
        }

        $prov = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like $pat }
        foreach ($pr in $prov) {
            _Log "Removing provisioned AppX: $($pr.DisplayName) ($($pr.PackageName))"
            try { Remove-AppxProvisionedPackage -Online -AllUsers -PackageName $pr.PackageName -ErrorAction Stop } catch { _Log "FAILED provisioned remove: $($_.Exception.Message)" }
        }
    }

    # -------------------------------------------------------------------------
    # 2) Run OneDriveSetup.exe /uninstall (covers system install)
    # -------------------------------------------------------------------------
    $oneDriveSetupPaths = @(
        "$env:SystemRoot\System32\OneDriveSetup.exe",
        "$env:SystemRoot\SysWOW64\OneDriveSetup.exe"
    )

    foreach ($setup in $oneDriveSetupPaths) {
        if (Test-Path $setup) {
            _Log "Running uninstall: `"$setup`" /uninstall"
            try {
                $p = Start-Process -FilePath $setup -ArgumentList "/uninstall" -WindowStyle Hidden -Wait -PassThru -ErrorAction Stop
                $exitcode = $p.ExitCode
                _Log "Uninstall via $setup completed. ExitCode: $exitcode"
            }
            catch {
                _Log "FAILED to run $setup /uninstall : $($_.Exception.Message)"
            }
        }
        else {
            _Log "OneDriveSetup not found at: $setup"
        }
    }

    # Stop again in case setup spawned anything briefly
    Get-Process -Name "OneDrive*", "FileCoAuth" -ErrorAction SilentlyContinue |
    Stop-Process -Force -ErrorAction SilentlyContinue

    # -------------------------------------------------------------------------
    # 3) Remove per-user program installs for ALL profiles (LocalAppData)
    # -------------------------------------------------------------------------
    _Log "Removing per-user OneDrive binaries for all profiles..."
    $userRoots = Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -notin @("Default", "Default User", "Public", "All Users") }

    foreach ($u in $userRoots) {
        $localOD = Join-Path $u.FullName "AppData\Local\Microsoft\OneDrive"
        $settingsOD = Join-Path $u.FullName "AppData\Local\Microsoft\OneDrive\settings"
        if (Test-Path $localOD) {
            _Log "Removing $localOD"
            try { Remove-Item $localOD -Recurse -Force -ErrorAction Stop } catch { _Log "FAILED removing $localOD : $($_.Exception.Message)" }
        }

        # Common leftover OneDrive folder (synced data) - only remove the folder itself, not the whole profile
        $odFolder = Join-Path $u.FullName "OneDrive"
        if (Test-Path $odFolder) {
            _Log "Removing leftover OneDrive folder: $odFolder"
            try { Remove-Item $odFolder -Recurse -Force -ErrorAction Stop } catch { _Log "FAILED removing $odFolder : $($_.Exception.Message)" }
        }

        # Also check for "OneDrive - <Tenant>" folders
        try {
            Get-ChildItem -Path $u.FullName -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like "OneDrive -*" } |
            ForEach-Object {
                _Log "Removing leftover OneDrive folder: $($_.FullName)"
                try { Remove-Item $_.FullName -Recurse -Force -ErrorAction Stop } catch { _Log "FAILED removing $($_.FullName) : $($_.Exception.Message)" }
            }
        }
        catch {}
    }

    # -------------------------------------------------------------------------
    # 4) Remove Program Files installs (x64/x86)
    # -------------------------------------------------------------------------
    _Log "Removing OneDrive Win32 binaries (Program Files)..."
    $programPaths = @(
        "$env:ProgramFiles\Microsoft OneDrive",
        "$env:ProgramFiles(x86)\Microsoft OneDrive",
        "$env:ProgramData\Microsoft OneDrive"
    ) | Where-Object { $_ -and $_.Trim() -ne "" } | Select-Object -Unique

    foreach ($path in $programPaths) {
        if (Test-Path $path) {
            _Log "Removing $path"
            try { Remove-Item $path -Recurse -Force -ErrorAction Stop } catch { _Log "FAILED to remove $path : $($_.Exception.Message)" }
        }
    }

    # -------------------------------------------------------------------------
    # 5) Remove ARP entries (HKLM + HKU for all users)
    # -------------------------------------------------------------------------
    _Log "Removing OneDrive uninstall registry entries (ARP)..."

    $uninstallRootsHKLM = @(
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    $hklmEntries = Get-ItemProperty $uninstallRootsHKLM -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -eq "Microsoft OneDrive" -or $_.DisplayName -like "Microsoft OneDrive*" }

    foreach ($e in $hklmEntries) {
        _Log "Deleting HKLM ARP entry: $($e.PSPath)"
        try { Remove-Item $e.PSPath -Recurse -Force -ErrorAction Stop } catch { _Log "FAILED HKLM ARP delete: $($_.Exception.Message)" }
    }

    # Per-user ARP (HKU) - catches Settings "Installed apps" entries not in HKLM
    $hkuUninstall = "Registry::HKEY_USERS\*\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
    $hkuEntries = Get-ItemProperty $hkuUninstall -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -eq "Microsoft OneDrive" -or $_.DisplayName -like "Microsoft OneDrive*" }

    foreach ($e in $hkuEntries) {
        _Log "Deleting HKU ARP entry: $($e.PSPath)"
        try { Remove-Item $e.PSPath -Recurse -Force -ErrorAction Stop } catch { _Log "FAILED HKU ARP delete: $($_.Exception.Message)" }
    }

    # -------------------------------------------------------------------------
    # 6) Remove Run keys (auto-start)
    # -------------------------------------------------------------------------
    if ($RemoveRunKeys) {
        _Log "Removing OneDrive Run key entries..."
        $runPaths = @(
            "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run",
            "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Run"
        )

        foreach ($rp in $runPaths) {
            try {
                $props = Get-ItemProperty -Path $rp -ErrorAction SilentlyContinue
                if ($props.PSObject.Properties.Name -contains "OneDrive") {
                    _Log "Removing Run value OneDrive from $rp"
                    Remove-ItemProperty -Path $rp -Name "OneDrive" -ErrorAction SilentlyContinue
                }
            }
            catch {}
        }

        # Remove per-user Run keys for all loaded profiles
        $hkuRun = "Registry::HKEY_USERS\*\Software\Microsoft\Windows\CurrentVersion\Run"
        try {
            Get-ChildItem "Registry::HKEY_USERS" -ErrorAction SilentlyContinue | ForEach-Object {
                $p = "Registry::HKEY_USERS\$($_.PSChildName)\Software\Microsoft\Windows\CurrentVersion\Run"
                if (Test-Path $p) {
                    $props = Get-ItemProperty -Path $p -ErrorAction SilentlyContinue
                    if ($props.PSObject.Properties.Name -contains "OneDrive") {
                        _Log "Removing Run value OneDrive from $p"
                        Remove-ItemProperty -Path $p -Name "OneDrive" -ErrorAction SilentlyContinue
                    }
                }
            }
        }
        catch {}
    }

    # -------------------------------------------------------------------------
    # 7) Scheduled tasks (common OneDrive tasks)
    # -------------------------------------------------------------------------
    if ($RemoveKnownScheduledTasks) {
        _Log "Disabling/removing common OneDrive scheduled tasks..."
        $taskNameHints = @("OneDrive", "OneDrive Standalone Update Task", "OneDrive Reporting Task", "OneDrive Per-Machine Standalone Update Task")
        try {
            $tasks = Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object {
                $n = $_.TaskName
                $p = $_.TaskPath
                ($n -match "OneDrive") -or ($p -match "OneDrive")
            }

            foreach ($t in $tasks) {
                _Log "Disabling task: $($t.TaskPath)$($t.TaskName)"
                try { Disable-ScheduledTask -TaskName $t.TaskName -TaskPath $t.TaskPath -ErrorAction SilentlyContinue | Out-Null } catch {}
                try { Unregister-ScheduledTask -TaskName $t.TaskName -TaskPath $t.TaskPath -Confirm:$false -ErrorAction SilentlyContinue | Out-Null } catch {}
            }
        }
        catch {}
    }

    # -------------------------------------------------------------------------
    # 8) Policy to block OneDrive from running/reinstalling
    # -------------------------------------------------------------------------
    if ($DisableReinstall) {
        _Log "Applying OneDrive block policy (DisableFileSyncNGSC=1)..."
        try {
            New-Item "HKLM:\Software\Policies\Microsoft\Windows\OneDrive" -Force | Out-Null
            Set-ItemProperty "HKLM:\Software\Policies\Microsoft\Windows\OneDrive" `
                -Name "DisableFileSyncNGSC" -Type DWord -Value 1 -Force
        }
        catch {
            _Log "FAILED setting OneDrive policy: $($_.Exception.Message)"
        }
    }

    # -------------------------------------------------------------------------
    # 9) Remove Explorer namespace (navigation pane)
    # -------------------------------------------------------------------------
    if ($RemoveExplorerNamespace) {
        _Log "Removing OneDrive Explorer namespace entry..."
        $clsid = "{018D5C66-4533-4307-9B53-224DE2ED1FE6}"
        $nsKeys = @(
            "Registry::HKEY_CLASSES_ROOT\CLSID\$clsid",
            "Registry::HKEY_CLASSES_ROOT\Wow6432Node\CLSID\$clsid"
        )
        foreach ($k in $nsKeys) {
            if (Test-Path $k) {
                _Log "Deleting: $k"
                try { Remove-Item $k -Recurse -Force -ErrorAction Stop } catch { _Log "FAILED deleting $k : $($_.Exception.Message)" }
            }
        }
    }

    # -------------------------------------------------------------------------
    # 10) Final verification output (lightweight)
    # -------------------------------------------------------------------------
    _Log "Verifying OneDrive presence..."
    $odExeHits = @(
        "$env:ProgramFiles\Microsoft OneDrive\OneDrive.exe",
        "$env:ProgramFiles(x86)\Microsoft OneDrive\OneDrive.exe"
    ) | Where-Object { $_ -and (Test-Path $_) }

    foreach ($h in $odExeHits) { _Log "STILL PRESENT: $h" }

    $arpHKLM = Get-ItemProperty $uninstallRootsHKLM -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -like "Microsoft OneDrive*" } |
    Select-Object -First 5

    if ($arpHKLM) {
        _Log "STILL PRESENT in HKLM ARP (showing first 5):"
        $arpHKLM | ForEach-Object { _Log " - $($_.DisplayName)" }
    }

    $arpHKU = Get-ItemProperty $hkuUninstall -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -like "Microsoft OneDrive*" } |
    Select-Object -First 5

    if ($arpHKU) {
        _Log "STILL PRESENT in HKU ARP (showing first 5):"
        $arpHKU | ForEach-Object { _Log " - $($_.DisplayName) ($($_.PSPath))" }
    }

    _Log "===== OneDrive removal completed. ====="
}

# Usage inside your script:
if (-not $leaveonedrive) { Remove-OneDriveCompletely -DisableReinstall -RemoveExplorerNamespace -RemoveKnownScheduledTasks -RemoveRunKeys -Debug:$debug }


# Office-specific removal logic - only execute if not keeping Office
if (-not $leaveoffice) {
    Remove-M365 "Microsoft 365*"
    Remove-M365 "*OneNote*"
}
else {
    Remove-OfficeC2RLanguagesExceptEnUS -KeepCulture 'en-us'
}

# Teams-specific removal logic - only execute if not keeping Teams
if (-not $leaveteams) {
    Remove-App "Microsoft.MicrosoftTeams"
    Remove-App "MSTeams"
    Remove-App "MicrosoftTeams"
}

Invoke-AsCurrentUser -ScriptBlock {
    
    function Set-RegistryValue ($registryPath, $name, $value) {
        $currentValue = (Get-ItemProperty -Path $registryPath -Name $name -ErrorAction SilentlyContinue).$name
        if ($currentValue -ne $value) {
            if (!(Test-Path -Path $registryPath)) {
                New-Item -Path $registryPath -Force | Out-Null
            }
            Set-ItemProperty -Path $registryPath -Name $name -Value $value -Force
            Write-Output "Set '$name' to $value at '$registryPath'"
        }
        else {
            Write-Output "'$name' is already set to $value at '$registryPath'"
        }
    }

    # Registry settings
    $registrySettings = @(
        @{
            RegistryPath = "HKCU:\Software\Policies\Microsoft\Windows\CurrentVersion\AccountNotifications";
            Name         = "DisableAccountNotifications";
            Value        = 1
        },
        @{
            RegistryPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement";
            Name         = "ScoobeSystemSettingEnabled";
            Value        = 0
        }
    )

    # Apply the registry settings
    $registrySettings | ForEach-Object {
        Set-RegistryValue -registryPath $_.RegistryPath -name $_.Name -value $_.Value
    }

} -CaptureOutput


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
            
    # Parameter status info in debug mode
    Write-Output "`n==== Parameter Status ===="
    Write-Output "Keep Office: $leaveoffice"
    Write-Output "Keep Teams: $leaveteams"
    Write-Output "Keep OneDrive: $leaveonedrive"
}