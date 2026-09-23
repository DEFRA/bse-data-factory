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

# ==================================================
# Verify ADF exists
# ==================================================

Get-AzDataFactoryV2 `
    -ResourceGroupName $ResourceGroupName `
    -Name $DataFactoryName | Out-Null

Write-Host "ADF Found"

# ==================================================
# Create Integration Runtime If Missing
# ==================================================

$requiredIRs = @(
    "integrationRuntimeBSEDB"
)

foreach ($irName in $requiredIRs)
{
    $ir = Get-AzDataFactoryV2IntegrationRuntime `
        -ResourceGroupName $ResourceGroupName `
        -DataFactoryName $DataFactoryName `
        -Name $irName `
        -ErrorAction SilentlyContinue

    if ($ir)
    {
        Write-Host "SUCCESS: Integration Runtime already exists - $irName"
    }
    else
    {
        Write-Host "Integration Runtime not found. Creating: $irName"

        $body = @{
            properties = @{
                type = "Managed"
                typeProperties = @{
                    computeProperties = @{
                        location = "UK South"
                        dataFlowProperties = @{
                            computeType = "General"
                            coreCount = 8
                            timeToLive = 10
                            cleanup = $false
                            customProperties = @()
                        }
                        pipelineExternalComputeScaleProperties = @{
                            timeToLive = 60
                            numberOfPipelineNodes = 1
                            numberOfExternalNodes = 1
                        }
                    }
                }
                managedVirtualNetwork = @{
                    type = "ManagedVirtualNetworkReference"
                    referenceName = "default"
                }
            }
        } | ConvertTo-Json -Depth 20

        $subscriptionId = (Get-AzContext).Subscription.Id

        $uri = "/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.DataFactory/factories/$DataFactoryName/integrationRuntimes/$irName?api-version=2018-06-01"

        Invoke-AzRestMethod `
            -Method PUT `
            -Path $uri `
            -Payload $body | Out-Null

        Start-Sleep -Seconds 10

        Write-Host "SUCCESS: Created Integration Runtime - $irName"
    }
}

# ==================================================
# Linked Services
# ==================================================

$linkedServices = @(
    "AmazonRdsForSqlServer1.json",
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
# Pipelines
# ==================================================

$pipelines = @(
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
