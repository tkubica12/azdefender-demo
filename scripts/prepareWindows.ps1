param (
    [string]$sqlConnectionString,
    [string]$clientId,
    [string]$clientSecret
)

# Download and install Edge
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 
$WebClient = New-Object System.Net.WebClient
$WebClient.DownloadFile("https://tomuvstore.blob.core.windows.net/sdilna/MicrosoftEdgeSetupBeta.exe?sp=r&st=2020-10-27T12:10:03Z&se=2025-10-27T20:10:03Z&spr=https&sv=2019-12-12&sr=b&sig=z0BkrU7iK8s5OJHCM8BGZWYnjhUchrf%2FiLsmibIv2fI%3D","C:\Users\tomas\Desktop\edge.exe")

# Download and install Azure Data Studio
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 
$WebClient = New-Object System.Net.WebClient
$WebClient.DownloadFile("https://go.microsoft.com/fwlink/?linkid=2145989","C:\Users\tomas\Desktop\ads.exe")

# Install IIS
Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServerRole
Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServer
Enable-WindowsOptionalFeature -Online -FeatureName IIS-CommonHttpFeatures
Enable-WindowsOptionalFeature -Online -FeatureName IIS-WindowsAuthentication
Install-WindowsFeature Web-Asp-Net45

# Download and install app
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 
$WebClient = New-Object System.Net.WebClient
$WebClient.DownloadFile("https://tomuvstore.blob.core.windows.net/public/app.zip","C:\Users\tomas\Desktop\app.zip")
cd \inetpub\wwwroot\
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

# Download sqlpackage
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 
$WebClient = New-Object System.Net.WebClient
$WebClient.DownloadFile("https://go.microsoft.com/fwlink/?linkid=2143496","C:\Users\tomas\sqlpackage.zip")
cd C:\Users\tomas\
Expand-Archive -LiteralPath 'C:\Users\tomas\sqlpackage.zip'

# Download database backup
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 
$WebClient = New-Object System.Net.WebClient
$WebClient.DownloadFile("https://raw.githubusercontent.com/tkubica12/azdefender-demo/master/artifacts/contosoclinic.bacpac","C:\Users\tomas\scontosoclinic.bacpac")

# Import database structure and data
C:\Users\tomas\sqlpackage\sqlpackage.exe /Action:Import /tcs:$sqlConnectionString /sf:C:\Users\tomas\scontosoclinic.bacpac

# Restart IIS
net stop was /y
net start w3svc