# Configure app
[System.Environment]::SetEnvironmentVariable('CLIENT_ID','myclientid',[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('CLIENT_SECRET','myclientsecret',[System.EnvironmentVariableTarget]::Machine)

# Install IIS
Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServerRole
Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServer
Enable-WindowsOptionalFeature -Online -FeatureName IIS-CommonHttpFeatures
Enable-WindowsOptionalFeature -Online -FeatureName IIS-WindowsAuthentication
Install-WindowsFeature Web-Asp-Net45

# Install dotnet core with IIS module
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 
New-Item -ItemType Directory -Force -Path \install
$WebClient = New-Object System.Net.WebClient
$WebClient.DownloadFile("https://download.visualstudio.microsoft.com/download/pr/a9bb6d52-5f3f-4f95-90c2-084c499e4e33/eba3019b555bb9327079a0b1142cc5b2/dotnet-hosting-2.2.6-win.exe","c:\install\dotnet-hosting-2.2.6-win.exe")
C:\install\dotnet-hosting-2.2.6-win.exe /install /quiet

# Restart IIS to pickup PATH for dotnet
net stop was /y
net start w3svc

# Install app
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 
$WebClient = New-Object System.Net.WebClient
$WebClient.DownloadFile("https://tomuvstore.blob.core.windows.net/public/app.zip","c:\install\app.zip")
cd \inetpub\wwwroot\
Expand-Archive -LiteralPath 'c:\install\app.zip'
Copy-item -Force -Recurse .\app\* -Destination .

# Restart IIS to pickup PATH for dotnet
net stop was /y
net start w3svc

# wait and clean up
Start-Sleep -s 15
Remove-Item \install -Force -Recurse


