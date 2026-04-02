<#
.SYNOPSIS
    Monitors Windows 'System' event logs and reports error events with configurable thresholds.

.DESCRIPTION
    This script retrieves error events from the Windows 'System' log over a configurable lookback period 
    (default 48 hours) and evaluates them within a configurable evaluation window 
    (default 12 hours). It filters out events by specified Event IDs and keywords. 

    The script supports three severity thresholds (set unrealistic threshold to disable):
        - INFO: default 1 event
        - WARN: default 2 events
        - ERROR: default 4 events

    Behavior:
        1. Retrieves error events (Level=2) from the 'System' log within the lookback period.
        2. Filters out ignored Event IDs and keywords (defaults or via environment variables).
        3. Evaluates events within the evaluation window:
            - If count >= ERROR threshold, exits with ERROR exit code (3).
            - If count >= WARN threshold, exits with WARN exit code (2).
            - Otherwise, exits with INFO exit code (1).
        4. Debug mode outputs filtered events and thresholds.

.EXAMPLE
    DEBUG=true
    FILTER_ID=1111,22222,3333
    FILTER_KEYWORD=keyword1,keyword2
    INFO_THRESHOLD=1
    WARN_THRESHOLD=2
    ERROR_THRESHOLD=4
    LOOKBACK_HOURS=72
    EVALUATION_WINDOW_HOURS=24

.NOTES
    Author: SAN
    Date: 24.10.2024
    #PUBLIC
    Default ignored Event IDs:
        10016 - safe to ignore, see:
            https://learn.microsoft.com/en-us/troubleshoot/windows-client/application-management/event-10016-logged-when-accessing-dcom
        36874 - ignored due to TLS/connection constraints

.CHANGELOG
    04.12.24 SAN: Added environment variable support for ignored Event IDs.
    12.12.24 SAN: Added keyword filters and support for dynamic filter addition via environment variables.
    02.04.26 SAN: Added configurable info/warn/error thresholds with exit codes.

#>

$defaultEventIds      = @(10016, 36874)
$defaultKeywords      = @("gupdate", "anotherkeyword")

$defaultInfoThreshold  = 1
$defaultWarnThreshold  = 2
$defaultErrorThreshold = 4

$defaultLookbackHours        = 48
$defaultEvaluationWindowHours = 12

$infoExitCode   = 1
$warnExitCode   = 2
$errorExitCode  = 3

$debug              = $env:DEBUG
$filterIdEnv        = $env:FILTER_ID
$filterKeywordEnv   = $env:FILTER_KEYWORD

$infoThresholdEnv   = $env:INFO_THRESHOLD
$warnThresholdEnv   = $env:WARN_THRESHOLD
$errorThresholdEnv  = $env:ERROR_THRESHOLD

$lookbackEnv        = $env:LOOKBACK_HOURS
$evaluationEnv      = $env:EVALUATION_WINDOW_HOURS

$ignoredEventIds = if ($filterIdEnv) { ($filterIdEnv.Split(",") | ForEach-Object { $_.Trim() }) + $defaultEventIds } else { $defaultEventIds }
$ignoredKeywords = if ($filterKeywordEnv) { ($filterKeywordEnv.Split(",") | ForEach-Object { $_.Trim() }) + $defaultKeywords } else { $defaultKeywords }

$infoThreshold  = if ($infoThresholdEnv)  { [int]$infoThresholdEnv }  else { $defaultInfoThreshold }
$warnThreshold  = if ($warnThresholdEnv)  { [int]$warnThresholdEnv }  else { $defaultWarnThreshold }
$errorThreshold = if ($errorThresholdEnv) { [int]$errorThresholdEnv } else { $defaultErrorThreshold }

$lookbackHours = if ($lookbackEnv) { [int]$lookbackEnv } else { $defaultLookbackHours }
$evaluationWindowHours = if ($evaluationEnv) { [int]$evaluationEnv } else { $defaultEvaluationWindowHours }

$lookbackStartTime   = (Get-Date).AddHours(-$lookbackHours)
$evaluationStartTime = (Get-Date).AddHours(-$evaluationWindowHours)

