param (
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]$DataFactoryName
)

$ErrorActionPreference = "Stop"

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
# Linked Services
# ==================================================

$linkedServicePath = Join-Path $RepoRoot "linkedService"

if(Test-Path $linkedServicePath)
{
    Write-Host ""
    Write-Host "Deploying Linked Services..."

    Get-ChildItem $linkedServicePath -Filter "*.json" | ForEach-Object {

        $json = Get-Content $_.FullName -Raw | ConvertFrom-Json
        $name = $json.name

        Write-Host "Deploying Linked Service: $name"

        Set-AzDataFactoryV2LinkedService `
            -ResourceGroupName $ResourceGroupName `
            -DataFactoryName $DataFactoryName `
            -Name $name `
            -DefinitionFile $_.FullName

        Write-Host "SUCCESS: $name"
    }
}

# ==================================================
# Datasets
# ==================================================

$datasetPath = Join-Path $RepoRoot "dataset"

if(Test-Path $datasetPath)
{
    Write-Host ""
    Write-Host "Deploying Datasets..."

    Get-ChildItem $datasetPath -Filter "*.json" | ForEach-Object {

        $json = Get-Content $_.FullName -Raw | ConvertFrom-Json
        $name = $json.name

        Write-Host "Deploying Dataset: $name"

        Set-AzDataFactoryV2Dataset `
            -ResourceGroupName $ResourceGroupName `
            -DataFactoryName $DataFactoryName `
            -Name $name `
            -DefinitionFile $_.FullName

        Write-Host "SUCCESS: $name"
    }
}

# ==================================================
# Pipelines
# ==================================================

$pipelinePath = Join-Path $RepoRoot "pipeline"

if(Test-Path $pipelinePath)
{
    Write-Host ""
    Write-Host "Deploying Pipelines..."

    Get-ChildItem $pipelinePath -Filter "*.json" | ForEach-Object {

        $json = Get-Content $_.FullName -Raw | ConvertFrom-Json

        if($json.name)
        {
            $name = $json.name

            Write-Host "Deploying Pipeline: $name"

            Set-AzDataFactoryV2Pipeline `
                -ResourceGroupName $ResourceGroupName `
                -DataFactoryName $DataFactoryName `
                -Name $name `
                -DefinitionFile $_.FullName

            Write-Host "SUCCESS: $name"
        }
    }
}

Write-Host ""
Write-Host "ADF Deployment Completed Successfully"
