targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
@allowed(['australiaeast', 'eastus', 'eastus2', 'francecentral', 'norwayeast', 'swedencentral', 'uksouth'])
param location string

@description('The Azure resource group where new resources will be deployed')
param resourceGroupName string = ''
@description('The Azure AI Studio Hub resource name. If ommited will be generated')
param aiHubName string = ''
@description('The Azure AI Studio project name. If ommited will be generated')
param aiProjectName string = ''
@description('The application insights resource name. If ommited will be generated')
param appInsightsName string = ''
@description('The Open AI resource name. If ommited will be generated')
param openAiName string = ''
@description('The name of the OpenAI deployment for the assistant')
param openAiChatDeploymentName string = ''
@description('The version of the OpenAI deployment for the assistant')
param openAiChatDeploymentVersion string = ''
@description('The name of the OpenAI deployment for the evaluation')
param openAiEvaluationDeploymentName string = ''
@description('The version of the OpenAI deployment for the evaluation')
param openAiEvaluationDeploymentVersion string = ''
@description('The Azure Container Registry resource name. If ommited will be generated')
param containerRegistryName string = ''
@description('The Azure Key Vault resource name. If ommited will be generated')
param keyVaultName string = ''
@description('The Azure Storage Account resource name. If ommited will be generated')
param storageAccountName string = ''
@description('The log analytics workspace name. If ommited will be generated')
param logAnalyticsWorkspaceName string = ''
@description('The name of the machine learning online endpoint. If ommited will be generated')
param endpointName string = ''
@description('Id of the user or app to assign application roles')
param principalId string = ''
@description('The name of the azd service to use for the machine learning endpoint')
param endpointServiceName string = 'chat'

param useContainerRegistry bool = true
param useAppInsights bool = true

var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = { 'azd-env-name': environmentName }

// Organize resources in a resource group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

module ai 'core/host/ai-environment.bicep' = {
  name: 'ai'
  scope: rg
  params: {
    location: location
    tags: tags
    hubName: !empty(aiHubName) ? aiHubName : 'ai-hub-${resourceToken}'
    projectName: !empty(aiProjectName) ? aiProjectName : 'ai-project-${resourceToken}'
    keyVaultName: !empty(keyVaultName) ? keyVaultName : '${abbrs.keyVaultVaults}${resourceToken}'
    storageAccountName: !empty(storageAccountName)
      ? storageAccountName
      : '${abbrs.storageStorageAccounts}${resourceToken}'
    openAiName: !empty(openAiName) ? openAiName : 'aoai-${resourceToken}'
    openAiModelDeployments:  [
      {
        name: openAiChatDeploymentName
        model: {
          format: 'OpenAI'
          name: 'gpt-35-turbo'
          version: openAiChatDeploymentVersion // use this version for Assistant API to work
        }
        sku: {
          name: 'Standard'
          capacity: 30
        }
      }
      {
        name: openAiEvaluationDeploymentName
        model: {
          format: 'OpenAI'
          name: 'gpt-35-turbo'
          version: openAiEvaluationDeploymentVersion // use this version for the evaluation API
        }
        sku: {
          name: 'Standard'
          capacity: 30
        }
      }
    ]
    logAnalyticsName: !useAppInsights
      ? ''
      : !empty(logAnalyticsWorkspaceName)
          ? logAnalyticsWorkspaceName
          : '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
    appInsightsName: !useAppInsights
      ? ''
      : !empty(appInsightsName) ? appInsightsName : '${abbrs.insightsComponents}${resourceToken}'
    containerRegistryName: !useContainerRegistry
      ? ''
      : !empty(containerRegistryName) ? containerRegistryName : '${abbrs.containerRegistryRegistries}${resourceToken}'    
  }
}

module machineLearningEndpoint './core/host/ml-online-endpoint.bicep' = {
  name: 'endpoint'
  scope: rg
  params: {
    name: !empty(endpointName) ? endpointName : 'mloe-${resourceToken}'
    location: location
    tags: tags
    serviceName: endpointServiceName
    aiHubName: ai.outputs.hubName
    aiProjectName: ai.outputs.projectName
    keyVaultName: ai.outputs.keyVaultName
  }
}

