param (
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory=$true)]
    [string]$DataFactoryName
)

Write-Host "==========================================="
Write-Host "ADF Deployment Started"
Write-Host "Resource Group : $ResourceGroupName"
Write-Host "Data Factory   : $DataFactoryName"
Write-Host "==========================================="

# Verify ADF exists

$factory = Get-AzDataFactoryV2 `
    -ResourceGroupName $ResourceGroupName `
    -Name $DataFactoryName `
    -ErrorAction Stop

Write-Host "Found Data Factory:" $factory.DataFactoryName

# -----------------------------------------------------
# Deploy Dataset
# -----------------------------------------------------

$datasetPath = Join-Path $PSScriptRoot "..\pipeline\BSESS_Import.json"

if(Test-Path $datasetPath)
{
    Write-Host "Deploying Dataset..."

    $datasetJson = Get-Content $datasetPath -Raw | ConvertFrom-Json

    Set-AzDataFactoryV2Dataset `
        -ResourceGroupName $ResourceGroupName `
        -DataFactoryName $DataFactoryName `
        -Name $datasetJson.name `
        -DefinitionFile $datasetPath

    Write-Host "Dataset deployed successfully."
}
else
{
    Write-Warning "Dataset file not found."
}

# -----------------------------------------------------
# Deploy Pipeline
# -----------------------------------------------------

$pipelinePath = Join-Path $PSScriptRoot "..\pipeline\BSESS_Import-pipeline.json"

if(Test-Path $pipelinePath)
{
    Write-Host "Deploying Pipeline..."

    $pipelineJson = Get-Content $pipelinePath -Raw | ConvertFrom-Json

    Set-AzDataFactoryV2Pipeline `
        -ResourceGroupName $ResourceGroupName `
        -DataFactoryName $DataFactoryName `
        -Name $pipelineJson.name `
        -DefinitionFile $pipelinePath

    Write-Host "Pipeline deployed successfully."
}
else
{
    Write-Warning "Pipeline file not found."
}

Write-Host "==========================================="
Write-Host "ADF Deployment Completed"
Write-Host "==========================================="
