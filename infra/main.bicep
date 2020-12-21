param location string = resourceGroup().location
param prefix string = 'azdefender'
param password string { 
  secure: true 
}

param spSqlEncryptObjectId string {
  metadata: {
    description: 'AAD object ID for identity used for SQL Always Encrypted'
  }
}
param spSqlEncryptClientId string {
  metadata: {
    description: 'AAD client ID for identity used for SQL Always Encrypted'
  }
}
param spSqlEncryptClientSecret string {
  metadata: {
    description: 'AAD client secret for identity used for SQL Always Encrypted'
  }
  secure: true
}

param adminObjectId string {
  metadata: {
    description: 'AAD object ID for admin user identity'
  }
}
param email string {
  metadata: {
    description: 'Email to send alerts both to and from (send to self)'
  }
}

var adminUsername = 'tomas'
var fdName = '${prefix}-${uniqueString(resourceGroup().id)}'

// Network infrastructure
resource vnet 'Microsoft.Network/virtualnetworks@2015-05-01-preview' = {
  name: 'mynet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes:[
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'apps'
        properties: {
          addressPrefix: '10.0.0.0/24'
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: '10.0.1.0/24'
        }
      }
    ]
  }
}

resource bastionIp 'Microsoft.Network/publicIPAddresses@2020-06-01' = {
  name: '${prefix}-bastion-ip'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource bastionHost 'Microsoft.Network/bastionHosts@2020-06-01' = {
  name: '${prefix}-bastion'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'IpConf'
        properties: {
          subnet: {
            id: '${vnet.id}/subnets/AzureBastionSubnet'
          }
          publicIPAddress: {
            id: bastionIp.id
          }
        }
      }
    ]
  }
}

resource frontDoor 'Microsoft.Network/frontDoors@2020-05-01' = {
  name: fdName
  location: 'global'
  properties: {
    routingRules: [
      {
        name: 'routingRule1'
        properties: {
          frontendEndpoints: [
            {
              id: resourceId('Microsoft.Network/frontDoors/frontendEndpoints', fdName, 'frontendEndpoint1')
            }
          ]
          acceptedProtocols: [
            'Http'
            'Https'
          ]
          patternsToMatch: [
            '/*'
          ]
          routeConfiguration: {
            '@odata.type': '#Microsoft.Azure.FrontDoor.Models.FrontdoorForwardingConfiguration'
            forwardingProtocol: 'HttpOnly'
            backendPool: {
              id: resourceId('Microsoft.Network/frontDoors/backendPools', fdName, 'backendPool1')
            }
          }
          enabledState: 'Enabled'
        }
      }
    ]
    healthProbeSettings: [
      {
        name: 'healthProbeSettings1'
        properties: {
          path: '/'
          protocol: 'Http'
          intervalInSeconds: 120
        }
      }
    ]
    loadBalancingSettings: [
      {
        name: 'loadBalancingSettings1'
        properties: {
          sampleSize: 4
          successfulSamplesRequired: 2
        }
      }
    ]
    backendPools: [
      {
        name: 'backendPool1'
        properties: {
          backends: [
            {
              address: vmIp.properties.dnsSettings.fqdn
              backendHostHeader: vmIp.properties.dnsSettings.fqdn
              httpPort: 80
              httpsPort: 443
              weight: 50
              priority: 1
              enabledState: 'Enabled'
            }
          ]
          loadBalancingSettings: {
            id: resourceId('Microsoft.Network/frontDoors/loadBalancingSettings', fdName, 'loadBalancingSettings1')
          }
          healthProbeSettings: {
            id: resourceId('Microsoft.Network/frontDoors/healthProbeSettings', fdName, 'healthProbeSettings1')
          }
        }
      }
    ]
    frontendEndpoints: [
      {
        name: 'frontendEndpoint1'
        properties: {
          hostName: '${fdName}.azurefd.net'
          sessionAffinityEnabledState: 'Disabled'
          webApplicationFirewallPolicyLink: {
            id: wafPolicy.id
          }
        }
      }
    ]
    enabledState: 'Enabled'
  }
}

resource frontDoorDiagnostics 'Microsoft.Network/frontDoors/providers/diagnosticSettings@2017-05-01-preview' = {
  name: '${frontDoor.name}/Microsoft.Insights/service'
  properties: {
    workspaceId: workspace.id
    logs: [
      {
        category: 'FrontdoorWebApplicationFirewallLog'
        enabled: true
        retentionPolicy: {
          days: 14
          enabled: true
        }
      }
      {
        category: 'FrontdoorAccessLog'
        enabled: true
        retentionPolicy: {
          days: 14
          enabled: true
        }
      }
    ]
    metrics: []
  }
}

resource wafPolicy 'Microsoft.Network/frontDoorWebApplicationFirewallPolicies@2020-04-01' = {
  name: 'wafpolicy'
  location: 'global'
  tags: {}
  properties: {
    policySettings: {
      enabledState: 'Enabled'
      mode: 'Prevention'
      customBlockResponseStatusCode: 403
      customBlockResponseBody: 'VGFrIHRha2hsZSBuZSwga2FtbyE='
    }
    customRules: {
      rules: []
    }
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: 'DefaultRuleSet'
          ruleSetVersion: '1.0'
          ruleGroupOverrides: []
          exclusions: []
        }
      ]
    }
  }
}

// Identity and RBAC
resource vmIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: 'vmIdentity'
  location: location
}

resource automationIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: 'automationIdentity'
  location: location
}

resource sqlLoginIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: 'sqlLoginIdentity'
  location: location
}

resource rbacAutomationContributor 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(resourceGroup().id, 'contributor')
  properties:{
    roleDefinitionId: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c'
    principalId: reference('automationIdentity').principalId
  }
}

resource rbacAutomationDataContributor 'Microsoft.Authorization/roleAssignments@2018-09-01-preview' = {
  name: guid(resourceGroup().id, 'dataContributor')
  properties: {
    roleDefinitionId: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/ba92f5b4-2d11-453d-a403-e96b0029c9fe'
    principalId: reference('automationIdentity').principalId
  }
}