$allErrors = Get-WinEvent -FilterHashtable @{ LogName='System'; Level=2; StartTime=$lookbackStartTime } -ErrorAction SilentlyContinue

function Test-KeywordMatch {
    param ($event, $keywords)
    $eventData = $event.Properties -join " " + " " + $event.Message
    foreach ($keyword in $keywords) { if ($eventData -match "(?i)\b$($keyword)\b") { return $true } }
    return $false
}

$filteredErrors = $allErrors | Where-Object {
    $eventIdMatches = $ignoredEventIds -contains $_.Id.ToString()
    $keywordMatches = Test-KeywordMatch $_ $ignoredKeywords
    -not ($eventIdMatches -or $keywordMatches)
}

if ($debug -eq "true") {
    Write-Output "DEBUG MODE ENABLED"
    Write-Output "Ignored Event IDs: $ignoredEventIds"
    Write-Output "Ignored Keywords: $ignoredKeywords"
    Write-Output "INFO Threshold: $infoThreshold"
    Write-Output "WARN Threshold: $warnThreshold"
    Write-Output "ERROR Threshold: $errorThreshold"
    Write-Output "Lookback Hours: $lookbackHours"
    Write-Output "Evaluation Window Hours: $evaluationWindowHours"
}

if ($debug -eq "true") {
    Write-Output "DEBUG: Filtering events with the following parameters:"
    Write-Output "DEBUG: Filtered Event IDs: $ignoredEventIds"
    Write-Output "DEBUG: Filtered Keywords: $ignoredKeywords"

    if ($eventsWithIdFilter.Count -gt 0) {
        Write-Output "Filtered Events by Event ID in the last $lookbackHours hours:"
        $eventsWithIdFilter | ForEach-Object { Write-Output "TimeCreated: $($_.TimeCreated)"; Write-Output "Event ID: $($_.Id)"; Write-Output "Message: $($_.Message)"; Write-Output "----------------------------------------" }
    } else { Write-Output "No events found matching the specified Event IDs in the last $lookbackHours hours." }

    if ($eventsWithKeywordFilter.Count -gt 0) {
        Write-Output "Filtered Events by Keyword in the last $lookbackHours hours:"
        $eventsWithKeywordFilter | ForEach-Object { Write-Output "TimeCreated: $($_.TimeCreated)"; Write-Output "Event ID: $($_.Id)"; Write-Output "Message: $($_.Message)"; Write-Output "----------------------------------------" }
    } else { Write-Output "No events found matching the specified Keywords in the last $lookbackHours hours." }
}

$errorsInEvaluationWindow = $filteredErrors | Where-Object { $_.TimeCreated -gt $evaluationStartTime }
$count = $errorsInEvaluationWindow.Count

if ($count -ge $errorThreshold) {
    Write-Output "CRITICAL: $count error events in last $evaluationWindowHours hours (threshold: $errorThreshold)."
    $errorsInEvaluationWindow | ForEach-Object {
        Write-Output "TimeCreated: $($_.TimeCreated)"
        Write-Output "Event ID: $($_.Id)"
        Write-Output "Message: $($_.Message)"
        Write-Output "----------------------------------------"
    }
    exit $errorExitCode
}
elseif ($count -ge $warnThreshold) {
    Write-Output "WARNING: $count error events in last $evaluationWindowHours hours (threshold: $warnThreshold)."
    $errorsInEvaluationWindow | ForEach-Object {
        Write-Output "TimeCreated: $($_.TimeCreated)"
        Write-Output "Event ID: $($_.Id)"
        Write-Output "Message: $($_.Message)"
        Write-Output "----------------------------------------"
    }
    exit $warnExitCode
}
elseif ($count -ge $infoThreshold) {
    Write-Output "INFO: $count error event(s) in last $evaluationWindowHours hours (below warning threshold: $warnThreshold)."
    $errorsInEvaluationWindow | ForEach-Object {
        Write-Output "TimeCreated: $($_.TimeCreated)"
        Write-Output "Event ID: $($_.Id)"
        Write-Output "Message: $($_.Message)"
        Write-Output "----------------------------------------"
    }
    exit $infoExitCode
}
else {
    Write-Output "OK: $count error events in last $evaluationWindowHours hours (below all thresholds)."
    exit 0
}