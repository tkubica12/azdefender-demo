param (
    [string]$sqlConnectionString,
    [string]$clientId,
    [string]$clientSecret,
    [string]$sqlLoginIdentity
)

# Copy install files to proper locations
New-Item -Path "c:\" -Name "install" -ItemType "directory"
Copy-Item azuredatastudio-windows-user-setup-1.23.0.exe C:\install\
Copy-Item app.zip C:\install\
Copy-Item sqlpackage-win7-x64-en-US-15.0.4897.1.zip C:\install\
Copy-Item contosoclinic.bacpac C:\install\
Copy-Item MsSqlCmdLnUtils.msi C:\install\

# Install Chocolatey
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

# Install Edge
choco install microsoft-edge -y

# Install Azure Data Studio
choco install azure-data-studio -y

# Install sqlpackage
choco install sqlpackage -y

# Install sqlcmd
choco install sqlserver-odbcdriver -y
choco install sqlserver-cmdlineutils -y

# Reload PATH
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User") 

# Install IIS
Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServerRole
Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServer
Enable-WindowsOptionalFeature -Online -FeatureName IIS-CommonHttpFeatures
Enable-WindowsOptionalFeature -Online -FeatureName IIS-WindowsAuthentication
Install-WindowsFeature Web-Asp-Net45

# Install app
cd C:\inetpub\wwwroot\
Expand-Archive -LiteralPath 'C:\install\app.zip'
Copy-item -Force -Recurse .\app\* -Destination .

# Modify Web.config
(Get-Content \inetpub\wwwroot\Web.config).replace('<replaceWithConnectionString>', $sqlConnectionString) | Set-Content \inetpub\wwwroot\Web.config

# Store identity information for AlwaysEncrypted
[System.Environment]::SetEnvironmentVariable('CLIENT_ID', $clientId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('CLIENT_SECRET', $clientSecret,[System.EnvironmentVariableTarget]::Machine)

# Install PowerShell modules
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
Install-Module -Name Az -Force
Install-Module -Name SqlServer -Force

# Import database structure and data
sqlpackage /Action:Import /tcs:$sqlConnectionString /sf:C:\install\contosoclinic.bacpac

# Configure additional AAD access to SQL
# $connectionValues = $sqlConnectionString -replace ';',"`r`n" | ConvertFrom-StringData
# $sqlLoginIdentity = "86e4fae4-b981-478e-91dc-6a9cc75a4dd9"
# sqlcmd -S $connectionValues['Server'] -U $connectionValues['User ID'] -P $connectionValues['Password'] -Q "CREATE USER [$sqlLoginIdentity] FROM EXTERNAL PROVIDER;
#     ALTER ROLE db_datareader ADD MEMBER [$sqlLoginIdentity];
#     ALTER ROLE db_datawriter ADD MEMBER [$sqlLoginIdentity];
#     ALTER ROLE db_ddladmin ADD MEMBER [$sqlLoginIdentity];
#     GO"

# Restart IIS
net stop was /y
net start w3svc



