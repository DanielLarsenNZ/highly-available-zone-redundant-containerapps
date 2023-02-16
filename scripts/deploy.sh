# Set up variables
RG_NAME='rg-zr-aca'
LOCATION='australiaeast'

# Create the resource group
az group create --name $RG_NAME --location $LOCATION

# Deploy Key Vault
KEY_VAULT_NAME=`az deployment group create \
    --name 'key-vault \'
    --resource-group $RG_NAME \
    --parameters location=$LOCATION \
    --template-file ./modules/key-vault.bicep \
    --query properties.outputs.name.value \
    --output tsv`

# Deploy ACR
ACR_NAME=`az deployment group create \
    --name 'acr-deployment' \
    --resource-group $RG_NAME \
    --parameters location=$LOCATION \
    --template-file ./modules/container-registry.bicep \
    --query properties.outputs.containerRegistryName.value \
    --output tsv`

# build images and push to ACR

# deploy main template
az deployment group create \
    --name 'main-deployment' \
    --resource-group $RG_NAME \
    --template-file ./main.bicep \
    --parameters location=$LOCATION \
    --parameters containerRegistryName=$ACR_NAME \
    --parameters keyVaultName=$KEY_VAULT_NAME