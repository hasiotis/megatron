#!/bin/bash

# Global
MAIN_DOMAIN=hasiotis.eu
ACR_NAME=hasiotis
ACR_RESOURCE_GROUP=infrastructure

# Cluster
AKS_CLUSTER_NAME="production"
AKS_RESOURCE_GROUP=${AKS_CLUSTER_NAME}
AKS_CLUSTER_CODE="prd"
AKS_CLUSTER_VERSION=1.10.3
AKS_CLUSTER_NODE_COUNT=1

LOCATION=westeurope
CLUSTER_DOMAIN=${AKS_CLUSTER_CODE}.${MAIN_DOMAIN}

echo "Create k8s cluster"
az group create --name ${AKS_RESOURCE_GROUP} --location ${LOCATION}
az network dns zone create --resource-group ${AKS_RESOURCE_GROUP} -n ${CLUSTER_DOMAIN}
az network dns record-set ns create -g ${ACR_RESOURCE_GROUP} -z ${MAIN_DOMAIN} -n prd
NS_SRV=`az network dns zone show --resource-group ${AKS_RESOURCE_GROUP} -n ${CLUSTER_DOMAIN} --query nameServers -o tsv`
for NS_DOT in ${NS_SRV}; do
    NS=${NS_DOT%?}
    az network dns record-set ns add-record -g ${ACR_RESOURCE_GROUP} -z ${MAIN_DOMAIN} -n prd -d ${NS}
done

az aks create --resource-group ${AKS_RESOURCE_GROUP}    \
    --name ${AKS_CLUSTER_NAME}                          \
    --kubernetes-version ${AKS_CLUSTER_VERSION}         \
    --node-count ${AKS_CLUSTER_NODE_COUNT}              \
    --ssh-key-value ~/.ssh/id_rsa.pub                   \
    --tags owner=hasiotis env=production                \
    --enable-rbac                                       \
#    --enable-addons http_application_routing
az aks get-credentials -g ${AKS_RESOURCE_GROUP} -n ${AKS_CLUSTER_NAME}

echo "Allow docker read (pull) for k8s cluster"
CLIENT_ID=$(az aks show --resource-group ${AKS_RESOURCE_GROUP} --name ${AKS_CLUSTER_NAME} --query "servicePrincipalProfile.clientId" --output tsv)
ACR_ID=$(az acr show --name $ACR_NAME --resource-group ${ACR_RESOURCE_GROUP} --query id --output tsv)
az role assignment create --assignee ${CLIENT_ID} --role Reader --scope ${ACR_ID}

echo "Creating DNS support"
TENANT_ID=`az account show -o tsv --query tenantId`
SUBSCRIPTION_ID=`az group show --name ${AKS_RESOURCE_GROUP} -o tsv --query id | cut -f 3 -d/`
SUBSCRIPTION_ID_FULL=`az group show --name ${AKS_RESOURCE_GROUP} -o tsv --query id`

AAD_CLIENT_SECRET=`az ad sp create-for-rbac --role=Contributor --scopes=${SUBSCRIPTION_ID_FULL} -n ExternalDnsServicePrincipal -o tsv --query password`
APP_ID=`az ad sp list --query "[?displayName == 'ExternalDnsServicePrincipal'].appId" -o tsv`
AAD_CLIENT_ID=`az ad sp show --id ${APP_ID} -o tsv --query appId`

(
cat <<EOF
{
  "tenantId": "${TENANT_ID}",
  "subscriptionId": "${SUBSCRIPTION_ID}",
  "aadClientId": "${AAD_CLIENT_ID}",
  "aadClientSecret": "${AAD_CLIENT_SECRET}",
  "resourceGroup": "${AKS_RESOURCE_GROUP}",
}
EOF
) > azure.json
kubectl create secret generic azure-config-file --from-file=azure.json
rm -rf azure.json
kubectl apply -f external-dns.yaml
