<#
.SYNOPSIS
	Stops ADF triggers that are currently in a Started state and are present
	in the ARM template being deployed. Idempotent - triggers already stopped
	(e.g. the newly added *-pipeline trigger) are skipped safely.
#>
param(
	[Parameter(Mandatory = $true)][string]$ResourceGroupName,
	[Parameter(Mandatory = $true)][string]$DataFactoryName,
	[Parameter(Mandatory = $true)][string]$ArmTemplateFile,
	[string]$StateFile = "$(Split-Path -Path $ArmTemplateFile -Parent)/triggerState.json"
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $ArmTemplateFile)) {
	throw "ARM template file not found: $ArmTemplateFile"
}

$armTemplate = Get-Content -Raw -Path $ArmTemplateFile | ConvertFrom-Json
$triggerResources = $armTemplate.resources | Where-Object { $_.type -like '*factories/triggers' }

if (-not $triggerResources -or $triggerResources.Count -eq 0) {
	Write-Host "No trigger resources found in ARM template. Nothing to stop."
	return
}

$stoppedTriggerNames = @()

foreach ($resource in $triggerResources) {
	# Resource name in ARM template is typically "<factoryName>/<triggerName>"
	$triggerName = ($resource.name -split '/')[-1].Trim("'", '[', ']')
	$triggerName = $triggerName -replace "parameters\('factoryName'\)", '' -replace "^'|'$", ''

	if ([string]::IsNullOrWhiteSpace($triggerName) -or $triggerName -notmatch '^[A-Za-z0-9_\-]+$') {
		Write-Host "Skipping unresolved trigger name from resource: $($resource.name)"
		continue
	}

	try {
		$trigger = Get-AzDataFactoryV2Trigger -ResourceGroupName $ResourceGroupName -DataFactoryName $DataFactoryName -Name $triggerName -ErrorAction SilentlyContinue
	} catch {
		Write-Host "Trigger '$triggerName' does not exist yet in the factory. Skipping (new deployment)."
		continue
	}

	if ($null -eq $trigger) {
		Write-Host "Trigger '$triggerName' not found. Skipping."
		continue
	}

	if ($trigger.RuntimeState -eq 'Started') {
		Write-Host "Stopping trigger '$triggerName' (currently Started)..."
		Stop-AzDataFactoryV2Trigger -ResourceGroupName $ResourceGroupName -DataFactoryName $DataFactoryName -Name $triggerName -Force
		$stoppedTriggerNames += $triggerName
	} else {
		Write-Host "Trigger '$triggerName' is already '$($trigger.RuntimeState)'. No action needed."
	}
}

# Persist which triggers we stopped so Start-ADFTriggers.ps1 only restarts those.
$stoppedTriggerNames | ConvertTo-Json | Set-Content -Path $StateFile
Write-Host "Recorded $($stoppedTriggerNames.Count) stopped trigger(s) to '$StateFile'."
