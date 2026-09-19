<#
.SYNOPSIS
	Restarts only the ADF triggers that Stop-ADFTriggers.ps1 previously stopped
	(recorded in triggerState.json). Idempotent - if the state file is missing
	or empty, no triggers are started (safe no-op).
#>
param(
	[Parameter(Mandatory = $true)][string]$ResourceGroupName,
	[Parameter(Mandatory = $true)][string]$DataFactoryName,
	[Parameter(Mandatory = $true)][string]$ArmTemplateFile,
	[string]$StateFile = "$(Split-Path -Path $ArmTemplateFile -Parent)/triggerState.json"
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $StateFile)) {
	Write-Host "No trigger state file found at '$StateFile'. Nothing to restart."
	return
}

$triggerNames = Get-Content -Raw -Path $StateFile | ConvertFrom-Json

if (-not $triggerNames -or $triggerNames.Count -eq 0) {
	Write-Host "No previously-started triggers recorded. Nothing to restart."
	return
}

foreach ($triggerName in $triggerNames) {
	try {
		$trigger = Get-AzDataFactoryV2Trigger -ResourceGroupName $ResourceGroupName -DataFactoryName $DataFactoryName -Name $triggerName -ErrorAction SilentlyContinue
	} catch {
		Write-Host "Trigger '$triggerName' no longer exists. Skipping."
		continue
	}

	if ($null -eq $trigger) {
		Write-Host "Trigger '$triggerName' not found. Skipping."
		continue
	}

	if ($trigger.RuntimeState -eq 'Started') {
		Write-Host "Trigger '$triggerName' is already Started. No action needed."
	} else {
		Write-Host "Starting trigger '$triggerName'..."
		Start-AzDataFactoryV2Trigger -ResourceGroupName $ResourceGroupName -DataFactoryName $DataFactoryName -Name $triggerName -Force
	}
}
