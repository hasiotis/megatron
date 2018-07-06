#!/bin/bash

az ad sp delete --id `az ad sp list --query "[?displayName == 'ExternalDnsServicePrincipal'].appId" -o tsv`
az group delete -n production --yes
#az group delete -n infrastructure --yes
