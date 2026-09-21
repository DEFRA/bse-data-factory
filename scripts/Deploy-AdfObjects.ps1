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
# Validate Integration Runtime
# ==================================================

$requiredIRs = @(
    "integrationRuntimeBSEDB",
    "integrationRuntimeBSEDB"
)

foreach ($irName in $requiredIRs)
{
    $ir = Get-AzDataFactoryV2IntegrationRuntime `
        -ResourceGroupName $ResourceGroupName `
        -DataFactoryName $DataFactoryName `
        -Name $irName `
        -ErrorAction SilentlyContinue

    if (-not $ir)
    {
        throw "Required Integration Runtime '$irName' does not exist in ADF '$DataFactoryName'. Deploy it through infrastructure first."
    }

    Write-Host "SUCCESS: Integration Runtime found - $irName"
}

# ==================================================
# Deploy Linked Services
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

    if (-not (Test-Path $path))
    {
        throw "Linked Service file not found: $path"
    }

    $json = Get-Content $path -Raw | ConvertFrom-Json

    Write-Host "Deploying Linked Service: $($json.name)"

    Set-AzDataFactoryV2LinkedService `
        -ResourceGroupName $ResourceGroupName `
        -DataFactoryName $DataFactoryName `
        -Name $json.name `
        -DefinitionFile $path `
        -Force | Out-Null

    Write-Host "SUCCESS: $($json.name)"
}

# ==================================================
# Deploy Datasets
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

    if (-not (Test-Path $path))
    {
        throw "Dataset file not found: $path"
    }

    $json = Get-Content $path -Raw | ConvertFrom-Json

    Write-Host "Deploying Dataset: $($json.name)"

    Set-AzDataFactoryV2Dataset `
        -ResourceGroupName $ResourceGroupName `
        -DataFactoryName $DataFactoryName `
        -Name $json.name `
        -DefinitionFile $path `
        -Force | Out-Null

    Write-Host "SUCCESS: $($json.name)"
}

# ==================================================
# Deploy Pipelines
# ==================================================

$pipelines = @(
    "BSESS_Import-pipeline.json",
    "BSESS_Import.json"
)

foreach ($file in $pipelines)
{
    $path = Join-Path $RepoRoot "pipeline\$file"

    if (-not (Test-Path $path))
    {
        throw "Pipeline file not found: $path"
    }

    $json = Get-Content $path -Raw | ConvertFrom-Json

    Write-Host "Deploying Pipeline: $($json.name)"

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
