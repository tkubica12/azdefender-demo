# Azure Defender demo
This repo contains demo of Azure Defender features together with GitHub and Web Application Firewall.

## Demos
After you setup environment follow guides to demonstrate capabilities.

Demonstrate Azure Defender infrastructure and container capabilities in [guide](./infraDemo.md).

Demonstrate Azure Defender, WAF and github application protection capabilities in [guide](./appDemo.md).

## Setup
Follow guide to setup your environment.

### Identities and environment
Prepare identities and deploy environment. In future version of demo this will be replaced with managed identity.

```powershell
# Prepare AAD identities
$spSqlEncrypt = New-AzADServicePrincipal -DisplayName tomasazdefender-sql-encrypt -SkipAssignment
$spSqlLogin = New-AzADServicePrincipal -DisplayName tomasazdefender-sql-login -SkipAssignment

$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($spSqlEncrypt.Secret)
$spSqlEncryptSecret = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($spSqlLogin.Secret)
$spSqlLoginSecret = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
$spSqlEncryptAppId = $spSqlEncrypt.ApplicationId
$spSqlLoginAppId = $spSqlLogin.ApplicationId
$spSqlEncryptObjectId = $spSqlEncrypt.Id
$spSqlLoginObjectId = $spSqlLogin.Id

$currentUserUPN = $(Get-AzContext).Account
$currentUserId = $(Get-AzADUser -UserPrincipalName $(Get-AzContext).Account).Id

# Deploy infrastructure
New-AzResourceGroup -Name azdefender -Location westeurope

New-AzResourceGroupDeployment -Name azdefender-infra `
    -ResourceGroupName azdefender `
    -TemplateFile .\armInfra.json `
    -adminObjectId $currentUserId `
    -spSqlEncryptObjectId $spSqlEncryptObjectId `
    -email tokubica@microsoft.com

# Import data to SQL
New-AzResourceGroupDeployment -Name azdefender-dataimport -ResourceGroupName azdefender -TemplateFile .\armSqlDataImport.json
```

### Install script for Windows Server
ARM template automatically downloads Edge and Azure Data Studio installation files. Go to desktop and install. Also IIS is installed and application copied.

Configure application credentials.

```powershell
# Configure service principal for accesing Key Vault for encryption (spSqlEncryptAppId and spSqlEncryptSecret)
[System.Environment]::SetEnvironmentVariable('CLIENT_ID','myclientid',[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('CLIENT_SECRET','myclientsecret',[System.EnvironmentVariableTarget]::Machine)

# Configure connection string
Open web.config and modify DefaultConnection.

# Restart IIS
net stop was /y
net start w3svc
```

### Cleanup environment.
After demo destroy infrastructure and identities.

```powershell
# Cleanup
Remove-AzADServicePrincipal -DisplayName tomasazdefender-sql-encrypt -Force
Remove-AzADApplication -DisplayName tomasazdefender-sql-encrypt -Force
Remove-AzADServicePrincipal -DisplayName tomasazdefender-sql-login -Force
Remove-AzADApplication -DisplayName tomasazdefender-sql-login -Force
Get-AzResourceLock -ResourceGroupName azdefender | Remove-AzResourceLock -Force
Remove-AzResourceGroup -Name azdefender -Force -AsJob
```

