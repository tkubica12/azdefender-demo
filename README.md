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
Run this script on Windows server to install Edge and Ayure Data Studio.

To be automated with VM extension in future.

```powershell
# Create install folder
mkdir c:\install

# Download and install Edge
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 
$WebClient = New-Object System.Net.WebClient
$WebClient.DownloadFile("https://tomuvstore.blob.core.windows.net/sdilna/MicrosoftEdgeSetupBeta.exe?sp=r&st=2020-10-27T12:10:03Z&se=2025-10-27T20:10:03Z&spr=https&sv=2019-12-12&sr=b&sig=z0BkrU7iK8s5OJHCM8BGZWYnjhUchrf%2FiLsmibIv2fI%3D","c:\install\edge.exe")
c:\install\edge.exe

# Download and install Azure Data Studio
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 
$WebClient = New-Object System.Net.WebClient
$WebClient.DownloadFile("https://go.microsoft.com/fwlink/?linkid=2145989","c:\install\ads.exe")
c:\install\ads.exe /verysilent

# Install IIS
Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServerRole
Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServer
Enable-WindowsOptionalFeature -Online -FeatureName IIS-CommonHttpFeatures
Enable-WindowsOptionalFeature -Online -FeatureName IIS-WindowsAuthentication
Install-WindowsFeature Web-Asp-Net45

# Download and install app
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 
$WebClient = New-Object System.Net.WebClient
$WebClient.DownloadFile("https://tomuvstore.blob.core.windows.net/public/app.zip","c:\install\app.zip")
cd \inetpub\wwwroot\
Expand-Archive -LiteralPath 'c:\install\app.zip'
Copy-item -Force -Recurse .\app\* -Destination .

# Configure service principal for accesing Key Vault for encryption (spSqlEncryptAppId and spSqlEncryptSecret)
[System.Environment]::SetEnvironmentVariable('CLIENT_ID','myclientid',[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('CLIENT_SECRET','myclientsecret',[System.EnvironmentVariableTarget]::Machine)

# Configure connection string
Open web.config and modify DefaultConnection.

# Restart IIS
net stop was /y
net start w3svc
```

### Upload testing malware to storage account
Example is using EICAR malware testing file. Since your computer will likely kill it, run following commands from Azure Cloud Shell (shell.azure.com).

To be automated with ARM deployment script in future.

```powershell
$resourceGroupName = "azdefender"
$containerName = "app-data"
$storageAccountName = $(Get-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName -Name azdefender-infra).outputs.storageAccount.Value
$storageAccount = Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName
$ctx = $storageAccount.Context
New-AzStorageContainer -Name $containerName -Context $ctx -Permission blob
'X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*' | Out-File EICAR.com
Set-AzStorageBlobContent -File EICAR.com -Container $containerName -Blob EICAR.com -Context $ctx 
Remove-Item EICAR.com
```

### Cleanup environment.
After demo destroy infrastructure and identities.

```powershell
# Cleanup
Remove-AzADServicePrincipal -DisplayName tomasazdefender-sql-encrypt -Force
Remove-AzADApplication -DisplayName tomasazdefender-sql-encrypt -Force
Remove-AzADServicePrincipal -DisplayName tomasazdefender-sql-login -Force
Remove-AzADApplication -DisplayName tomasazdefender-sql-login -Force
Remove-AzResourceGroup -Name azdefender -Force -AsJob
```

