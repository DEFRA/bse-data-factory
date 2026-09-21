param (
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]$DataFactoryName
)

$ErrorActionPreference = "Stop"
$ConfirmPreference = "None"

Write-Host "====================================="
Write-Host "ADF Deployment Started"
Write-Host "Resource Group : $ResourceGroupName"
Write-Host "Data Factory   : $DataFactoryName"
Write-Host "====================================="

# Verify Data Factory exists
Get-AzDataFactoryV2 `
    -ResourceGroupName $ResourceGroupName `
    -Name $DataFactoryName | Out-Null

Write-Host "ADF Found"

$RepoRoot = Split-Path $PSScriptRoot -Parent

# ==================================================
# Deploy Linked Services
# ==================================================

$linkedServicePath = Join-Path $RepoRoot "linkedService"

if (Test-Path $linkedServicePath)
{
    Write-Host ""
    Write-Host "Deploying Linked Services..."

    Get-ChildItem $linkedServicePath -Filter "*.json" | ForEach-Object {

        $json = Get-Content $_.FullName -Raw | ConvertFrom-Json
        $name = $json.name

        $existing = Get-AzDataFactoryV2LinkedService `
            -ResourceGroupName $ResourceGroupName `
            -DataFactoryName $DataFactoryName `
            -Name $name `
            -ErrorAction SilentlyContinue

        if ($existing)
        {
            Write-Host "Updating Linked Service: $name"
        }
        else
        {
            Write-Host "Creating Linked Service: $name"
        }

        Set-AzDataFactoryV2LinkedService `
            -ResourceGroupName $ResourceGroupName `
            -DataFactoryName $DataFactoryName `
            -Name $name `
            -DefinitionFile $_.FullName `
            -Force | Out-Null

        Write-Host "SUCCESS: $name"
    }
}

# ==================================================
# Deploy Datasets
# ==================================================

$datasetPath = Join-Path $RepoRoot "dataset"

if (Test-Path $datasetPath)
{
    Write-Host ""
    Write-Host "Deploying Datasets..."

    Get-ChildItem $datasetPath -Filter "*.json" | ForEach-Object {

        $json = Get-Content $_.FullName -Raw | ConvertFrom-Json
        $name = $json.name

        $existing = Get-AzDataFactoryV2Dataset `
            -ResourceGroupName $ResourceGroupName `
            -DataFactoryName $DataFactoryName `
            -Name $name `
            -ErrorAction SilentlyContinue

        if ($existing)
        {
            Write-Host "Updating Dataset: $name"
        }
        else
        {
            Write-Host "Creating Dataset: $name"
        }

        Set-AzDataFactoryV2Dataset `
            -ResourceGroupName $ResourceGroupName `
            -DataFactoryName $DataFactoryName `
            -Name $name `
            -DefinitionFile $_.FullName `
            -Force | Out-Null

        Write-Host "SUCCESS: $name"
    }
}

# ==================================================
# Deploy Pipelines
# ==================================================

$pipelinePath = Join-Path $RepoRoot "pipeline"

if (Test-Path $pipelinePath)
{
    Write-Host ""
    Write-Host "Deploying Pipelines..."

    Get-ChildItem $pipelinePath -Filter "*.json" | ForEach-Object {

        $json = Get-Content $_.FullName -Raw | ConvertFrom-Json

        if ($json.name)
        {
            $name = $json.name

            $existing = Get-AzDataFactoryV2Pipeline `
                -ResourceGroupName $ResourceGroupName `
                -DataFactoryName $DataFactoryName `
                -Name $name `
                -ErrorAction SilentlyContinue

            if ($existing)
            {
                Write-Host "Updating Pipeline: $name"
            }
            else
            {
                Write-Host "Creating Pipeline: $name"
            }

            Set-AzDataFactoryV2Pipeline `
                -ResourceGroupName $ResourceGroupName `
                -DataFactoryName $DataFactoryName `
                -Name $name `
                -DefinitionFile $_.FullName `
                -Force | Out-Null

            Write-Host "SUCCESS: $name"
        }
    }
}

Write-Host ""
Write-Host "====================================="
Write-Host "ADF Deployment Completed Successfully"
Write-Host "====================================="