// Compute infrastructure
resource appsNsg 'Microsoft.Network/networkSecurityGroups@2020-06-01' = {
  name: '${prefix}-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'web'
        properties: {
          priority: 200
          sourceAddressPrefix: '*'
          protocol: 'Tcp'
          destinationPortRanges: [
            '80'
            '443'
          ]
          access: 'Allow'
          direction: 'Inbound'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource vmIp 'Microsoft.Network/publicIPAddresses@2019-11-01' = {
  name: '${prefix}-vm-ip'
  location: resourceGroup().location
  properties: {
    publicIPAllocationMethod: 'Dynamic'
    dnsSettings: {
      domainNameLabel: '${prefix}-ip-${uniqueString(resourceGroup().id)}'
    }
  }
}

resource vmNic 'Microsoft.Network/networkInterfaces@2020-06-01' = {
  name: '${prefix}-vm-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: '${vnet.id}/subnets/apps'
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: vmIp.id
          }
        }
      }
    ]
    networkSecurityGroup: {
      id: appsNsg.id
    }
  }
}

resource vmLinuxNic 'Microsoft.Network/networkInterfaces@2020-06-01' = {
  name: '${prefix}-linux-vm-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: '${vnet.id}/subnets/apps'
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
    networkSecurityGroup: {
      id: appsNsg.id
    }
  }
}


resource vm 'Microsoft.Compute/virtualMachines@2020-06-01' = {
  name: '${prefix}-vm'
  location: location
  identity:{
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${vmIdentity.id}': {}
    }
  }
  properties: {
    osProfile: {
      computerName: 'win1-vm'
      adminUsername: adminUsername
      adminPassword: password
    }
    hardwareProfile: {
      vmSize: 'Standard_B2ms'
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2016-Datacenter'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
      }
      dataDisks: []
    }
    networkProfile: {
      networkInterfaces: [
        {
          properties: {
            primary: true
          }
          id: vmNic.id
        }
      ]
    }
  }
}

resource vmExtensionMonitoringAgent 'Microsoft.Compute/virtualMachines/extensions@2020-06-01' = {
  name: '${vm.name}/Microsoft.EnterpriseCloud.Monitoring'
  location: location
  properties: {
    publisher: 'Microsoft.EnterpriseCloud.Monitoring'
    type: 'MicrosoftMonitoringAgent'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    settings: {
      workspaceId: workspace.properties.customerId
    }
    protectedSettings: {
      workspaceKey: listKeys(workspace.id, '2015-03-20').primarySharedKey
    }
  }
}

resource vmExtensionDependencyAgent 'Microsoft.Compute/virtualMachines/extensions@2020-06-01' = {
  name: '${vm.name}/DAExtension'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Monitoring.DependencyAgent'
    type: 'DependencyAgentWindows'
    typeHandlerVersion: '9.5'
    autoUpgradeMinorVersion: true
  }
}

resource vmExtensionInstall 'Microsoft.Compute/virtualMachines/extensions@2020-06-01' = {
  name: '${vm.name}/install'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.7'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        'https://raw.githubusercontent.com/tkubica12/azdefender-demo/master/scripts/prepareWindows.ps1'
        'https://raw.githubusercontent.com/tkubica12/azdefender-demo/master/artifacts/app.zip'
        'https://raw.githubusercontent.com/tkubica12/azdefender-demo/master/artifacts/contosoclinic.bacpac'
    ]
    }
    protectedSettings: {
      commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File prepareWindows.ps1 -sqlConnectionString "Server=tcp:${sqlServer.properties.fullyQualifiedDomainName},1433;Initial Catalog=${sqlDb.name};Persist Security Info=False;User ID=${sqlServer.properties.administratorLogin};Password=${sqlServer.properties.administratorLoginPassword};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"  -clientId ${spSqlEncryptClientId} -clientSecret ${spSqlEncryptClientSecret}'
    }
  }
}

resource vmExtensionSecurity 'Microsoft.Compute/virtualMachines/providers/serverVulnerabilityAssessments@2015-06-01-preview' = {
  name: '${vm.name}/Microsoft.Security/default'
}

resource vmLinux 'Microsoft.Compute/virtualMachines@2019-07-01' = {
  name: '${prefix}-linux-vm'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${vmIdentity.id}': {}
    }
  }
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B1ms'
    }
    osProfile: {
      computerName: 'lin1-vm'
      adminUsername: adminUsername
      adminPassword: password
      customData: 'I2Nsb3VkLWNvbmZpZwpwYWNrYWdlczoKLSB1YnVudHUtZGVza3RvcAotIG5tYXAKLSBvcGVudnBuCi0gZnJlZXJkcC14MTEKLSB0aWdlcnZuYy12aWV3ZXIKLSBweXRob24zCi0gcHl0aG9uMy1waXAKcnVuY21kOgogLSBta2RpciAvc2NyaXB0cwogLSBjZCAvc2NyaXB0cwogLSB3Z2V0IGh0dHBzOi8vcmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbS90a3ViaWNhMTIvYXpkZWZlbmRlci1kZW1vL21hc3Rlci9zY3JpcHRzL2luZnJhQXR0YWNrU2ltdWxhdGlvbkZyb21MaW51eC5zaA=='
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: 'UbuntuServer'
        sku: '18.04-LTS'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: vmLinuxNic.id
        }
      ]
    }
  }
}

resource vmLinuxExtensionMonitoringAgent 'Microsoft.Compute/virtualMachines/extensions@2018-06-01' = {
  name: '${vmLinux.name}/OMSExtension'
  location: location
  properties: {
    publisher: 'Microsoft.EnterpriseCloud.Monitoring'
    type: 'OmsAgentForLinux'
    typeHandlerVersion: '1.13'
    autoUpgradeMinorVersion: true
    settings: {
      workspaceId: workspace.properties.customerId
    }
    protectedSettings: {
      workspaceKey: listKeys(workspace.id, '2015-03-20').primarySharedKey
    }
  }
}

resource vmLinuxExtensionDependencyAgent 'Microsoft.Compute/virtualMachines/extensions@2015-06-15' = {
  name: '${vmLinux.name}/DAExtension'
  location: resourceGroup().location
  properties: {
    publisher: 'Microsoft.Azure.Monitoring.DependencyAgent'
    type: 'DependencyAgentLinux'
    typeHandlerVersion: '9.5'
    autoUpgradeMinorVersion: true
  }
}

