param (
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]$DataFactoryName
)

$ErrorActionPreference = "Stop"
$ConfirmPreference = "None"

$RepoRoot = Split-Path $PSScriptRoot -Parent

Write-Host "====================================="
Write-Host "ADF Dependency Deployment Started"
Write-Host "Resource Group : $ResourceGroupName"
Write-Host "Data Factory   : $DataFactoryName"
Write-Host "====================================="

# Verify ADF exists

Get-AzDataFactoryV2 `
    -ResourceGroupName $ResourceGroupName `
    -Name $DataFactoryName | Out-Null

Write-Host "ADF Found"

# ==================================================
# Integration Runtimes
# ==================================================

$integrationRuntimes = @(
    "integrationRuntimeBSEDB-pipeline.json",
    "integrationRuntimeBSEDB.json"
)

foreach ($file in $integrationRuntimes)
{
    $path = Join-Path $RepoRoot "integrationRuntime\$file"

    Write-Host "Deploying Integration Runtime: $file"

    $json = Get-Content $path -Raw | ConvertFrom-Json

    Set-AzDataFactoryV2IntegrationRuntime `
        -ResourceGroupName $ResourceGroupName `
        -DataFactoryName $DataFactoryName `
        -Name $json.name `
        -DefinitionFile $path `
        -Force | Out-Null

    Write-Host "SUCCESS: $($json.name)"
}

# ==================================================
# Linked Services
# ==================================================

$linkedServices = @(
    "AmazonRdsForSqlServer1-pipeline.json",
    "AmazonRdsForSqlServer1.json",
    "AzureSqlDatabaseBSE-pipeline.json",
    "AzureSqlDatabaseBSE.json"
)

foreach ($file in $linkedServices)
{
    $path = Join-Path $RepoRoot "linkedService\$file"

    Write-Host "Deploying Linked Service: $file"

    $json = Get-Content $path -Raw | ConvertFrom-Json

    Set-AzDataFactoryV2LinkedService `
        -ResourceGroupName $ResourceGroupName `
        -DataFactoryName $DataFactoryName `
        -Name $json.name `
        -DefinitionFile $path `
        -Force | Out-Null

    Write-Host "SUCCESS: $($json.name)"
}

# ==================================================
# Datasets
# ==================================================

$datasets = @(
    "AmazonRdsForSqlServer-pipeline.json",
    "AmazonRdsForSqlServer.json",
    "AzureSqlSink-pipeline.json",
    "AzureSqlSink.json"
)

foreach ($file in $datasets)
{
    $path = Join-Path $RepoRoot "dataset\$file"

    Write-Host "Deploying Dataset: $file"

    $json = Get-Content $path -Raw | ConvertFrom-Json

    Set-AzDataFactoryV2Dataset `
        -ResourceGroupName $ResourceGroupName `
        -DataFactoryName $DataFactoryName `
        -Name $json.name `
        -DefinitionFile $path `
        -Force | Out-Null

    Write-Host "SUCCESS: $($json.name)"
}

# ==================================================
# Pipelines
# ==================================================

$pipelines = @(
    "BSESS_Import-pipeline.json",
    "BSESS_Import.json"
)

foreach ($file in $pipelines)
{
    $path = Join-Path $RepoRoot "pipeline\$file"

    Write-Host "Deploying Pipeline: $file"

    $json = Get-Content $path -Raw | ConvertFrom-Json

    Set-AzDataFactoryV2Pipeline `
        -ResourceGroupName $ResourceGroupName `
        -DataFactoryName $DataFactoryName `
        -Name $json.name `
        -DefinitionFile $path `
        -Force | Out-Null

    Write-Host "SUCCESS: $($json.name)"
}

Write-Host ""
Write-Host "====================================="
Write-Host "ADF Dependency Deployment Completed"
Write-Host "====================================="
