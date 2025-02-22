@description('The AI Studio Hub Resource name')
param name string
@description('The display name of the AI Studio Hub Resource')
param displayName string = name
@description('The storage account ID to use for the AI Studio Hub Resource')
param storageAccountId string
@description('The key vault ID to use for the AI Studio Hub Resource')
param keyVaultId string
@description('The application insights ID to use for the AI Studio Hub Resource')
param appInsightsId string = ''
@description('The container registry ID to use for the AI Studio Hub Resource')
param containerRegistryId string = ''
@description('The OpenAI Cognitive Services account name to use for the AI Studio Hub Resource')
param openAiName string
@description('The Azure Cognitive Search service name to use for the AI Studio Hub Resource')
param aiSearchName string = ''

@description('The SKU name to use for the AI Studio Hub Resource')
param skuName string = 'Basic'
@description('The SKU tier to use for the AI Studio Hub Resource')
@allowed(['Basic', 'Free', 'Premium', 'Standard'])
param skuTier string = 'Basic'
@description('The public network access setting to use for the AI Studio Hub Resource')
@allowed(['Enabled','Disabled'])
param publicNetworkAccess string = 'Enabled'

param location string = resourceGroup().location
param tags object = {}

resource hub 'Microsoft.MachineLearningServices/workspaces@2024-01-01-preview' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: skuName
    tier: skuTier
  }
  kind: 'Hub'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    friendlyName: displayName
    storageAccount: storageAccountId
    keyVault: keyVaultId
    applicationInsights: !empty(appInsightsId) ? appInsightsId : null
    containerRegistry: !empty(containerRegistryId) ? containerRegistryId : null
    hbiWorkspace: false
    managedNetwork: {
      isolationMode: 'Disabled'
    }
    v1LegacyMode: false
    publicNetworkAccess: publicNetworkAccess
    discoveryUrl: 'https://${location}.api.azureml.ms/discovery'
  }

  resource openAiDefaultEndpoint 'endpoints' = {
    name: 'Azure.OpenAI'
    properties: {
      name: 'Azure.OpenAI'
      endpointType: 'Azure.OpenAI'
      associatedResourceId: openAi.id
    }
  }

  resource contentSafetyDefaultEndpoint 'endpoints' = {
    name: 'Azure.ContentSafety'
    properties: {
      name: 'Azure.ContentSafety'
      endpointType: 'Azure.ContentSafety'
      associatedResourceId: openAi.id
    }
  }

  resource openAiConnection 'connections' = {
    name: 'aoai-connection'
    properties: {
      category: 'AzureOpenAI'
      authType: 'AAD'
      isSharedToAll: true
      target: openAi.properties.endpoints['OpenAI Language Model Instance API']
      metadata: {
        ApiType: 'azure'
        ResourceId: openAi.id
      }
    }
  }

  resource searchConnection 'connections' =
    if (!empty(aiSearchName)) {
      name: 'search-connection'
      properties: {
        category: 'CognitiveSearch'
        authType: 'ApiKey'
        isSharedToAll: true
        target: 'https://${search.name}.search.windows.net/'
        credentials: {
          key: !empty(aiSearchName) ? search.listAdminKeys().primaryKey : ''
        }
      }
    }
}

resource openAi 'Microsoft.CognitiveServices/accounts@2023-05-01' existing = {
  name: openAiName
}

resource search 'Microsoft.Search/searchServices@2021-04-01-preview' existing =
  if (!empty(aiSearchName)) {
    name: aiSearchName
  }

output name string = hub.name
output id string = hub.id
output principalId string = hub.identity.principalId