resource vmLinuxExtensionSecurity 'Microsoft.Compute/virtualMachines/providers/serverVulnerabilityAssessments@2015-06-01-preview' = {
  name: '${vmLinux.name}/Microsoft.Security/default'
}


// Storage
resource storage 'Microsoft.Storage/storageAccounts@2019-06-01' = {
  name: uniqueString(resourceGroup().id)
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
}

resource storageSecurity 'Microsoft.Storage/storageAccounts/providers/advancedThreatProtectionSettings@2019-01-01' = {
  name: '${storage.name}/Microsoft.Security/current'
  properties: {
    isEnabled: true
  }
}

resource uploadMalwareToStorage 'Microsoft.Resources/deploymentScripts@2019-10-01-preview' = {
  name: 'uploadMalwareToStorage'
  location: resourceGroup().location
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${automationIdentity.id}': {}
    }
  }
  properties: {
    forceUpdateTag: 'onceOnly'
    azCliVersion: '2.9.1'
    timeout: 'PT30M'
    arguments: '${resourceGroup().name}, ${storage.name}'
    scriptContent: 'az storage container create -n app-data --auth-mode login --account-name $2 -g $1; echo \'X5O!P%@AP[4\\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*\' > ./EICAR.com; az storage blob upload --auth-mode login --account-name $2 --container-name app-data -f ./EICAR.com -n EICAR.com'
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'PT1H'
  }
  dependsOn: [
    rbacAutomationContributor
    rbacAutomationDataContributor
  ]
}


// SQL
resource sqlServer 'Microsoft.Sql/servers@2019-06-01-preview' = {
  name: '${prefix}-sql-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    administratorLogin: adminUsername
    administratorLoginPassword: password
  }
}

resource sqlFirewallAzureServices 'Microsoft.Sql/servers/firewallRules@2014-04-01' = {
  name: '${sqlServer.name}/AllowAllWindowsAzureIps'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

resource sqlFirewallAll 'Microsoft.Sql/servers/firewallRules@2014-04-01' = {
  name: '${sqlServer.name}/all'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '255.255.255.255'
  }
}

resource sqlAuditSettings 'Microsoft.Sql/servers/auditingSettings@2017-03-01-preview' = {
  name: '${sqlServer.name}/defaultAuditingSettings'
  properties: {
    state: 'Enabled'
    isAzureMonitorTargetEnabled: true
  }
}

resource sqlAlertPolicies 'Microsoft.Sql/servers/securityAlertPolicies@2020-02-02-preview' = {
  name: '${sqlServer.name}/default'
  properties: {
    state: 'Enabled'
  }
}

resource sqlVulnerabilityAssessments 'Microsoft.Sql/servers/vulnerabilityAssessments@2018-06-01-preview' = {
  name: '${sqlServer.name}/Default'
  properties: {
    storageContainerPath: 'https://${storage.name}, .blob.core.windows.net/vulnerability-assessment/'
    recurringScans: {
      isEnabled: true
      emailSubscriptionAdmins: false
      emails: []
    }
  }
}

resource sqlAdministrators 'Microsoft.Sql/servers/administrators@2019-06-01-preview' = {
  name: '${sqlServer.name}/ActiveDirectory'
  properties: {
    administratorType: 'ActiveDirectory'
    login: 'sqlLoginIdentity'
    sid: sqlLoginIdentity.properties.principalId
    tenantId: subscription().tenantId
  }
}

resource sqlDb 'Microsoft.Sql/servers/databases@2020-08-01-preview' = {
  name: '${sqlServer.name}/sqldb'
  location: location
  sku: {
    name: 'GP_S_Gen5'
    tier: 'GeneralPurpose'
    family: 'Gen5'
    capacity: 2
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: 1073741824
    catalogCollation: 'SQL_Latin1_General_CP1_CI_AS'
    zoneRedundant: false
    readScale: 'Disabled'
    autoPauseDelay: 60
    storageAccountType: 'GRS'
    minCapacity: 0
  }
}

resource sqlDbAlertPolicies 'Microsoft.Sql/servers/databases/securityAlertPolicies@2020-02-02-preview' = {
  name: '${sqlServer.name}/${sqlDb.name}/default'
  properties: {
    state: 'Enabled'
  }
}

resource sqlTde 'Microsoft.Sql/servers/databases/transparentDataEncryption@2014-04-01' = {
  name: '${sqlServer.name}/${sqlDb.name}/current'
  properties: {
    status: 'Disabled'
  }
}

resource sqlDbVulnerabilityAssessments 'Microsoft.Sql/servers/databases/vulnerabilityAssessments@2017-03-01-preview' = {
  name: '${sqlServer.name}/${sqlDb.name}/Default'
  properties: {
    storageContainerPath: 'https://${storage.name}, .blob.core.windows.net/vulnerability-assessment/'
    recurringScans: {
      isEnabled: true
      emailSubscriptionAdmins: false
      emails: []
    }
  }
}

resource sqlDbAuditSettings 'Microsoft.Sql/servers/databases/auditingSettings@2017-03-01-preview' = {
  name: '${sqlServer.name}/${sqlDb.name}/defaultAuditingSettings'
  properties: {
    state: 'Enabled'
    isAzureMonitorTargetEnabled: true
    retentionDays: 0
    auditActionsAndGroups: [
      'SUCCESSFUL_DATABASE_AUTHENTICATION_GROUP'
      'FAILED_DATABASE_AUTHENTICATION_GROUP'
      'BATCH_COMPLETED_GROUP'
    ]
  }
}

resource sqlDbDiagnostics 'Microsoft.Sql/servers/databases/providers/diagnosticSettings@2017-05-01-preview' = {
  name: '${sqlServer.name}/${sqlDb.name}/Microsoft.Insights/service'
  properties: {
    workspaceId: workspace.id
    logs: [
      {
        category: 'QueryStoreRuntimeStatistics'
        enabled: true
        retentionPolicy: {
          days: 14
          enabled: true
        }
      }
      {
        category: 'QueryStoreWaitStatistics'
        enabled: true
        retentionPolicy: {
          days: 14
          enabled: true
        }
      }
      {
        category: 'Errors'
        enabled: true
        retentionPolicy: {
          days: 14
          enabled: true
        }
      }
      {
        category: 'DatabaseWaitStatistics'
        enabled: true
        retentionPolicy: {
          days: 14
          enabled: true
        }
      }
      {
        category: 'Timeouts'
        enabled: true
        retentionPolicy: {
          days: 14
          enabled: true
        }
      }
      {
        category: 'Blocks'
        enabled: true
        retentionPolicy: {
          days: 14
          enabled: true
        }
      }
      {
        category: 'SQLInsights'
        enabled: true
        retentionPolicy: {
          days: 14
          enabled: true
        }
      }
      {
        category: 'SQLSecurityAuditEvents'
        enabled: true
        retentionPolicy: {
          days: 14
          enabled: false
        }
      }
    ]
    metrics: [
      {
        timeGrain: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 14
        }
      }
    ]
  }
}


