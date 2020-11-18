# Download Visual C++ redist
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 
New-Item -ItemType Directory -Force -Path \install
$WebClient = New-Object System.Net.WebClient
$WebClient.DownloadFile("https://download.visualstudio.microsoft.com/download/pr/48431a06-59c5-4b63-a102-20b66a521863/4B5890EB1AEFDF8DFA3234B5032147EB90F050C5758A80901B201AE969780107/VC_redist.x64.exe","c:\install\VC_redist.x64.exe")
C:\install\VC_redist.x64.exe

# Download sqlcmd.exe
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 
New-Item -ItemType Directory -Force -Path \install
$WebClient = New-Object System.Net.WebClient
$WebClient.DownloadFile("https://download.microsoft.com/download/6/b/3/6b3dd05c-678c-4e6b-b503-1d66e16ef23d/en-US/17.6.1.1/x64/msodbcsql.msi","c:\install\msodbcsql.msi")
C:\install\msodbcsql.msi

# Download sqlcmd.exe
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 
New-Item -ItemType Directory -Force -Path \install
$WebClient = New-Object System.Net.WebClient
$WebClient.DownloadFile("https://download.microsoft.com/download/0/e/6/0e63d835-3513-45a0-9cf0-0bc75fb4269e/EN/x64/MsSqlCmdLnUtils.msi","c:\install\MsSqlCmdLnUtils.msi")
C:\install\MsSqlCmdLnUtils.msi





