param (
    [string]$sqlConnectionString,
    [string]$clientId,
    [string]$clientSecret
)

# Copy install files to proper locations
Copy-Item MicrosoftEdgeSetupBeta.exe C:\Users\tomas\Desktop\
Copy-Item azuredatastudio-windows-user-setup-1.23.0.exe C:\Users\tomas\Desktop\
Copy-Item app.zip C:\Users\tomas\Desktop\
Copy-Item sqlpackage-win7-x64-en-US-15.0.4897.1.zip C:\Users\tomas\


# Install IIS
Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServerRole
Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServer
Enable-WindowsOptionalFeature -Online -FeatureName IIS-CommonHttpFeatures
Enable-WindowsOptionalFeature -Online -FeatureName IIS-WindowsAuthentication
Install-WindowsFeature Web-Asp-Net45

# Install app
cd C:\inetpub\wwwroot\
Expand-Archive -LiteralPath 'C:\Users\tomas\Desktop\app.zip'
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
cd C:\Users\tomas\
Expand-Archive -LiteralPath 'C:\Users\tomas\sqlpackage-win7-x64-en-US-15.0.4897.1.zip'
C:\Users\tomas\sqlpackage\sqlpackage.exe /Action:Import /tcs:$sqlConnectionString /sf:C:\Users\tomas\contosoclinic.bacpac

# Restart IIS
net stop was /y
net start w3svc