// Monitoring
resource workspace 'Microsoft.OperationalInsights/workspaces@2020-08-01' = {
  name: adminUsername
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
  }
}

resource workspaceName_syslogCollection 'Microsoft.OperationalInsights/workspaces/dataSources@2020-03-01-preview' = {
  name: '${workspace.name}/syslogCollection'
  kind: 'LinuxSyslogCollection'
  properties: {
    state: 'Enabled'
  }
}

resource workspaceName_SyslogKern 'Microsoft.OperationalInsights/workspaces/datasources@2020-08-01' = {
  name: '${workspace.name}/SyslogKern'
  kind: 'LinuxSyslog'
  properties: {
    syslogName: 'kern'
    syslogSeverities: [
      {
        severity: 'emerg'
      }
      {
        severity: 'alert'
      }
      {
        severity: 'crit'
      }
      {
        severity: 'err'
      }
      {
        severity: 'warning'
      }
      {
        severity: 'notice'
      }
      {
        severity: 'info'
      }
      {
        severity: 'debug'
      }
    ]
  }
}

resource workspaceName_SyslogDaemon 'Microsoft.OperationalInsights/workspaces/datasources@2020-08-01' = {
  name: '${workspace.name}/SyslogDaemon'
  kind: 'LinuxSyslog'
  properties: {
    syslogName: 'daemon'
    syslogSeverities: [
      {
        severity: 'emerg'
      }
      {
        severity: 'alert'
      }
      {
        severity: 'crit'
      }
      {
        severity: 'err'
      }
      {
        severity: 'warning'
      }
    ]
  }
}

resource workspaceName_WindowsEventApp 'Microsoft.OperationalInsights/workspaces/dataSources@2020-03-01-preview' = {
  name: '${workspace.name}/WindowsEventApp'
  kind: 'WindowsEvent'
  properties: {
    eventLogName: 'Application'
    eventTypes: [
      {
        eventType: 'Error'
      }
      {
        eventType: 'Warning'
      }
      {
        eventType: 'Information'
      }
    ]
  }
}

resource workspaceName_WindowsEventSystem 'Microsoft.OperationalInsights/workspaces/dataSources@2020-03-01-preview' = {
  name: '${workspace.name}/WindowsEventSystem'
  kind: 'WindowsEvent'
  properties: {
    eventLogName: 'System'
    eventTypes: [
      {
        eventType: 'Error'
      }
      {
        eventType: 'Warning'
      }
      {
        eventType: 'Information'
      }
    ]
  }
}

resource workspaceName_subscriptionId 'Microsoft.OperationalInsights/workspaces/dataSources@2020-03-01-preview' = {
  name: '${workspace.name}/${replace(subscription().subscriptionId, '-', '')}'
  kind: 'AzureActivityLog'
  properties: {
    linkedResourceId: '/subscriptions/${subscription().subscriptionId}/providers/microsoft.insights/eventtypes/management'
  }
}

resource workspaceName_SecurityEventCollectionConfiguration 'Microsoft.OperationalInsights/workspaces/dataSources@2020-03-01-preview' = {
  name: '${workspace.name}/SecurityEventCollectionConfiguration'
  kind: 'SecurityEventCollectionConfiguration'
  properties: {
    tier: 'All'
    tierSetMethod: 'Custom'
  }
}

resource SecurityInsights_workspaceName 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = {
  name: 'SecurityInsights(${workspace.name})'
  location: resourceGroup().location
  properties: {
    workspaceResourceId: workspace.id
  }
  plan: {
    name: 'SecurityInsights(${workspace.name})'
    product: 'OMSGallery/SecurityInsights'
    publisher: 'Microsoft'
    promotionCode: ''
  }
}

resource SecurityCenterFree_workspaceName 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = {
  name: 'SecurityCenterFree(${workspace.name})'
  location: resourceGroup().location
  properties: {
    workspaceResourceId: workspace.id
  }
  plan: {
    name: 'SecurityCenterFree(${workspace.name})'
    product: 'OMSGallery/SecurityCenterFree'
    publisher: 'Microsoft'
    promotionCode: ''
  }
}

resource Security_workspaceName 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = {
  name: 'Security(${workspace.name})'
  location: resourceGroup().location
  properties: {
    workspaceResourceId: workspace.id
  }
  plan: {
    name: 'Security(${workspace.name})'
    product: 'OMSGallery/Security'
    publisher: 'Microsoft'
    promotionCode: ''
  }
}

resource SQLAdvancedThreatProtection_workspaceName 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = {
  name: 'SQLAdvancedThreatProtection(${workspace.name})'
  location: resourceGroup().location
  properties: {
    workspaceResourceId: workspace.id
  }
  plan: {
    name: 'SQLAdvancedThreatProtection(${workspace.name})'
    product: 'OMSGallery/SQLAdvancedThreatProtection'
    publisher: 'Microsoft'
    promotionCode: ''
  }
}

resource SQLVulnerabilityAssessment_workspaceName 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = {
  name: 'SQLVulnerabilityAssessment(${workspace.name})'
  location: location
  properties: {
    workspaceResourceId: workspace.id
  }
  plan: {
    name: 'SQLVulnerabilityAssessment(${workspace.name})'
    product: 'OMSGallery/SQLVulnerabilityAssessment'
    publisher: 'Microsoft'
    promotionCode: ''
  }
}

resource SQLAuditing_workspaceName 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = {
  name: 'SQLAuditing[${workspace.name}]'
  location: location
  plan: {
    name: 'SQLAuditing[${workspace.name}]'
    promotionCode: ''
    product: 'SQLAuditing'
    publisher: 'Microsoft'
  }
  properties: {
    workspaceResourceId: workspace.id
    containedResources: [
      '${workspace.id}/views/SQLSecurityInsights'
      '${workspace.id}/views/SQLAccessToSensitiveData'
    ]
    referencedResources: []
  }
}

