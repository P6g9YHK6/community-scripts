#public



param([string]$excluded_jobs = "")
if($excluded_jobs -ne "")
{
	$excluded_jobs_array = $excluded_jobs.Split(",")
}

<#
disabled temporarly
#Adding required SnapIn
if((Get-PSSnapin -Name VeeamPSSnapIn -ErrorAction SilentlyContinue) -eq $null)
{
	Add-PsSnapin VeeamPSSnapIn
}
#>


#-------------------------------------------------------------------------------

$output_jobs_failed 	= ""
$output_jobs_warning 	= ""
$nagios_output 			= ""
$exit_code 			= 0

$output_jobs_failed_counter 	= 0
$output_jobs_warning_counter 	= 0
$output_jobs_success_counter 	= 0
$output_jobs_none_counter 		= 0
$output_jobs_working_counter 	= 0
$output_jobs_skipped_counter 	= 0

#Get all Veeam backup jobs
$jobs = Get-VBRJob

#Loop through every backup job
ForEach($job in $jobs)
{
	$status 	= $job.GetLastResult()
	$state 		= $($job.findlastsession()).State
	
	#Parse the date when the job last run (thanks to tkurek.blogspot.com for this idea)
	$runtime 	= $job.GetScheduleOptions()
	$runtime 	= $runtime -replace '.*Latest run time: \[', ''
	$runtime 	= $runtime -replace '\], Next run time: .*', ''
	$runtime 	= $runtime.split(' ')[0]

	#Skip jobs that are currently running
	if($state -ne "Working")
	{
		if($status -eq "Failed")
		{
			if($excluded_jobs_array -ne $null -and $excluded_jobs_array -contains $job.Name)
			{
				$output_jobs_skipped_counter++
			}
			else
			{
				$output_jobs_failed += $job.Name + " (" + $runtime + "), "
				$exit_code = 2
				$output_jobs_failed_counter++
			}
		}
		elseif($status -eq "Warning")
		{
			if($excluded_jobs_array -ne $null -and $excluded_jobs_array -contains $job.Name)
			{
				$output_jobs_skipped_counter++
			}
			else
			{
				$output_jobs_warning += $job.Name + " (" + $runtime + "), "
				if($exit_code -ne 2)
				{
					$exit_code = 1
				}
				
				$output_jobs_warning_counter ++
			}
		}
		else
		{
			if($status -eq "None" -and $state -ne "Idle")
			{
				$output_jobs_none_counter++
			}
			else
			{
				$output_jobs_success_counter++
			}
		}
	}
	else
	{
		$output_jobs_working_counter++
	}
	
}

#We could display currently running jobs, but if we'd like to use the Nagios stalking option we just summarize "ok" and "working"
$output_jobs_success_counter = $output_jobs_working_counter + $output_jobs_success_counter

if($output_jobs_failed -ne "")
{
	$output_jobs_failed 	= $output_jobs_failed.Substring(0, $output_jobs_failed.Length-2)
	
	$nagios_output += "`nFailed: " + $output_jobs_failed
}

if($output_jobs_warning -ne "")
{
	$output_jobs_warning 	= $output_jobs_warning.Substring(0, $output_jobs_warning.Length-2)
	
	$nagios_output += "`nWarning: " + $output_jobs_warning
}

if($exit_code -eq 1 -or $exit_code -eq 2)
{
	Write-Host "Backup Status - Failed: "$output_jobs_failed_counter" / Warning: "$output_jobs_warning_counter" / OK: "$output_jobs_success_counter" / None: "$output_jobs_none_counter" / Skipped: "$output_jobs_skipped_counter $nagios_output
}
else
{
	Write-Host "Backup Status - All "$output_jobs_success_counter" backups successful"
}


exit $exit_code