param (
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]$DataFactoryName,

    [Parameter(Mandatory = $true)]
    [string]$KeyVaultName,
    
    [Parameter(Mandatory = $true)]
    [string]$RdsServerName,
    
    [Parameter(Mandatory = $true)]
    [string]$SqlServerName
)

$ErrorActionPreference = "Stop"
$ConfirmPreference = "None"

$RepoRoot = Split-Path $PSScriptRoot -Parent

Write-Host "====================================="
Write-Host "ADF Dependency Deployment Started"
Write-Host "Resource Group : $ResourceGroupName"
Write-Host "Data Factory   : $DataFactoryName"
Write-Host "Key Vault      : $KeyVaultName"
Write-Host "RDS Server     : $RdsServerName"
Write-Host "SQL Server     : $SqlServerName"
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

        $uri = "/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.DataFactory/factories/$DataFactoryName/integrationRuntimes/${irName}?api-version=2018-06-01"

        $resp = Invoke-AzRestMethod `
            -Method PUT `
            -Path $uri `
            -Payload $body

        if ($resp.StatusCode -notin 200, 201)
        {
            throw "Failed to create Integration Runtime $irName ($($resp.StatusCode)): $($resp.Content)"
        }

        Start-Sleep -Seconds 10

        Write-Host "SUCCESS: Created Integration Runtime - $irName"
    }
}

# ==================================================
# Verify Self-hosted Integration Runtime
# ==================================================

$shirName = "bse-integrationruntime-self-hosted"

$shir = Get-AzDataFactoryV2IntegrationRuntime `
    -ResourceGroupName $ResourceGroupName `
    -DataFactoryName $DataFactoryName `
    -Name $shirName `
    -ErrorAction SilentlyContinue

if (-not $shir)
{
    throw "Self-hosted Integration Runtime '$shirName' not found in $DataFactoryName"
}

Write-Host "SUCCESS: Self-hosted Integration Runtime exists - $shirName"

# ==================================================
# Linked Services
# ==================================================

$linkedServices = @(
    "AzureKeyVaultRDSTSE.json",
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

    $definitionFile = $path

    # Point any Key Vault linked service at this environment's vault
    if ($json.properties.type -eq "AzureKeyVault")
    {
        $json.properties.typeProperties.baseUrl = "https://$KeyVaultName.vault.azure.net/"
        $definitionFile = Join-Path ([System.IO.Path]::GetTempPath()) "$($json.name).json"
        [System.IO.File]::WriteAllText($definitionFile, ($json | ConvertTo-Json -Depth 20))
        Write-Host "Key Vault URL set to: $($json.properties.typeProperties.baseUrl)"
    }

    # Point the RDS linked service at this environment's server
    if ($json.properties.type -eq "AmazonRdsForSqlServer")
    {
        $json.properties.typeProperties.server = $RdsServerName
        $definitionFile = Join-Path ([System.IO.Path]::GetTempPath()) "$($json.name).json"
        [System.IO.File]::WriteAllText($definitionFile, ($json | ConvertTo-Json -Depth 20))
        Write-Host "RDS server set to: $RdsServerName"
    }
    
    # Point the Azure SQL linked service at this environment's server
    if ($json.properties.type -eq "AzureSqlDatabase")
    {
        $sqlFqdn = "$($SqlServerName.ToLower()).database.windows.net"
        $tp = $json.properties.typeProperties

        if ($tp.PSObject.Properties.Name -contains "server")
        {
            $tp.server = $sqlFqdn
        }
        elseif ($tp.connectionString -is [string])
        {
            $tp.connectionString = $tp.connectionString -replace '(?i)(Data Source|Server)=(tcp:)?[^;,]+', ('$1=$2' + $sqlFqdn)
        }
        else
        {
            throw "Could not find the server name in $($json.name) to update"
        }

        $definitionFile = Join-Path ([System.IO.Path]::GetTempPath()) "$($json.name).json"
        [System.IO.File]::WriteAllText($definitionFile, ($json | ConvertTo-Json -Depth 20))
        Write-Host "SQL server set to: $sqlFqdn"
    }

    Write-Host "Deploying Linked Service: $($json.name)"

    Set-AzDataFactoryV2LinkedService `
        -ResourceGroupName $ResourceGroupName `
        -DataFactoryName $DataFactoryName `
        -Name $json.name `
        -DefinitionFile $definitionFile `
        -Force | Out-Null

    Write-Host "SUCCESS: $($json.name)"
}

# ==================================================
# Datasets
# ==================================================

$datasets = @(
    "AmazonRdsForSqlServer.json",
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