resource VMInsights_workspaceName 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = {
  name: 'VMInsights(${workspace.name})'
  location: resourceGroup().location
  properties: {
    workspaceResourceId: workspace.id
  }
  plan: {
    name: 'VMInsights(${workspace.name})'
    product: 'OMSGallery/VMInsights'
    publisher: 'Microsoft'
    promotionCode: ''
  }
}

resource WindowsFirewall_workspaceName 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = {
  name: 'WindowsFirewall(${workspace.name})'
  location: resourceGroup().location
  properties: {
    workspaceResourceId: workspace.id
  }
  plan: {
    name: 'WindowsFirewall(${workspace.name})'
    product: 'OMSGallery/WindowsFirewall'
    publisher: 'Microsoft'
    promotionCode: ''
  }
} 

// Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2016-10-01' = {
  name: 'kv${uniqueString(resourceGroup().id)}'
  location: resourceGroup().location
  properties: {
    enabledForDeployment: true
    enabledForTemplateDeployment: true
    enabledForDiskEncryption: true
    tenantId: subscription().tenantId
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: adminObjectId
        permissions: {
          keys: [
            'get'
            'list'
            'update'
            'create'
            'import'
            'delete'
            'recover'
            'backup'
            'restore'
            'decrypt'
            'encrypt'
            'unwrapKey'
            'wrapKey'
            'verify'
            'sign'
            'purge'
          ]
          secrets: [
            'get'
            'list'
            'set'
            'delete'
            'recover'
            'backup'
            'restore'
            'purge'
          ]
          certificates: [
            'get'
            'list'
            'update'
            'create'
            'import'
            'delete'
            'recover'
            'Backup'
            'Restore'
            'managecontacts'
            'manageissuers'
            'getissuers'
            'listissuers'
            'setissuers'
            'deleteissuers'
            'purge'
          ]
        }
      }
      {
        tenantId: subscription().tenantId
        objectId: spSqlEncryptObjectId
        permissions: {
          keys: [
            'get'
            'list'
            'unwrapKey'
            'wrapKey'
            'verify'
            'sign'
          ]
          secrets: []
          certificates: []
        }
      }
      {
        tenantId: subscription().tenantId
        objectId: reference('myVmIdentity').principalId
        permissions: {
          secrets: [
            'get'
            'list'
          ]
          keys: []
          certificates: []
        }
      }
    ]
    sku: {
      name: 'standard'
      family: 'A'
    }
  }
}

// Containers infra
resource registry 'Microsoft.ContainerRegistry/registries@2019-05-01' = {
  name: 'acr${uniqueString(resourceGroup().id)}'
  location: resourceGroup().location
  sku: {
    name: 'Standard'
  }
  properties: {
    adminUserEnabled: false
  }
}

resource uploadVulnerableImage 'Microsoft.Resources/deploymentScripts@2019-10-01-preview' = {
  name: 'uploadVulnerableImage'
  location: resourceGroup().location
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${automationIdentity.id}': {}
    }
  }
  properties: {
    forceUpdateTag: 'onceOnly'
    azCliVersion: '2.9.1'
    timeout: 'PT30M'
    arguments: registry.name
    scriptContent: 'az acr import --name $1 --source docker.io/library/nginx:1.7.11 --image nginx:1.7.11'
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'PT1H'
  }
  dependsOn: [
    rbacAutomationContributor
  ]
}

resource kubernetes 'Microsoft.ContainerService/managedClusters@2020-02-01' = {
  name: 'aks-${uniqueString(resourceGroup().id)}'
  location: resourceGroup().location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    dnsPrefix: 'aks-${uniqueString(resourceGroup().id)}'
    enableRBAC: true
    agentPoolProfiles: [
      {
        name: 'agentpool'
        count: 1
        vmSize: 'Standard_B2s'
        osType: 'Linux'
        storageProfile: 'ManagedDisks'
        type: 'VirtualMachineScaleSets'
        mode: 'System'
        maxPods: 110
        availabilityZones: [
          '1'
          '2'
          '3'
        ]
      }
    ]
    networkProfile: {
      loadBalancerSku: 'standard'
      networkPlugin: 'kubenet'
    }
    addonProfiles: {
      omsagent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: workspace.id
        }
      }
    }
  }
}

// Web App
resource webAppPlan 'Microsoft.Web/serverfarms@2016-09-01' = {
  name: 'webapp-plan'
  location: location
  properties: {
    name: 'webapp-plan'
    workerSizeId: '0'
    numberOfWorkers: '1'
  }
  sku: {
    tier: 'Basic'
    name: 'B1'
  }
}

resource webApp 'Microsoft.Web/sites@2018-11-01' = {
  name: 'web-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    siteConfig: {
      appSettings: [
        {
          name: 'DATABASE_HOST'
          value: 'P:DATABASEHOST:3306'
        }
        {
          name: 'PHPMYADMIN_EXTENSION_VERSION'
          value: 'latest'
        }
        {
          name: 'XDT_MicrosoftApplicationInsights_Mode'
          value: 'default'
        }
        {
          name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
          value: '~2'
        }
      ]
      phpVersion: '7.0'
      localMySqlEnabled: true
    }
    name: 'web-${uniqueString(resourceGroup().id)}'
    serverFarmId: webAppPlan.id
  }
}

resource webAppContent 'Microsoft.Web/sites/sourcecontrols@2018-11-01' = {
  name: '${webApp.name}/web'
  properties: {
    repoUrl: 'https://github.com/azureappserviceoss/wordpress-azure'
    branch: 'master'
    isManualIntegration: true
  }
}

// Logic Apps
resource azdefenderOfficeConnection 'Microsoft.Web/connections@2016-06-01' = {
  name: 'azdefenderOfficeConnection'
  location: resourceGroup().location
  properties: {
    displayName: email
    customParameterValues: {}
    api: {
      id: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Web/locations/${resourceGroup().location}/managedApis/office365'
    }
  }
}

