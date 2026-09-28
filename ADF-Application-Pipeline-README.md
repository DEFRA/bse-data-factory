# ADF Application Deployment Pipeline

## Overview

This repository uses an Azure DevOps YAML-based deployment pipeline to deploy Azure Data Factory (ADF) artefacts directly from GitHub to target ADF environments.

The pipeline deploys:

- Integration Runtime dependencies (validation)
- Linked Services
- Datasets
- Pipelines

The current implementation deploys the dependencies required for:

- BSESS_Import
- BSESS_Import-pipeline

## Architecture

GitHub Repository
    -> Azure DevOps Pipeline
        -> DEV
        -> TST
        -> PRE

## Why Direct Deployment Instead of ARM Templates?

This solution uses GitHub as the source of truth and deploys ADF JSON artefacts directly using Azure PowerShell.

Benefits:

- No dependency on ADF Publish Mode
- No dependency on ARM template generation
- Simpler CI/CD process
- GitHub remains the single source of truth
- Easier control of individual artefact deployments

## Deployment Order

1. Integration Runtime Validation
2. Linked Services
3. Datasets
4. Pipelines

This deployment order ensures all dependencies exist before pipeline deployment.

## Current Dependencies

### Integration Runtime

- integrationRuntimeBSEDB

### Linked Services

- AmazonRdsForSqlServer1-pipeline
- AmazonRdsForSqlServer1
- AzureSqlDatabaseBSE-pipeline
- AzureSqlDatabaseBSE

### Datasets

- AmazonRdsForSqlServer-pipeline
- AmazonRdsForSqlServer
- AzureSqlSink-pipeline
- AzureSqlSink

### Pipelines

- BSESS_Import-pipeline
- BSESS_Import

## Deployment Script

Deployment logic is implemented in:

scripts/Deploy-AdfObjects.ps1

The script:

1. Validates required Integration Runtime exists.
2. Deploys Linked Services.
3. Deploys Datasets.
4. Deploys Pipelines.

## Adding a New ADF Pipeline

When a project team adds a new ADF pipeline, the deployment script must be updated to include the required dependencies.

### Example

New pipeline:

BSE_Access_Export

Potential dependencies:

- Linked Services
- Datasets
- Integration Runtime references

### Steps

1. Identify all dependent Linked Services, Datasets and Integration Runtime references.
2. Update the dependency arrays in Deploy-AdfObjects.ps1.
3. Commit the new artefacts and updated script.
4. Run the Azure DevOps deployment pipeline.

## Prerequisites

Before application deployment:

- Azure Data Factory must exist.
- Managed Virtual Network must exist.
- Required Integration Runtimes must exist.
- Azure DevOps Service Connections must be configured:
  - AZR-BSE-DEV1
  - AZR-BSE-TST1
  - AZR-BSE-PRE1

These components are provisioned by the infrastructure deployment process.

## Future Enhancements

- Deploy only changed artefacts using Git diff.
- Automatic dependency discovery.
- Production deployment stage.
- Environment approval gates.

## Ownership

- Infrastructure Repository: DEFRA-BSE-INFRA (Azure DevOps)
- Application Repository: bse-data-factory (GitHub)
- Deployment Platform: Azure DevOps

This implementation was successfully validated by deploying the BSESS_Import ADF pipeline and its dependencies into the DEV Azure Data Factory environment.
