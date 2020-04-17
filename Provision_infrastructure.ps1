<#
.SYNOPSIS 
    PowerShell script for provisioning infrastructure.
        
.DESCRIPTION 
    Based on provided inputs, script will provision:
        All needed Resource Groups
        Two (2) Virtual Networks with peering
        One (1) Network Security Groups
        One (1) rule that allows access to port 3389
        One (1) Azure Container Registry
        One (1) Azure Container Instance
        One (1) Virtual Machine

.NOTES
    Before creating ACI it is needed to use Docker to build our custom image and to push it to the ACR. Refer to Instructions.md
         
.NOTES 
    File Name  : Provision_infrastructure.ps1
    Author     : Milos Katinski 
    Requires   : Az PowerShell module
#>

#region Define Parameters
$Location = "West Europe"
$ProjectName = "mkatinski"
$VirtualMachinesRG = "$ProjectName-vm-rg"
$ContainerInstanceRG = "$ProjectName-aci-rg"
$NetworkingRG = "$ProjectName-network-rg"
# $StorageRG = "$ProjectName-Storage"
$vNetNameTest = "solar-impulse-test"
$AddressSpaceTest = "10.240.0.0/16"
$SubnetIPRangeTest = "10.240.1.0/24"
$SubnetNameTest = "aci-subnet"
$vNetNameAcc = "solar-impulse-acc"
$AddressSpaceAcc = "10.241.0.0/16"
$SubnetIPRangeAcc = "10.241.1.0/24"
$SubnetNameAcc = "vm-subnet"
$NsgNameAcc = "$vNetNameAcc-nsg"
#endregion

#region RG creation
# Create RG for virtual machines
#if (Get-AzResourceGroup | Where-Object { $_.ResourceGroupName -match $VirtualMachinesRG }) {
#    Write-Host $VirtualMachinesRG already exist -ForegroundColor Cyan
#}
#else {    
#    Write-Host $VirtualMachinesRG creating ... Please wait -ForegroundColor Yellow
#    New-AzResourceGroup -Name $VirtualMachinesRG -Location $location  
#    if (Get-AzResourceGroup | Where-Object { $_.ResourceGroupName -match $VirtualMachinesRG }) {
#        Write-Host Resource Group $VirtualMachinesRG successfully created. -ForegroundColor Green
#    }
#}

# Create RG for Container Instance
#if (Get-AzResourceGroup | Where-Object { $_.ResourceGroupName -match $ContainerInstanceRG }) {
#    Write-Host $ContainerInstanceRG already exist -ForegroundColor Cyan
#}
#else {    
#    Write-Host $ContainerInstanceRG creating ... Please wait -ForegroundColor Yellow
#    New-AzResourceGroup -Name $ContainerInstanceRG -Location $location  
#    if (Get-AzResourceGroup | Where-Object { $_.ResourceGroupName -match $ContainerInstanceRG }) {
#        Write-Host Resource Group $ContainerInstanceRG successfully created. -ForegroundColor Green
#    }
#}

# Create RG for networking
#if (Get-AzResourceGroup | Where-Object { $_.ResourceGroupName -match $NetworkingRG }) {
#    Write-Host $NetworkingRG already exist -ForegroundColor Cyan
#}
#else {    
#    Write-Host $NetworkingRG creating ... Please wait -ForegroundColor Yellow
#    New-AzResourceGroup -Name $NetworkingRG -Location $location
#    if (Get-AzResourceGroup | Where-Object { $_.ResourceGroupName -match $NetworkingRG }) {
#        Write-Host Resource Group $NetworkingRG successfully created. -ForegroundColor Green
#    }
#}
#endregion

#region Test environment
# Create virtual network and subnet for Test
$vNetworkTest = New-AzVirtualNetwork -ResourceGroupName $NetworkingRG -Name $vNetNameTest -AddressPrefix $AddressSpaceTest -Location $location
Add-AzVirtualNetworkSubnetConfig -Name $SubnetNameTest -VirtualNetwork $vNetworkTest -AddressPrefix $SubnetIPRangeTest
Set-AzVirtualNetwork -VirtualNetwork $vNetworkTest