resource azdefenderAlertsConnection 'Microsoft.Web/connections@2016-06-01' = {
  name: 'azdefenderAlertsConnection'
  location: resourceGroup().location
  properties: {
    displayName: email
    customParameterValues: {}
    api: {
      id: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Web/locations/${resourceGroup().location}/managedApis/ascalert'
    }
  }
}

resource arm 'Microsoft.Web/connections@2016-06-01' = {
  name: 'arm'
  location: resourceGroup().location
  kind: 'V1'
  properties: {
    displayName: email
    customParameterValues: {}
    api: {
      id: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Web/locations/${resourceGroup().location}/managedApis/arm'
    }
  }
}

resource ascassessment 'Microsoft.Web/connections@2016-06-01' = {
  name: 'ascassessment'
  location: resourceGroup().location
  kind: 'V1'
  properties: {
    displayName: 'Security Center Recommendation'
    customParameterValues: {}
    api: {
      id: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Web/locations/${resourceGroup().location}/managedApis/ascassessment'
    }
  }
}

resource integrationAccount 'Microsoft.Logic/IntegrationAccounts@2016-06-01' = {
  name: 'integrationAccount'
  location: resourceGroup().location
  sku: {
    name: 'Basic'
  }
  properties: {}
}

resource ascRecommendationInformUser 'Microsoft.Logic/workflows@2017-07-01' = {
  name: 'ascRecommendationInformUser'
  location: resourceGroup().location
  properties: {
    state: 'Enabled'
    integrationAccount: {
      id: integrationAccount.id
    }
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      parameters: {
        '$connections': {
          defaultValue: {}
          type: 'Object'
        }
      }
      triggers: {
        When_an_Azure_Security_Center_Recommendation_is_created_or_triggered: {
          type: 'ApiConnectionWebhook'
          inputs: {
            body: {
              callback_url: '@{listCallbackUrl()}'
            }
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'ascassessment\'][\'connectionId\']'
              }
            }
            path: '/Microsoft.Security/Assessment/subscribe'
          }
        }
      }
      actions: {
        Parse_Resource_Group: {
          runAfter: {}
          type: 'JavaScriptCode'
          inputs: {
            code: 'var text = workflowContext.trigger.outputs.body.properties.resourceDetails.id;\r\n\r\nvar match = text.match(/resourcegroups\\/([^\\/]*)/);\r\n\r\nreturn match[1];'
          }
        }
        Parse_Subscription: {
          runAfter: {
            Parse_Resource_Group: [
              'Succeeded'
            ]
          }
          type: 'JavaScriptCode'
          inputs: {
            code: 'var text = workflowContext.trigger.outputs.body.properties.resourceDetails.id;\r\n\r\nvar match = text.match(/subscriptions\\/([^\\/]*)/);\r\n\r\nreturn match[1];'
          }
        }
        Read_a_resource_group: {
          runAfter: {
            Parse_Subscription: [
              'Succeeded'
            ]
          }
          type: 'ApiConnection'
          inputs: {
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'arm\'][\'connectionId\']'
              }
            }
            method: 'get'
            path: '/subscriptions/@{encodeURIComponent(outputs(\'Parse_Subscription\')?[\'body\'])}/resourcegroups/@{encodeURIComponent(outputs(\'Parse_Resource_Group\')?[\'body\'])}'
            queries: {
              'x-ms-api-version': '2016-06-01'
            }
          }
        }
        'Send_an_email_(V2)': {
          runAfter: {
            Read_a_resource_group: [
              'Succeeded'
            ]
          }
          type: 'ApiConnection'
          inputs: {
            body: {
              Body: '<p>You have been identified as owner of resource @{triggerBody()?[\'properties\']?[\'resourceDetails\']?[\'id\']}<br>\n<br>\n<strong>Recommendation is:</strong><br>\n@{triggerBody()?[\'properties\']?[\'metadata\']?[\'displayName\']}<br>\n<br>\n@{triggerBody()?[\'properties\']?[\'metadata\']?[\'description\']}<br>\n<br>\n<strong>To remediate:</strong><br>\n@{triggerBody()?[\'properties\']?[\'metadata\']?[\'remediationDescription\']}</p>'
              Subject: 'Security Recommendation'
              To: '@{body(\'Read_a_resource_group\')?[\'tags\'][\'Owner\']}'
            }
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'azdefenderOfficeConnection\'][\'connectionId\']'
              }
            }
            method: 'post'
            path: '/v2/Mail'
          }
        }
      }
      outputs: {}
    }
    parameters: {
      '$connections': {
        value: {
          arm: {
            connectionId: arm.id
            connectionName: 'arm'
            id: '/subscriptions/a0f4a733-4fce-4d49-b8a8-d30541fc1b45/providers/Microsoft.Web/locations/westeurope/managedApis/arm'
          }
          ascassessment: {
            connectionId: ascassessment.id
            connectionName: 'ascassessment'
            id: '/subscriptions/a0f4a733-4fce-4d49-b8a8-d30541fc1b45/providers/Microsoft.Web/locations/westeurope/managedApis/ascassessment'
          }
          office365: {
            connectionId: azdefenderOfficeConnection.id
            connectionName: 'azdefenderOfficeConnection'
            id: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Web/locations/${resourceGroup().location}/managedApis/office365'
          }
        }
      }
    }
  }
}

