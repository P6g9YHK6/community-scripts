<#
.SYNOPSIS
    This script checks the status of the Veeam Backup Agent by:
    1. Searching for the most recent `.Backup.log` file in the specified directory.
    2. Extracting the job status and completion time from the log file.
    3. Verifying whether the job was successful and if the log entry is within a specified threshold period (default is 48 hours).
    4. Outputs a simplified result

.DESCRIPTION
    The script is intended to monitor the status of Veeam backup jobs by checking the latest log 
    file in the Veeam Endpoint backup folder. 

.NOTE
    Author: SAN
    Date: 10/08/24
    #public

.CHANGELOG
    15/04/25 SAN Code Cleaup & Publication
    12.02.26 SAN Code improvement and fix for v13

.TODO
    Var to env

#>

# CONFIG 
$RootDirectory = "C:\ProgramData\Veeam\Endpoint"
$ThresholdHours = 48
$DateFormat = "dd.MM.yyyy HH:mm:ss.fff"
$LogPattern = "Job session '.*' has been completed, status: '(.*?)',"
$FailureLogLines = 50


function Get-RecentLogFile {
    if (-not (Test-Path $RootDirectory)) {
        throw "Directory not found: $RootDirectory"
    }

    $logFile = Get-ChildItem -Path $RootDirectory -Filter "*.Backup.log" -Recurse -ErrorAction Stop |
               Sort-Object LastWriteTime -Descending |
               Select-Object -First 1

    if (-not $logFile) {
        throw "No .Backup.log files found."
    }

    return $logFile
}

function Get-JobStatusFromLog {
    param (
        [Parameter(Mandatory)]
        [System.IO.FileInfo]$LogFile
    )

    $recentLine = Select-String -Path $LogFile.FullName -Pattern $LogPattern -ErrorAction Stop |
                  Select-Object -Last 1

    if (-not $recentLine) {
        throw "No matching job completion entry found in log."
    }

    if ($recentLine.Line -match "\[(.*?)\].*status: '(.*?)',") {
        return @{
            DateTime = $matches[1]
            Status   = $matches[2]
        }
    }

    throw "Log entry found but parsing failed."
}

function Check-JobStatus {
    param (
        [Parameter(Mandatory)][string]$DateTime,
        [Parameter(Mandatory)][string]$Status
    )

    $culture = [System.Globalization.CultureInfo]::InvariantCulture

    try {
        $logDate = [datetime]::ParseExact($DateTime, $DateFormat, $culture)
    }
    catch {
        throw "Timestamp format invalid: '$DateTime'"
    }

    $timeSpan = New-TimeSpan -Start $logDate -End (Get-Date)

    if ($Status -ne "Success") {
        return @{
            Code = 1
            Message = "KO: Job status is '$Status'"
        }
    }

    if ($timeSpan.TotalHours -gt $ThresholdHours) {
        return @{
            Code = 1
            Message = "KO: Last backup older than $ThresholdHours hours (Last run: $DateTime)"
        }
    }

    return @{
        Code = 0
        Message = "OK: Job succeeded at $DateTime"
    }
}

function Write-FailureDetails {
    param (
        [string]$Message,
        [System.IO.FileInfo]$LogFile
    )

    Write-Output $Message

    if ($LogFile -and (Test-Path $LogFile.FullName)) {
        Write-Output "---- Last $FailureLogLines log lines ----"
        try {
            Get-Content -Path $LogFile.FullName -Tail $FailureLogLines -ErrorAction Stop |
                ForEach-Object { Write-Output $_ }
        }
        catch {
            Write-Output "Unable to read log tail: $($_.Exception.Message)"
        }
    }
}

#MAIN

$logFile = $null

try {
    $logFile = Get-RecentLogFile
    $jobInfo = Get-JobStatusFromLog -LogFile $logFile
    $result  = Check-JobStatus -DateTime $jobInfo.DateTime -Status $jobInfo.Status

    if ($result.Code -eq 0) {
        Write-Output $result.Message
        exit 0
    }
    else {
        Write-FailureDetails -Message $result.Message -LogFile $logFile
        exit 1
    }
}
catch {
    $errorMessage = "KO: $($_.Exception.Message)"
    Write-FailureDetails -Message $errorMessage -LogFile $logFile
    exit 1
}