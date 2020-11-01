# Application demo
In this demo we will use sample clinic application with vulnerabilities.

## Demonstrate SQL Injection vulnerability
Connect to web running on VM by accessing following URL:

```powershell
$(Get-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName -Name azdefender-infra).outputs.vmDns.Value
```

Access Patiens page and use hints to copy SQL injection string into search field. App is vulnerable.

## Azure Defender for SQL detects injection
Show Azure Defender eg. from Security page on database. Alerts should indicate SQL injection. Describe other protections (brute force, unusual query etc.)

## Azure WAF on Front Door
Azure Front Door is distributed Web Application Firewall running on all POPs to Microsoft network including Prague. Show configuration and WAF policy.

Access application via Front Door on following URL and show SQL injection is blocked.

```powershell
$(Get-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName -Name azdefender-infra).outputs.fdDns.Value
```

## Encrypt data at rest with TDE
Go to portal and enable TDE.

## Using Key Vault to store secrets
Go to portal, find deployed Key Vault and create new secret called mySecret.

Review access policies to show identity myVmIdentity has been given access to read secrets.

Go to VM/identity and show myVmIdentity is assigned to VM.

Access VM via Bastion and show how managed identitz can be used to get secret from vault. To get your Key Vault you can use following command:

```powershell
Write-Host https://$($(Get-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName -Name azdefender-infra).outputs.keyVaultName.Value).vault.azure.net/
```

Run on Azure VM:

```powershell
# Get token from metadata service for Key Vault scope
$response = Invoke-WebRequest -Uri 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fvault.azure.net' -Method GET -Headers @{Metadata="true"}

# Parse token
$content = $response.Content | ConvertFrom-Json
$KeyVaultToken = $content.access_token

# Use token to access secret (make sure to change URL to match your environment)
(Invoke-WebRequest -Uri https://kv5zfbmg5p6w444.vault.azure.net/secrets/mySecret?api-version=2016-10-01 -Method GET -Headers @{Authorization="Bearer $KeyVaultToken"}).content
```

## Centralize SQL identity with AAD and MFA
Go to portal and enable AAD admin.

Open Azure Data Management studio on Azure VM connected via Bastion and connect to server (FQDN is output of following commmand) with AAD authentication and to sqldb database.

```powershell
Write-Host "$($(Get-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName -Name azdefender-infra).outputs.sqlName.Value).database.windows.net"
```

## Always Encrypted
Configure Always Encrypted with key generated in Key Vault and encrypt sensitive columns.

```powershell
# Install modules
Install-Module -Name Az -Scope CurrentUser
Install-Module -Name SqlServer -Scope CurrentUser

# Create a column master key in Azure Key Vault.
Import-Module Az
Connect-AzAccount
$resourceGroupName = "azdefender"
$akvName = $(Get-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName -Name azdefender-infra).outputs.keyVaultName.Value
$akvKeyName = "dbkey"
$akvKey = Add-AzKeyVaultKey -VaultName $akvName -Name $akvKeyName -Destination "Software"

# Import the SqlServer module
Import-Module "SqlServer"  

# Connect to your database
$sqlName = $(Get-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName -Name azdefender-infra).outputs.sqlName.Value
$sqlPassword = Read-Host -Prompt 'SQL password'
$connStr = "Server=tcp:$sqlName.database.windows.net,1433;Initial Catalog=sqldb;Persist Security Info=False;User ID=tomas;Password=$sqlPassword;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
$database = Get-SqlDatabase -ConnectionString $connStr

# List column master keys for the specified database.
Get-SqlColumnMasterKey -InputObject $database

$cmkSettings = New-SqlAzureKeyVaultColumnMasterKeySettings -KeyURL $akvKey.Id

$cmkName = "CMK1"
New-SqlColumnMasterKey -Name $cmkName -InputObject $database -ColumnMasterKeySettings $cmkSettings

# Authenticate to Azure
Add-SqlAzureAuthenticationContext -Interactive

# Generate a column encryption key, encrypt it with the column master key and create column encryption key metadata in the database. 
$cekName = "CEK1"
New-SqlColumnEncryptionKey -Name $cekName -InputObject $database -ColumnMasterKey $cmkName

# Encrypt the selected columns (or re-encrypt, if they are already encrypted using keys/encrypt types, different than the specified keys/types.
$ces = @()
$ces += New-SqlColumnEncryptionSettings -ColumnName "dbo.Patients.SSN" -EncryptionType "Deterministic" -EncryptionKey "CEK1"
$ces += New-SqlColumnEncryptionSettings -ColumnName "dbo.Patients.BirthDate" -EncryptionType "Randomized" -EncryptionKey "CEK1"
Set-SqlColumnEncryption -InputObject $database -ColumnEncryptionSettings $ces -LogFileDirectory .
```

Open application and make sure data is still visible there as app has identity with access to Key Vault to decrypt data.

Demonstrate that full admin of SQL is no longer able to see sensitive data.

## Always encrypted with Secure Enclave
Describe solution with allowing database to do computations on data without admin be able to access it (data in use encryption): https://docs.microsoft.com/en-us/sql/relational-databases/security/encryption/always-encrypted-enclaves?view=sql-server-ver15

## Check application dependencies with GitHub Dependabot
Check dependency tree

https://github.com/tkubica12/sectest/network/dependencies

Open Dependabot alerts

https://github.com/tkubica12/sectest/network/alerts

Check Pull request has been automatically created to fix this.

https://github.com/tkubica12/sectest/pulls

## Analyze code for security issues with GitHub CodeQL
Check found vulnerabilities

https://github.com/tkubica12/sectest/security/code-scanning

## Demonstrate using GitHub Codespaces for secure remote development
For this demo you need to clone repo to your GitHub and create your own Codespace.

Open GitHub repo and open developer environment in browser.

Open the same environment in local editor (Open in VS Code).

## Demonstrate Azure Defender checking for vulnerabilities in container images
Check Azure Defender for vulnerabilities in container images.