#!/bin/bash

# Global variables
# Which location....: "az account list-locations -o table"
LOCATION=westeurope

# Infrastructure variables
ACR_RESOURCE_GROUP=infrastructure
ACR_NAME=hasiotis

echo "Create Infrastructure"
az group create --name ${ACR_RESOURCE_GROUP} --location ${LOCATION} -o table
az acr create --resource-group ${ACR_RESOURCE_GROUP}  --name ${ACR_NAME} --sku Basic -o table
az acr show --name ${ACR_NAME} --query loginServer
az network dns zone create --resource-group ${ACR_RESOURCE_GROUP} -n hasiotis.eu

az acr login --name ${ACR_NAME}
echo "docker push ${ACR_NAME}.azurecr.io/megatron:1.0.0"
