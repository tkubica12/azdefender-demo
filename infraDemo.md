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
### Host level protection
First let's simulate couple of attacks.

We can invoke PowerShell script in Windows VM via Azure PowerShell command.

```powershell
Invoke-AzVMRunCommand -ResourceGroupName 'azdefender' -VMName 'azdefender-vm' -CommandId 'RunPowerShellScript' -ScriptPath 'scripts/infraAttackSimulationFromWindows.ps1' 
```

Also invoke Bash script on Linux node. Script is downloaded already in /scripts folder and you can run it by using Bastion to connect to server or using az command.

```powershell
az vm run-command invoke -g azdefender -n azdefender-linux-vm --command-id RunShellScript --scripts "sudo bash /scripts/infraAttackSimulationFromLinux.sh | sudo tee /scripts/infraAttackSimulation.log"
```

#### Windows protection
Search for alerts such as suspicious process or RDP attack. You can check out [scripts](./scripts/) to understand how attack simulations work.

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

#### Linux Host level protection
Check alerts in Azure Defender. You can check out [scripts](./scripts/) to understand how attack simulations work.

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

