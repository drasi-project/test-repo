#!/bin/bash

# AKS Cluster Deletion Script
# This script deletes an Azure Kubernetes Service cluster

set -e

# Function to display usage information
usage() {
    echo "Usage: $0 -g <resource-group> -n <cluster-name> [OPTIONS]"
    echo ""
    echo "Required arguments:"
    echo "  -g, --resource-group    Name of the Azure resource group"
    echo "  -n, --cluster-name      Name of the AKS cluster to delete"
    echo ""
    echo "Optional arguments:"
    echo "  --delete-rg             Also delete the resource group (default: false)"
    echo "  -y, --yes               Skip confirmation prompt"
    echo "  -h, --help              Display this help message"
    echo ""
    echo "Example:"
    echo "  $0 -g my-resource-group -n my-aks-cluster"
    echo "  $0 -g my-rg -n my-cluster --delete-rg -y"
    exit 1
}

# Initialize variables
RESOURCE_GROUP=""
CLUSTER_NAME=""
DELETE_RG=false
SKIP_CONFIRM=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -g|--resource-group)
            RESOURCE_GROUP="$2"
            shift 2
            ;;
        -n|--cluster-name)
            CLUSTER_NAME="$2"
            shift 2
            ;;
        --delete-rg)
            DELETE_RG=true
            shift
            ;;
        -y|--yes)
            SKIP_CONFIRM=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate required arguments
if [ -z "$RESOURCE_GROUP" ] || [ -z "$CLUSTER_NAME" ]; then
    echo "Error: Resource group and cluster name are required."
    echo ""
    usage
fi

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo "Error: Azure CLI is not installed. Please install it from https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi

# Check if logged into Azure
if ! az account show &> /dev/null; then
    echo "Error: Not logged into Azure. Please run 'az login' first."
    exit 1
fi

echo "========================================="
echo "AKS Cluster Deletion"
echo "========================================="
echo "Resource Group: $RESOURCE_GROUP"
echo "Cluster Name:   $CLUSTER_NAME"
if [ "$DELETE_RG" = true ]; then
    echo "Delete RG:      Yes (entire resource group will be deleted)"
else
    echo "Delete RG:      No (only the cluster will be deleted)"
fi
echo "========================================="
echo ""

# Check if cluster exists
if ! az aks show --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME" &> /dev/null; then
    echo "Error: AKS cluster '$CLUSTER_NAME' not found in resource group '$RESOURCE_GROUP'."
    exit 1
fi

# Confirmation prompt
if [ "$SKIP_CONFIRM" = false ]; then
    if [ "$DELETE_RG" = true ]; then
        read -p "Are you sure you want to delete the entire resource group '$RESOURCE_GROUP'? (yes/no): " confirm
    else
        read -p "Are you sure you want to delete AKS cluster '$CLUSTER_NAME'? (yes/no): " confirm
    fi

    if [ "$confirm" != "yes" ]; then
        echo "Deletion cancelled."
        exit 0
    fi
fi

if [ "$DELETE_RG" = true ]; then
    echo ""
    echo "Deleting resource group '$RESOURCE_GROUP'..."
    echo "This will delete the AKS cluster and all other resources in the group."
    echo "This may take several minutes..."
    echo ""

    az group delete --name "$RESOURCE_GROUP" --yes --no-wait

    echo "Resource group deletion initiated."
    echo "Use 'az group show --name $RESOURCE_GROUP' to check the deletion status."
else
    echo ""
    echo "Deleting AKS cluster '$CLUSTER_NAME'..."
    echo "This may take several minutes..."
    echo ""

    az aks delete \
        --resource-group "$RESOURCE_GROUP" \
        --name "$CLUSTER_NAME" \
        --yes \
        --no-wait

    echo "Cluster deletion initiated."
    echo "Use 'az aks show --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME' to check the deletion status."
fi

echo ""
echo "========================================="
echo "Deletion request submitted successfully!"
echo "========================================="
echo ""