module keyVaultAccess 'core/security/keyvault-access.bicep' = {
  name: 'keyvault-access'
  scope: rg
  params: {
    keyVaultName: ai.outputs.keyVaultName
    principalId: ai.outputs.projectPrincipalId
  }
}

module userAcrRolePush 'core/security/role.bicep' = {
  name: 'user-acr-role-push'
  scope: rg
  params: {
    principalId: principalId
    roleDefinitionId: '8311e382-0749-4cb8-b61a-304f252e45ec'
    principalType: 'User'
  }
}

module userAcrRolePull 'core/security/role.bicep' = {
  name: 'user-acr-role-pull'
  scope: rg
  params: {
    principalId: principalId
    roleDefinitionId: '7f951dda-4ed3-4680-a7ca-43fe172d538d'
    principalType: 'User'
  }
}

module userRoleDataScientist 'core/security/role.bicep' = {
  name: 'user-role-data-scientist'
  scope: rg
  params: {
    principalId: principalId
    roleDefinitionId: 'f6c7c914-8db3-469d-8ca1-694a8f32e121'
    principalType: 'User'
  }
}

module userRoleSecretsReader 'core/security/role.bicep' = {
  name: 'user-role-secrets-reader'
  scope: rg
  params: {
    principalId: principalId
    roleDefinitionId: 'ea01e6af-a1c1-4350-9563-ad00f8c72ec5'
    principalType: 'User'
  }
}

module userCognitiveServicesOpenAIContributor 'core/security/role.bicep' = {
  name: 'user-cognitive-services-openAI-contributor'
  scope: rg
  params: {
    principalId: principalId
    roleDefinitionId: 'a001fd3d-188f-4b5d-821b-7da978bf7442'
    principalType: 'User'
  }
}

module endpointCognitiveServicesOpenAIContributor 'core/security/role.bicep' = {
  name: 'endpoint-cognitive-services-openAI-contributor'
  scope: rg
  params: {
    principalId: machineLearningEndpoint.outputs.principalId
    roleDefinitionId: 'a001fd3d-188f-4b5d-821b-7da978bf7442'
    principalType: 'ServicePrincipal'
  }
}

module mlServiceRoleDataScientist 'core/security/role.bicep' = {
  name: 'ml-service-role-data-scientist'
  scope: rg
  params: {
    principalId: ai.outputs.projectPrincipalId
    roleDefinitionId: 'f6c7c914-8db3-469d-8ca1-694a8f32e121'
    principalType: 'ServicePrincipal'
  }
}

module mlServiceRoleSecretsReader 'core/security/role.bicep' = {
  name: 'ml-service-role-secrets-reader'
  scope: rg
  params: {
    principalId: ai.outputs.projectPrincipalId
    roleDefinitionId: 'ea01e6af-a1c1-4350-9563-ad00f8c72ec5'
    principalType: 'ServicePrincipal'
  }
}

// output the names of the resources
output AZURE_TENANT_ID string = tenant().tenantId
output AZURE_RESOURCE_GROUP string = rg.name

output AZUREAI_HUB_NAME string = ai.outputs.hubName
output AZUREAI_PROJECT_NAME string = ai.outputs.projectName
output AZUREAI_ENDPOINT_NAME string = machineLearningEndpoint.outputs.name

output AZURE_OPENAI_NAME string = ai.outputs.openAiName
output AZURE_OPENAI_ENDPOINT string = ai.outputs.openAiEndpoint
output AZURE_OPENAI_CHAT_DEPLOYMENT string = openAiChatDeploymentName
output AZURE_OPENAI_EVALUATION_DEPLOYMENT string = openAiEvaluationDeploymentName

output AZURE_CONTAINER_REGISTRY_NAME string = ai.outputs.containerRegistryName
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = ai.outputs.containerRegistryEndpoint

output AZURE_KEYVAULT_NAME string = ai.outputs.keyVaultName
output AZURE_KEYVAULT_ENDPOINT string = ai.outputs.keyVaultEndpoint

output AZURE_STORAGE_ACCOUNT_NAME string = ai.outputs.storageAccountName
output AZURE_STORAGE_ACCOUNT_ENDPOINT string = ai.outputs.storageAccountName

output AZURE_APP_INSIGHTS_NAME string = ai.outputs.appInsightsName
output AZURE_LOG_ANALYTICS_WORKSPACE_NAME string = ai.outputs.logAnalyticsWorkspaceName
