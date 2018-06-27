#!/bin/bash

LOCATION=westeurope
ACR_NAME=hasiotis
ACR_RESOURCE_GROUP=infrastructure

# Environment variables
AKS_RESOURCE_GROUP=production
AKS_CLUSTER_NAME=production
# Which version.....: "az aks get-versions -l westeurope -o table"
AKS_CLUSTER_VERSION=1.10.3
AKS_CLUSTER_NODE_COUNT=1

echo "Create k8s cluster"
az network dns zone create --resource-group ${AKS_RESOURCE_GROUP} -n prd.hasiotis.eu
az network dns record-set ns create     -g infrastructure  -z hasiotis.eu -n prd
az network dns record-set ns add-record -g infrastructure  -z hasiotis.eu -n prd -d ns1-03.azure-dns.com
az network dns record-set ns add-record -g infrastructure  -z hasiotis.eu -n prd -d ns2-03.azure-dns.net
az network dns record-set ns add-record -g infrastructure  -z hasiotis.eu -n prd -d ns3-03.azure-dns.org
az network dns record-set ns add-record -g infrastructure  -z hasiotis.eu -n prd -d ns4-03.azure-dns.info

az group create --name ${AKS_RESOURCE_GROUP} --location ${LOCATION} -o table
az aks create --resource-group ${AKS_RESOURCE_GROUP}    \
    --name ${AKS_CLUSTER_NAME}                          \
    --kubernetes-version ${AKS_CLUSTER_VERSION}         \
    --node-count ${AKS_CLUSTER_NODE_COUNT}              \
    --ssh-key-value ~/.ssh/id_rsa.pub                   \
    --tags owner=hasiotis env=production                \
    --enable-rbac                                       \
#    --enable-addons http_application_routing
az aks get-credentials -g ${AKS_RESOURCE_GROUP} -n ${AKS_CLUSTER_NAME} --output table

echo "Allow docker read (pull) for k8s cluster"
CLIENT_ID=$(az aks show --resource-group ${AKS_RESOURCE_GROUP} --name ${AKS_CLUSTER_NAME} --query "servicePrincipalProfile.clientId" --output tsv)
ACR_ID=$(az acr show --name $ACR_NAME --resource-group ${ACR_RESOURCE_GROUP} --query id --output tsv)
az role assignment create --assignee ${CLIENT_ID} --role Reader --scope ${ACR_ID}

echo "Creating DNS support"
TENANT_ID=`az account show -o tsv --query tenantId`
SUBSCRIPTION_ID=`az group show --name production -o tsv --query id`

AAD_CLIENT_SECRET=`az ad sp create-for-rbac --role=Contributor --scopes=${SUBSCRIPTION_ID} -n ExternalDnsServicePrincipal -o tsv --query password`
APP_ID=`az ad sp list --query "[?displayName == 'ExternalDnsServicePrincipal'].appId" -o tsv`
AAD_CLIENT_ID=`az ad sp show --id ${APP_ID} -o tsv --query appId`

(
cat <<EOF
{
  "tenantId": "${TENANT_ID}",
  "subscriptionId": "${SUBSCRIPTION_ID}",
  "aadClientId": "${AAD_CLIENT_ID}",
  "aadClientSecret": "${AAD_CLIENT_SECRET}",
  "resourceGroup": "production",
}
EOF
) > azure.json
kubectl create secret generic azure-config-file --from-file=azure.json