resource azdefenderDeleteBlob 'Microsoft.Logic/workflows@2017-07-01' = {
  name: 'azdefenderDeleteBlob'
  location: resourceGroup().location
  tags: {
    LogicAppsCategory: 'security'
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${automationIdentity.id}': {}
    }
  }
  properties: {
    state: 'Enabled'
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      parameters: {
        '$connections': {
          defaultValue: {}
          type: 'Object'
        }
        SOCEmailAddress: {
          defaultValue: email
          type: 'String'
        }
      }
      triggers: {
        When_an_Azure_Security_Center_Alert_is_created_or_triggered: {
          type: 'ApiConnectionWebhook'
          inputs: {
            body: {
              callback_url: '@{listCallbackUrl()}'
            }
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'ascalert\'][\'connectionId\']'
              }
            }
            path: '/Microsoft.Security/Alert/subscribe'
          }
        }
      }
      actions: {
        If_request_approved: {
          actions: {
            Delete_Blob: {
              runAfter: {}
              type: 'Http'
              inputs: {
                authentication: {
                  audience: 'https://@{triggerBody()?[\'CompromisedEntity\']}.blob.core.windows.net/'
                  type: 'ManagedServiceIdentity'
                  identity: automationIdentity.id
                }
                headers: {
                  'x-ms-version': '2019-07-07'
                }
                method: 'DELETE'
                uri: '@variables(\'BlobUri\')'
              }
            }
            'Send_an_email_(V2)': {
              runAfter: {
                Delete_Blob: [
                  'Succeeded'
                ]
              }
              type: 'ApiConnection'
              inputs: {
                body: {
                  Body: '<p>You’ve successfully mitigated a potential malware attack<br>\n<br>\nBlob &nbsp;@{triggerBody()?[\'ExtendedProperties\']?[\'Blob\']} was successfully deleted following your request</p>'
                  Importance: 'High'
                  Subject: 'Blob  @{triggerBody()?[\'ExtendedProperties\']?[\'Blob\']} was successfully deleted following your request'
                  To: '@parameters(\'SOCEmailAddress\')'
                }
                host: {
                  connection: {
                    name: '@parameters(\'$connections\')[\'office365\'][\'connectionId\']'
                  }
                }
                method: 'post'
                path: '/v2/Mail'
              }
            }
          }
          runAfter: {
            Send_approval_email: [
              'Succeeded'
            ]
          }
          expression: {
            and: [
              {
                equals: [
                  '@body(\'Send_approval_email\')?[\'SelectedOption\']'
                  'Delete'
                ]
              }
            ]
          }
          type: 'If'
        }
        Initialize_Blob_Uri: {
          runAfter: {}
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'BlobUri'
                type: 'string'
                value: 'https://@{triggerBody()?[\'CompromisedEntity\']}.blob.core.windows.net/@{triggerBody()?[\'ExtendedProperties\']?[\'Container\']}/@{triggerBody()?[\'ExtendedProperties\']?[\'Blob\']}'
              }
            ]
          }
        }
        Send_approval_email: {
          runAfter: {
            Initialize_Blob_Uri: [
              'Succeeded'
            ]
          }
          type: 'ApiConnectionWebhook'
          inputs: {
            body: {
              Message: {
                Body: '<p>This email is sent by a playbook run on your subscription</p>\n<p>&nbsp;</p>\n<p>@{triggerBody()?[\'Description\']}</p>\n<p>&nbsp;</p>\n<p>Storage Account: @{triggerBody()?[\'CompromisedEntity\']}</p>\n<p>Container: @{triggerBody()?[\'ExtendedProperties\']?[\'Container\']}</p>\n<p>Blob name: @{triggerBody()?[\'ExtendedProperties\']?[\'Blob\']}</p>\n<p>Detected by: @{triggerBody()?[\'AlertType\']}</p>\n<p>&nbsp;</p>\n<a href="@{triggerBody()?[\'AlertUri\']}">More details can be found here</a>\n<p>&nbsp;</p>\nAlternatively, you can remediate this manually:\nGo to Azure Portal, and delete blob @{triggerBody()?[\'ExtendedProperties\']?[\'Blob\']}  in storage account @{triggerBody()?[\'CompromisedEntity\']}\n<p>&nbsp;</p>\n<p><strong>Delete Blob ?</strong></p>\n'
                Importance: 'High'
                Options: 'Delete, Ignore'
                Subject: 'Blob deletion request - a potential security threat on @{triggerBody()?[\'CompromisedEntity\']}'
                To: '@parameters(\'SOCEmailAddress\')'
                UseOnlyHTMLMessage: true
              }
              NotificationUrl: '@{listCallbackUrl()}'
            }
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'office365\'][\'connectionId\']'
              }
            }
            path: '/approvalmail/$subscriptions'
          }
        }
      }
      outputs: {}
    }
    parameters: {
      '$connections': {
        value: {
          ascalert: {
            connectionId: azdefenderAlertsConnection.id
            connectionName: 'azdefenderAlertsConnection'
            id: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Web/locations/${resourceGroup().location}/managedApis/ascalert'
          }
          office365: {
            connectionId: azdefenderOfficeConnection.id
            connectionName: 'azdefenderOfficeConnection'
            id: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Web/locations/${resourceGroup().location}/managedApis/office365'
          }
        }
      }
    }
  }
}

