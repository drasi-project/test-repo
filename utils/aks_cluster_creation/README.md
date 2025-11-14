# AKS Cluster Creation Scripts

This directory contains scripts to easily create and delete Azure Kubernetes Service (AKS) clusters using Azure Bicep templates.

## Prerequisites

1. **Azure CLI**: Install from [Azure CLI installation guide](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
2. **Azure Account**: You need an active Azure subscription
3. **Login**: Run `az login` before using these scripts

## Files

- `create.sh` - Script to create an AKS cluster
- `delete.sh` - Script to delete an AKS cluster
- `aks-cluster.bicep` - Azure Bicep template defining the AKS infrastructure

## Creating an AKS Cluster

### Basic Usage

```bash
./create.sh -g <resource-group> -n <cluster-name>
```

### Required Arguments

- `-g, --resource-group` - Name of the Azure resource group (will be created if it doesn't exist)
- `-n, --cluster-name` - Name for the AKS cluster

### Optional Arguments

- `-l, --location` - Azure region (default: westus3)
- `-c, --node-count` - Number of nodes in system pool (default: 2)
- `-s, --vm-size` - VM size for nodes (default: Standard_D8ds_v5)
- `-d, --dns-prefix` - DNS prefix for the cluster (default: auto-generated)
- `-h, --help` - Display help message

### Examples

Create a basic cluster with defaults:
```bash
./create.sh -g drasi-test-rg -n drasi-aks-cluster
```

Create a cluster with custom configuration:
```bash
./create.sh -g my-rg -n my-cluster -l eastus -c 3 -s Standard_D4ds_v5
```

Create a cluster with custom DNS prefix:
```bash
./create.sh -g prod-rg -n prod-aks -d mycompany-prod
```

## Using the Cluster

After the cluster is created, connect to it:

```bash
az aks get-credentials --resource-group <resource-group> --name <cluster-name>
```

Verify the cluster:
```bash
kubectl get nodes
```

## Deleting an AKS Cluster

### Basic Usage

```bash
./delete.sh -g <resource-group> -n <cluster-name>
```

### Required Arguments

- `-g, --resource-group` - Name of the Azure resource group
- `-n, --cluster-name` - Name of the AKS cluster to delete

### Optional Arguments

- `--delete-rg` - Also delete the entire resource group (default: false)
- `-y, --yes` - Skip confirmation prompt
- `-h, --help` - Display help message

### Examples

Delete just the cluster (keeps resource group):
```bash
./delete.sh -g drasi-test-rg -n drasi-aks-cluster
```

Delete the cluster and entire resource group:
```bash
./delete.sh -g drasi-test-rg -n drasi-aks-cluster --delete-rg
```

Delete without confirmation prompt:
```bash
./delete.sh -g drasi-test-rg -n drasi-aks-cluster -y
```

## Cluster Configuration

The Bicep template creates an AKS cluster with:

- **Identity**: System-assigned managed identity
- **Auto-upgrade**: Enabled with stable channel for Kubernetes and NodeImage for OS
- **Agent Pool**: Single system pool with configurable:
  - Node count (default: 2)
  - VM size (default: Standard_D8ds_v5)
  - OS: AzureLinux
  - Type: Virtual Machine Scale Sets

## Customizing the Bicep Template

The `aks-cluster.bicep` file can be modified to add additional features:

- Additional node pools
- Network policies
- Azure Container Registry integration
- Azure Monitor integration
- Custom RBAC roles

After modifying the template, update the `create.sh` script to pass any new parameters.

## Troubleshooting

### Azure CLI not found
```bash
# Install Azure CLI
# macOS: brew install azure-cli
# Windows: Download from Microsoft
# Linux: See Azure docs
```

### Not logged in
```bash
az login
```

### Insufficient permissions
Ensure your Azure account has:
- Contributor role on the subscription or resource group
- Ability to create managed identities

### Cluster creation fails
Check the Azure portal deployment logs or run:
```bash
az deployment group list --resource-group <resource-group>
```

## Notes

- Cluster creation typically takes 5-10 minutes
- Deletion is initiated asynchronously (use `--no-wait` flag)
- The resource group will be created automatically if it doesn't exist
- DNS prefix is auto-generated using `uniqueString()` if not specified