if (Get-AzVirtualNetwork | Where-Object { $_.Name -like "$vNetNameTest" }) {
    Write-Host Virtual Network $vNetNameTest is successfully created. Address space is $AddressSpaceTest. -ForegroundColor Green
}
# Create ACR and ACI
New-AzContainerRegistry -ResourceGroupName $ContainerInstanceRG -Name "SolarACR" -Sku 'Basic' -EnableAdminUser
$CredObj = Get-AzContainerRegistryCredential -ResourceGroupName $ContainerInstanceRG -Name "SolarACR"
$username = $CredObj.Username
$password = ConvertTo-SecureString -string $CredObj.Password -AsPlainText -Force
$NewCredObj = New-Object -TypeName PSCredential -ArgumentList $username, $password
$RegLoginServer = (Get-AzContainerRegistry -ResourceGroupName $ContainerInstanceRG).LoginServer

# Before we use our modified image, we need to push it to ACR -> read instructions.md
#New-AzContainerGroup -ResourceGroupName $ContainerInstanceRG -Name $ProjectName-dnsmasq `
#    -Image $RegLoginServer/dnsmasq -DnsNameLabel 'solartstdns' -IpAddressType Public -Port @(53) -RegistryCredential $NewCredObj

#endregion

#region Acc environment
# Create virtual network and subnet for Acc
$vNetworkAcc = New-AzVirtualNetwork -ResourceGroupName $NetworkingRG -Name $vNetNameAcc -AddressPrefix $AddressSpaceAcc -Location $location
Add-AzVirtualNetworkSubnetConfig -Name $SubnetNameAcc -VirtualNetwork $vNetworkAcc -AddressPrefix $SubnetIPRangeAcc
Set-AzVirtualNetwork -VirtualNetwork $vNetworkAcc

if (Get-AzVirtualNetwork | Where-Object { $_.Name -like "$vNetNameAcc" }) {
    Write-Host Virtual Network $vNetNameAcc is successfully created. Address space is $AddressSpaceAcc. -ForegroundColor Green
}

# Create Network Security Group
$nsgRuleVMAccess = New-AzNetworkSecurityRuleConfig -Name 'allow-rdp' `
    -Protocol Tcp -Direction Inbound -Priority 100 -SourceAddressPrefix 195.169.110.175 `
    -SourcePortRange * -DestinationAddressPrefix VirtualNetwork -DestinationPortRange 3389 -Access Allow
$nsg = New-AzNetworkSecurityGroup -ResourceGroupName $NetworkingRG -Location $location -Name $NsgNameAcc -SecurityRules $nsgRuleVMAccess

if (Get-AzNetworkSecurityGroup | Where-Object { $_.Name -like "$nsgNameAcc" }) {
    Write-Host Network Security Groups $NsgNameAcc is successfully created with included $nsgRuleVMAccess.Name rule. -ForegroundColor Green 
}

# Associate NSG with subnet
$vnet = Get-AzVirtualNetwork -Name $vNetNameAcc -ResourceGroupName $NetworkingRG
$subnet = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name $SubnetNameAcc
$nsg = Get-AzNetworkSecurityGroup -ResourceGroupName $NetworkingRG -Name $NsgNameAcc
$subnet.NetworkSecurityGroup = $nsg
Set-AzVirtualNetwork -VirtualNetwork $vnet
#endregion

#region Connect Vnets
# Vnet Peering
Add-AzVirtualNetworkPeering -Name 'tst-to-acc' -VirtualNetwork $vNetworkTest -RemoteVirtualNetworkId $vNetworkAcc.Id
Add-AzVirtualNetworkPeering -Name 'acc-to-tst' -VirtualNetwork $vNetworkAcc -RemoteVirtualNetworkId $vNetworkTest.Id
#endregion

#region Provision VM
$StorageAccountName = "$ProjectName" + "stvm"
$CSVFilePath = ".\ServersFull.csv"

# Check storage name availability
if (Get-AzStorageAccountNameAvailability -Name $StorageAccountName | Where-Object { $_.NameAvailable -match "False" }) {
    Write-Host The storage account named $StorageAccountName is already taken. -ForegroundColor Red
    Write-Host Script will be stopped. Please select other storage account name. -ForegroundColor Yellow
    exit 3
}
else {
    Write-Host "Storage account name $StorageAccountName is available. Enjoy!" -ForegroundColor Green
    New-AzStorageAccount -Name $StorageAccountName -ResourceGroupName $VirtualMachinesRG -SkuName Standard_GRS -location $location
}

