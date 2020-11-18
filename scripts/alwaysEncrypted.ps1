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