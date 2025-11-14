#!/bin/bash

# AKS Cluster Creation Script
# This script creates an Azure Kubernetes Service cluster using Bicep templates

set -e

# Function to display usage information
usage() {
    echo "Usage: $0 -g <resource-group> -n <cluster-name> [OPTIONS]"
    echo ""
    echo "Required arguments:"
    echo "  -g, --resource-group    Name of the Azure resource group"
    echo "  -n, --cluster-name      Name for the AKS cluster"
    echo ""
    echo "Optional arguments:"
    echo "  -l, --location          Azure region (default: westus3)"
    echo "  -c, --node-count        Number of nodes in system pool (default: 2)"
    echo "  -s, --vm-size           VM size for nodes (default: Standard_D8ds_v5)"
    echo "  -d, --dns-prefix        DNS prefix for the cluster (default: auto-generated)"
    echo "  -h, --help              Display this help message"
    echo ""
    echo "Example:"
    echo "  $0 -g my-resource-group -n my-aks-cluster"
    echo "  $0 -g my-rg -n my-cluster -l eastus -c 3 -s Standard_D4ds_v5"
    exit 1
}

# Initialize variables
RESOURCE_GROUP=""
CLUSTER_NAME=""
LOCATION="westus3"
NODE_COUNT="2"
VM_SIZE="Standard_D8ds_v5"
DNS_PREFIX=""

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
        -l|--location)
            LOCATION="$2"
            shift 2
            ;;
        -c|--node-count)
            NODE_COUNT="$2"
            shift 2
            ;;
        -s|--vm-size)
            VM_SIZE="$2"
            shift 2
            ;;
        -d|--dns-prefix)
            DNS_PREFIX="$2"
            shift 2
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

# Get the script directory to find the bicep template
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BICEP_TEMPLATE="$SCRIPT_DIR/aks-cluster.bicep"

# Verify bicep template exists
if [ ! -f "$BICEP_TEMPLATE" ]; then
    echo "Error: Bicep template not found at $BICEP_TEMPLATE"
    exit 1
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
echo "AKS Cluster Creation"
echo "========================================="
echo "Resource Group: $RESOURCE_GROUP"
echo "Cluster Name:   $CLUSTER_NAME"
echo "Location:       $LOCATION"
echo "Node Count:     $NODE_COUNT"
echo "VM Size:        $VM_SIZE"
if [ -n "$DNS_PREFIX" ]; then
    echo "DNS Prefix:     $DNS_PREFIX"
fi
echo "========================================="
echo ""

# Check if resource group exists, create if it doesn't
if ! az group show --name "$RESOURCE_GROUP" &> /dev/null; then
    echo "Resource group '$RESOURCE_GROUP' does not exist. Creating..."
    az group create --name "$RESOURCE_GROUP" --location "$LOCATION"
    echo "Resource group created successfully."
else
    echo "Using existing resource group '$RESOURCE_GROUP'."
fi

echo ""
echo "Creating AKS cluster '$CLUSTER_NAME'..."
echo "This may take several minutes..."
echo ""

# Build parameters
PARAMS="clusterName=$CLUSTER_NAME location=$LOCATION systemNodeCount=$NODE_COUNT vmSize=$VM_SIZE"
if [ -n "$DNS_PREFIX" ]; then
    PARAMS="$PARAMS dnsPrefix=$DNS_PREFIX"
fi

# Create the deployment
DEPLOYMENT_NAME="aks-cluster-$(date +%s)"

az deployment group create \
    --resource-group "$RESOURCE_GROUP" \
    --template-file "$BICEP_TEMPLATE" \
    --parameters $PARAMS \
    --name "$DEPLOYMENT_NAME"

echo ""
echo "========================================="
echo "AKS Cluster created successfully!"
echo "========================================="
echo ""
echo "To get credentials and configure kubectl:"
echo "  az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME"
echo ""
echo "To verify the cluster:"
echo "  kubectl get nodes"
echo ""