# Define Virtual Machine Parameters
Import-Csv -Path $CSVFilePath | ForEach-Object {
    $vmName = $_.VmName
    $pubName	= $_.Publication
    $offerName	= $_.Offer
    $skuName	= $_.Sku
    $vmSize = $_.VMSize
    $pipName = "$vmName-pip" 
    $nicName = "$vmName-nic"
    $osDiskName = "$vmName-OsDisk"
    $osDiskSize = $_.DiskSize
    $osDiskType = 'Premium_LRS'
    $AVSet = $_.AVSet

    # Create a public IP and NIC
    $pip = New-AzPublicIpAddress -Name $pipName -ResourceGroupName $VirtualMachinesRG -Location $location -AllocationMethod Static 
    $nic = New-AzNetworkInterface -Name $nicName -ResourceGroupName $VirtualMachinesRG -Location $location -SubnetId $subnet.Id -PublicIpAddressId $pip.Id -NetworkSecurityGroupId $nsg.Id

    # Create Availability Set
    if (Get-AzAvailabilitySet -ResourceGroupName $VirtualMachinesRG | Where-Object { $_.Name -match $AVSet }) {
        Write-Host The Availability Set named $AVSet is already created. -ForegroundColor Red
    }
    else {
        Write-Host "Availability Set $AVSet will be created." -ForegroundColor Green
        New-AzAvailabilitySet -ResourceGroupName $VirtualMachinesRG -Location $location -Name $AVSet -Sku Aligned -PlatformFaultDomainCount 2 -PlatformUpdateDomainCount 5
        Start-Sleep 5
    }

    # Set VM Configuration
    $AVSetConfig = Get-AzAvailabilitySet -ResourceGroupName $VirtualMachinesRG -Name $AVSet
    $vmConfig	= New-AzVMConfig -VMName $vmName -VMSize $vmSize -AvailabilitySetId $AVSetConfig.Id
    Add-AzVMNetworkInterface -VM $vmConfig -Id $nic.Id

    Set-AzVMOperatingSystem -VM $vmConfig -Windows -ComputerName $vmName -Credential $NewCredObj

    # Identify the diagnostics storage account
    Set-AzVMBootDiagnostics -Enable -ResourceGroupName $VirtualMachinesRG -VM $vmConfig -StorageAccountName $StorageAccountName

    Set-AzVMSourceImage -VM $vmConfig -PublisherName $pubName -Offer $offerName -Skus $skuName -Version 'latest'
    Set-AzVMOSDisk -VM $vmConfig -Name $osDiskName -DiskSizeInGB $osDiskSize -StorageAccountType $osDiskType -CreateOption fromImage

    # Create the VM
    New-AzVM -ResourceGroupName $VirtualMachinesRG -Location $location -VM $vmConfig -AsJob

    Start-Sleep -Seconds 2

    # Check VM creating status
    if (Get-AzVM | Where-Object { $_.Name -match $vmName }) {
        Write-Host $vmName configuration has been successfully validated. -ForegroundColor Green
        Write-Host "Creation process will start immediately." -ForegroundColor Yellow 
    }
    else {
        Write-Host Houston, we have a probem with creating $vmName. Please check ASAP. -ForegroundColor Red
    }

    Start-Sleep -Seconds 1

}

Import-Csv -Path $CSVFilePath | ForEach-Object { 
    if (Get-AzVM -Name $_.VmName -ResourceGroupName $VirtualMachinesRG) {
        Write-Host "Creation process of VM named "$_.VmName" is successfully started." -ForegroundColor Green
    }
    else {
        Write-Host $_.VmName is NOT created. Please check error logs. -ForegroundColor Red
    }
}

# Check Status of Provisioning Virtual Machines
$VMProvisioningStatus = Get-AzVM -ResourceGroupName $VirtualMachinesRG | Where-Object { $_.ProvisioningState -match "Creating" }

Do {
    # Check VMs provisioning
    if ($VMProvisioningStatus.Count -gt "0") {
        Write-Host "Virtual machine is in provisioning state..." -ForegroundColor Yellow
        Start-Sleep -Seconds 10
        $VMProvisioningStatus = Get-AzVM -ResourceGroupName $VirtualMachinesRG | Where-Object { $_.ProvisioningState -match "Creating" }

    }
}
Until ($VMProvisioningStatus.Count -le "0")

if ($VMProvisioningStatus.Count -le "0") {
    Write-Host "All virtual machines are provisioned." -ForegroundColor Green
}

#endregion