resource isolateVm 'Microsoft.Logic/workflows@2017-07-01' = {
  name: 'isolateVm'
  location: resourceGroup().location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${automationIdentity.id}': {}
    }
  }
  properties: {
    state: 'Enabled'
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      parameters: {
        '$connections': {
          defaultValue: {}
          type: 'Object'
        }
      }
      triggers: {
        When_an_Azure_Security_Center_Alert_is_created_or_triggered: {
          type: 'ApiConnectionWebhook'
          inputs: {
            body: {
              callback_url: '@{listCallbackUrl()}'
            }
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'ascalert\'][\'connectionId\']'
              }
            }
            path: '/Microsoft.Security/Alert/subscribe'
          }
        }
      }
      actions: {
        Filter_array: {
          runAfter: {
            Var_ResourceGroup: [
              'Succeeded'
            ]
          }
          type: 'Query'
          inputs: {
            from: '@triggerBody()?[\'Entities\']'
            where: '@equals(item()?[\'type\'], \'ip\')'
          }
        }
        HTTPCreateSecurityRule: {
          runAfter: {
            Var_NSGName: [
              'Succeeded'
            ]
          }
          type: 'Http'
          inputs: {
            authentication: {
              type: 'ManagedServiceIdentity'
              identity: automationIdentity.id
            }
            body: {
              properties: {
                access: 'Deny'
                destinationAddressPrefix: '*'
                destinationPortRange: '*'
                direction: 'Inbound'
                priority: 100
                protocol: '*'
                sourceAddressPrefix: '@variables(\'varattackeraddress\')'
                sourcePortRange: '*'
              }
            }
            method: 'PUT'
            uri: 'https://management.azure.com/subscriptions/@{variables(\'subid\')}/resourceGroups/@{variables(\'resourcegroup\')}/providers/Microsoft.Network/networkSecurityGroups/@{variables(\'nsgname\')}/securityRules/BruteforceAttackerIP?api-version=2020-05-01\n'
          }
        }
        HTTPGetNSGs: {
          runAfter: {
            Var_NetworkName: [
              'Succeeded'
            ]
          }
          type: 'Http'
          inputs: {
            authentication: {
              type: 'ManagedServiceIdentity'
              identity: automationIdentity.id
            }
            headers: {
              'api-version': '2020-05-01'
            }
            method: 'GET'
            uri: 'https://management.azure.com/subscriptions/@{variables(\'subid\')}/resourceGroups/@{variables(\'resourcegroup\')}/providers/Microsoft.Network/networkInterfaces/@{variables(\'networkname\')}?api-version=2020-05-01'
          }
        }
        HTTPGetVM: {
          runAfter: {
            Var_AttackerAddress: [
              'Succeeded'
            ]
          }
          type: 'Http'
          inputs: {
            authentication: {
              type: 'ManagedServiceIdentity'
              identity: automationIdentity.id
            }
            headers: {
              'api-version': '2019-12-01'
            }
            method: 'GET'
            uri: 'https://management.azure.com/subscriptions/@{variables(\'subid\')}/resourceGroups/@{variables(\'resourcegroup\')}/providers/Microsoft.Compute/virtualMachines/@{variables(\'hostname\')}?api-version=2019-12-01'
          }
        }
        'Send_an_email_(V2)': {
          runAfter: {
            HTTPCreateSecurityRule: [
              'Succeeded'
            ]
          }
          type: 'ApiConnection'
          inputs: {
            body: {
              Body: '<p><span style="font-size: 16px"><strong>Azure Security Center has discovered a potential security threat in your environment. Details below:</strong></span><br>\n<br>\n<strong>Alert name: </strong>@{triggerBody()?[\'AlertDisplayName\']}<br>\n<br>\n<strong>Attacked resource:</strong> @{triggerBody()?[\'CompromisedEntity\']}<br>\n<br>\n<strong>Alert severity</strong>: @{triggerBody()?[\'Severity\']}<br>\n<br>\n<strong>Detection time</strong>: @{triggerBody()?[\'TimeGenerated\']}<br>\n<br>\n<strong>Description</strong>: @{triggerBody()?[\'Description\']}<br>\n<br>\n<strong>Detected by</strong>: @{triggerBody()?[\'VendorName\']}<br>\n<br>\n<strong>Alert ID:</strong> @{triggerBody()?[\'SystemAlertId\']}<br>\n<br>\n<strong>Resource identifiers</strong>: @{variables(\'resourceid\')}<br>\n<br>\n<strong>Link to view alert in Azure Security Center</strong>: @{triggerBody()?[\'AlertUri\']}<br>\n<br>\n<strong>Attacker IPaddress</strong>: @{variables(\'varattackeraddress\')}<br>\n<br>\n<strong>Network Security Group</strong>: &nbsp;@{variables(\'nsgname\')}<br>\n&nbsp;<br>\n<span style="font-size: 16px"><strong>Powered by Azure Security Center Logic Apps alert connector</strong></span></p>'
              Importance: 'High'
              Subject: 'Azure Security Center has blocked IPs in the NSG as a response to the BruteForce Attack'
              To: email
            }
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'office365\'][\'connectionId\']'
              }
            }
            method: 'post'
            path: '/v2/Mail'
          }
        }
        Var_AttackerAddress: {
          runAfter: {
            Filter_array: [
              'Succeeded'
            ]
          }
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'varattackeraddress'
                type: 'string'
                value: '@{concat(split(triggerBody()?[\'ExtendedProperties\'][\'attacker source IP\'], \' \')[2], \'/32\')}'
              }
            ]
          }
        }
        Var_Hostname: {
          runAfter: {
            Var_SubID: [
              'Succeeded'
            ]
          }
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'hostname'
                type: 'string'
                value: '@{variables(\'resourceidarray\')?[8]}'
              }
            ]
          }
        }
        Var_NSGName: {
          runAfter: {
            HTTPGetNSGs: [
              'Succeeded'
            ]
          }
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'nsgname'
                type: 'string'
                value: '@{split(body(\'httpgetnsgs\')?[\'properties\']?[\'networkSecurityGroup\']?[\'id\'],\'/\')?[8]}'
              }
            ]
          }
        }
        Var_NetworkName: {
          runAfter: {
            HTTPGetVM: [
              'Succeeded'
            ]
          }
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'networkname'
                type: 'string'
                value: '@{split(body(\'httpGetVM\')?[\'properties\']?[\'networkProfile\']?[\'networkInterfaces\']?[0]?[\'id\'],\'/\')?[8]}'
              }
            ]
          }
        }
        Var_ResourceGroup: {
          runAfter: {
            Var_Hostname: [
              'Succeeded'
            ]
          }
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'resourcegroup'
                type: 'string'
                value: '@{variables(\'resourceidarray\')?[4]}'
              }
            ]
          }
        }
        Var_ResourceID: {
          runAfter: {}
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'resourceid'
                type: 'string'
                value: '@{triggerBody()?[\'Entities\']?[0]?[\'AzureID\']}'
              }
            ]
          }
        }
        Var_ResourceIDArray: {
          runAfter: {
            Var_ResourceID: [
              'Succeeded'
            ]
          }
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'resourceidarray'
                type: 'array'
                value: '@split(variables(\'resourceid\'),\'/\')'
              }
            ]
          }
        }
        Var_SubID: {
          runAfter: {
            Var_ResourceIDArray: [
              'Succeeded'
            ]
          }
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'subid'
                type: 'string'
                value: '@{variables(\'resourceidarray\')?[2]}'
              }
            ]
          }
        }
      }
      outputs: {}
    }
    parameters: {
      '$connections': {
        value: {
          ascalert: {
            connectionId: azdefenderAlertsConnection.id
            connectionName: 'azdefenderAlertsConnection'
            id: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Web/locations/${resourceGroup().location}/managedApis/ascalert'
          }
          office365: {
            connectionId: azdefenderOfficeConnection.id
            connectionName: 'azdefenderOfficeConnection'
            id: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Web/locations/${resourceGroup().location}/managedApis/office365'
          }
        }
      }
    }
  }
}

// Outputs
output vmDns string = vmIp.properties.dnsSettings.fqdn
output fdDns string = '${frontDoor.name}.azurefd.net'
output storageAccount string = storage.name
output keyVaultName string = keyVault.name
output sqlName string = sqlServer.name
output kubeName string = kubernetes.name