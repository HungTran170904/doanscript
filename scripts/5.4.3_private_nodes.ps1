# AKS Private Nodes Management Tool
# CIS Benchmark 5.4.3 - Ensure clusters are created with Private Nodes

function Show-Menu {
    Clear-Host
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  AKS Private Nodes Management" -ForegroundColor Cyan
    Write-Host "  CIS Benchmark 5.4.3" -ForegroundColor Gray
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. Check if cluster has Private Nodes"
    Write-Host "2. Create cluster with Private Nodes"
    Write-Host "3. Exit"
    Write-Host ""
}

function Select-Subscription {
    $subscriptions = az account list --output json | ConvertFrom-Json
    
    if ($subscriptions.Count -eq 0) {
        Write-Host "No subscription found. Please login with 'az login'" -ForegroundColor Red
        return $null
    }
    
    Write-Host "`nAvailable Subscriptions:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $subscriptions.Count; $i++) {
        Write-Host "$($i + 1). $($subscriptions[$i].name)"
    }
    
    $choice = Read-Host "`nSelect subscription"
    $selected = $subscriptions[$choice - 1]
    
    if ($selected) {
        az account set --subscription $selected.id
        Write-Host "Using: $($selected.name)" -ForegroundColor Green
    }
    
    return $selected
}

function Select-ResourceGroup {
    param([string]$Prompt = "Select resource group")
    
    $rgs = az group list --output json | ConvertFrom-Json
    
    if ($rgs.Count -eq 0) {
        Write-Host "No resource groups found" -ForegroundColor Red
        return $null
    }
    
    Write-Host "`nResource Groups:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $rgs.Count; $i++) {
        Write-Host "$($i + 1). $($rgs[$i].name) [$($rgs[$i].location)]"
    }
    
    $choice = Read-Host "`n$Prompt"
    return $rgs[$choice - 1]
}

function Select-AKSCluster {
    param([string]$ResourceGroupName)
    
    $clusters = az aks list --resource-group $ResourceGroupName --output json | ConvertFrom-Json
    
    if ($clusters.Count -eq 0) {
        Write-Host "No AKS clusters found in resource group: $ResourceGroupName" -ForegroundColor Red
        return $null
    }
    
    Write-Host "`nAKS Clusters:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $clusters.Count; $i++) {
        Write-Host "$($i + 1). $($clusters[$i].name)"
    }
    
    $choice = Read-Host "`nSelect cluster"
    return $clusters[$choice - 1]
}

function Check-PrivateNodes {
    Write-Host "`n=== Check Private Nodes Status ===" -ForegroundColor Yellow
    Write-Host "CIS Benchmark 5.4.3: Ensure clusters are created with Private Nodes" -ForegroundColor Gray
    Write-Host ""
    
    if (-not (Select-Subscription)) { return }
    
    $rg = Select-ResourceGroup
    if (-not $rg) { return }
    
    $cluster = Select-AKSCluster -ResourceGroupName $rg.name
    if (-not $cluster) { 
        Read-Host "`nPress Enter"
        return 
    }
    
    Write-Host "`nChecking private cluster configuration for: $($cluster.name)..." -ForegroundColor Yellow
    
    # Check if cluster has private nodes (enable-private-cluster)
    $isPrivateCluster = az aks show `
        --name $cluster.name `
        --resource-group $rg.name `
        --query "apiServerAccessProfile.enablePrivateCluster" `
        --output tsv
    
    # Get additional network configuration
    $clusterDetails = az aks show `
        --name $cluster.name `
        --resource-group $rg.name `
        --query "{privateCluster:apiServerAccessProfile.enablePrivateCluster, privateFqdn:privateFqdn, fqdn:fqdn, networkPlugin:networkProfile.networkPlugin, loadBalancerSku:networkProfile.loadBalancerSku, outboundType:networkProfile.outboundType}" `
        --output json | ConvertFrom-Json
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "`nFailed to retrieve cluster information" -ForegroundColor Red
        Read-Host "Press Enter"
        return
    }
    
    # Display results
    Write-Host "`n=== Audit Results ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Cluster: " -NoNewline
    Write-Host "$($cluster.name)" -ForegroundColor White
    Write-Host "Resource Group: " -NoNewline
    Write-Host "$($rg.name)" -ForegroundColor White
    Write-Host ""
    
    # Private Cluster Status (CIS Benchmark check)
    Write-Host "Private Nodes Enabled: " -NoNewline
    if ($isPrivateCluster -eq "true") {
        Write-Host "YES" -ForegroundColor Green
        Write-Host "  Status: " -NoNewline
        Write-Host "COMPLIANT" -ForegroundColor Green -BackgroundColor DarkGreen
    } else {
        Write-Host "NO" -ForegroundColor Red
        Write-Host "  Status: " -NoNewline
        Write-Host "NON-COMPLIANT" -ForegroundColor Red -BackgroundColor DarkRed
    }
    
    Write-Host ""
    Write-Host "--- Network Configuration ---" -ForegroundColor Cyan
    
    # Private FQDN
    if ($clusterDetails.privateFqdn) {
        Write-Host "Private FQDN: $($clusterDetails.privateFqdn)" -ForegroundColor Gray
    }
    
    # Public FQDN (if exists)
    if ($clusterDetails.fqdn) {
        Write-Host "Public FQDN: $($clusterDetails.fqdn)" -ForegroundColor Gray
    }
    
    # Network Plugin
    Write-Host "Network Plugin: $($clusterDetails.networkPlugin)" -ForegroundColor Gray
    
    # Load Balancer SKU
    Write-Host "Load Balancer SKU: $($clusterDetails.loadBalancerSku)" -ForegroundColor Gray
    
    # Outbound Type
    Write-Host "Outbound Type: $($clusterDetails.outboundType)" -ForegroundColor Gray
    
    # CIS Benchmark Explanation
    Write-Host "`n--- CIS Benchmark 5.4.3 ---" -ForegroundColor Cyan
    Write-Host "Requirement: Clusters should be created with Private Nodes" -ForegroundColor Gray
    Write-Host "Description: Private nodes have no public IP addresses," -ForegroundColor Gray
    Write-Host "             reducing exposure to internet-based attacks" -ForegroundColor Gray
    
    # Recommendations
    Write-Host "`n--- Recommendations ---" -ForegroundColor Cyan
    
    if ($isPrivateCluster -ne "true") {
        Write-Host "[!] CRITICAL: This cluster does NOT have private nodes" -ForegroundColor Red
        Write-Host "    Action: Create a new cluster with --enable-private-cluster flag" -ForegroundColor Yellow
        Write-Host "    Note: Existing clusters cannot be converted to private" -ForegroundColor Yellow
    } else {
        Write-Host "[OK] Cluster is properly configured with private nodes" -ForegroundColor Green
        
        # Additional checks
        if ($clusterDetails.loadBalancerSku -ne "standard") {
            Write-Host "[!] Consider using Standard Load Balancer SKU" -ForegroundColor Yellow
        }
        
        if ($clusterDetails.networkPlugin -ne "azure") {
            Write-Host "[INFO] Using $($clusterDetails.networkPlugin) network plugin" -ForegroundColor Gray
            Write-Host "       Azure CNI is recommended for private clusters" -ForegroundColor Gray
        }
    }
    
    # Security Benefits
    if ($isPrivateCluster -eq "true") {
        Write-Host "`n--- Security Benefits ---" -ForegroundColor Cyan
        Write-Host "[OK] Nodes have no public IP addresses" -ForegroundColor Green
        Write-Host "[OK] Reduced attack surface" -ForegroundColor Green
        Write-Host "[OK] API server accessible only via private endpoint" -ForegroundColor Green
        Write-Host "[OK] Network isolation from internet" -ForegroundColor Green
    }
    
    Read-Host "`nPress Enter"
}

function Create-PrivateCluster {
    Write-Host "`n=== Create Cluster with Private Nodes ===" -ForegroundColor Yellow
    Write-Host "CIS Benchmark 5.4.3 Compliance" -ForegroundColor Gray
    Write-Host ""
    Write-Host "IMPORTANT NOTES:" -ForegroundColor Cyan
    Write-Host "- Private nodes have no public IP addresses" -ForegroundColor Gray
    Write-Host "- API server is only accessible via private endpoint" -ForegroundColor Gray
    Write-Host "- Requires VNet integration for management access" -ForegroundColor Gray
    Write-Host "- Cannot convert existing public cluster to private" -ForegroundColor Gray
    Write-Host ""
    
    $confirm = Read-Host "Do you want to create a new private cluster? (yes/no)"
    if ($confirm -ne "yes") {
        Write-Host "Operation cancelled" -ForegroundColor Red
        Read-Host "`nPress Enter"
        return
    }
    
    if (-not (Select-Subscription)) { return }
    
    $rg = Select-ResourceGroup -Prompt "Select resource group for new cluster"
    if (-not $rg) { return }
    
    # Cluster Configuration
    Write-Host "`n--- Basic Configuration ---" -ForegroundColor Cyan
    $clusterName = Read-Host "Enter cluster name"
    
    if ([string]::IsNullOrWhiteSpace($clusterName)) {
        Write-Host "`nCluster name is required" -ForegroundColor Red
        Read-Host "Press Enter"
        return
    }
    
    # Check if cluster already exists
    $existingCluster = az aks show --resource-group $rg.name --name $clusterName 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`nCluster '$clusterName' already exists in resource group '$($rg.name)'" -ForegroundColor Red
        Read-Host "Press Enter"
        return
    }
    
    # Node Configuration
    Write-Host "`n--- Node Configuration ---" -ForegroundColor Cyan
    $nodeCount = Read-Host "Node count (default: 3)"
    if ([string]::IsNullOrWhiteSpace($nodeCount)) { $nodeCount = "3" }
    
    $nodeSize = Read-Host "Node VM size (default: Standard_DS2_v2)"
    if ([string]::IsNullOrWhiteSpace($nodeSize)) { $nodeSize = "Standard_DS2_v2" }
    
    # Network Configuration
    Write-Host "`n--- Network Configuration ---" -ForegroundColor Cyan
    Write-Host "Network plugin options:" -ForegroundColor Gray
    Write-Host "  1. azure (Azure CNI - Recommended for private clusters)" -ForegroundColor Gray
    Write-Host "  2. kubenet (Basic networking)" -ForegroundColor Gray
    $networkChoice = Read-Host "Select network plugin (1 or 2, default: 1)"
    
    $networkPlugin = "azure"
    if ($networkChoice -eq "2") {
        $networkPlugin = "kubenet"
    }
    
    # Load Balancer SKU
    Write-Host "`nLoad Balancer SKU:" -ForegroundColor Gray
    Write-Host "  Standard (Required for private clusters)" -ForegroundColor Gray
    $loadBalancerSku = "standard"
    
    # VNet Configuration (Optional but recommended)
    Write-Host "`n--- VNet Configuration (Optional) ---" -ForegroundColor Cyan
    Write-Host "You can specify an existing VNet subnet or let Azure create one" -ForegroundColor Gray
    $useExistingVnet = Read-Host "Use existing VNet? (yes/no, default: no)"
    
    $vnetSubnetId = ""
    if ($useExistingVnet -eq "yes") {
        # List VNets
        $vnets = az network vnet list --resource-group $rg.name --output json | ConvertFrom-Json
        
        if ($vnets.Count -eq 0) {
            Write-Host "No VNets found in resource group. Will create new VNet." -ForegroundColor Yellow
        } else {
            Write-Host "`nAvailable VNets:" -ForegroundColor Cyan
            for ($i = 0; $i -lt $vnets.Count; $i++) {
                Write-Host "$($i + 1). $($vnets[$i].name)"
            }
            
            $vnetChoice = Read-Host "Select VNet (or press Enter to create new)"
            if (![string]::IsNullOrWhiteSpace($vnetChoice)) {
                $selectedVnet = $vnets[$vnetChoice - 1]
                
                # List subnets
                $subnets = az network vnet subnet list --resource-group $rg.name --vnet-name $selectedVnet.name --output json | ConvertFrom-Json
                
                if ($subnets.Count -gt 0) {
                    Write-Host "`nAvailable Subnets:" -ForegroundColor Cyan
                    for ($i = 0; $i -lt $subnets.Count; $i++) {
                        Write-Host "$($i + 1). $($subnets[$i].name) [$($subnets[$i].addressPrefix)]"
                    }
                    
                    $subnetChoice = Read-Host "Select subnet"
                    if (![string]::IsNullOrWhiteSpace($subnetChoice)) {
                        $selectedSubnet = $subnets[$subnetChoice - 1]
                        $vnetSubnetId = $selectedSubnet.id
                    }
                }
            }
        }
    }
    
    # Additional Options
    Write-Host "`n--- Additional Options ---" -ForegroundColor Cyan
    $enablePublicFqdn = Read-Host "Enable public FQDN for private cluster? (yes/no, default: no)"
    
    # Configuration Summary
    Write-Host "`n=== Configuration Summary ===" -ForegroundColor Yellow
    Write-Host "Cluster Name: $clusterName"
    Write-Host "Resource Group: $($rg.name)"
    Write-Host "Location: $($rg.location)"
    Write-Host "Node Count: $nodeCount"
    Write-Host "Node Size: $nodeSize"
    Write-Host "Network Plugin: $networkPlugin"
    Write-Host "Load Balancer SKU: $loadBalancerSku"
    Write-Host "Private Cluster: Enabled (CIS 5.4.3 Compliant)" -ForegroundColor Green
    
    if (![string]::IsNullOrWhiteSpace($vnetSubnetId)) {
        Write-Host "VNet Subnet: $vnetSubnetId"
    }
    
    if ($enablePublicFqdn -eq "yes") {
        Write-Host "Public FQDN: Enabled"
    }
    
    Write-Host ""
    $finalConfirm = Read-Host "Create private cluster? (yes/no)"
    if ($finalConfirm -ne "yes") {
        Write-Host "Operation cancelled" -ForegroundColor Red
        Read-Host "`nPress Enter"
        return
    }
    
    Write-Host "`nCreating private AKS cluster..." -ForegroundColor Yellow
    Write-Host "This may take 10-15 minutes..." -ForegroundColor Gray
    Write-Host "Started: $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Gray
    
    # Build command
    $command = "az aks create --resource-group $($rg.name) --name $clusterName --node-count $nodeCount --node-vm-size $nodeSize --load-balancer-sku $loadBalancerSku --enable-private-cluster --network-plugin $networkPlugin --generate-ssh-keys"
    
    # Add VNet subnet if specified
    if (![string]::IsNullOrWhiteSpace($vnetSubnetId)) {
        $command += " --vnet-subnet-id `"$vnetSubnetId`""
    }
    
    # Add public FQDN if requested
    if ($enablePublicFqdn -eq "yes") {
        $command += " --enable-public-fqdn"
    }
    
    Write-Host "`nExecuting command..." -ForegroundColor Gray
    Write-Host $command -ForegroundColor DarkGray
    Write-Host ""
    
    $result = Invoke-Expression "$command --output json 2>&1"
    
    Write-Host "Completed: $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Gray
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n=== SUCCESS ===" -ForegroundColor Green
        Write-Host "Private cluster created successfully!" -ForegroundColor Green
        Write-Host ""
        Write-Host "CIS Benchmark 5.4.3: " -NoNewline
        Write-Host "COMPLIANT" -ForegroundColor Green -BackgroundColor DarkGreen
        Write-Host ""
        Write-Host "Cluster Features:" -ForegroundColor Cyan
        Write-Host "[OK] Private nodes (no public IPs)" -ForegroundColor Green
        Write-Host "[OK] Private API server endpoint" -ForegroundColor Green
        Write-Host "[OK] Network isolation" -ForegroundColor Green
        Write-Host "[OK] Standard Load Balancer" -ForegroundColor Green
        Write-Host ""
        Write-Host "Next steps:" -ForegroundColor Cyan
        Write-Host "1. Get credentials:" -ForegroundColor Gray
        Write-Host "   az aks get-credentials -g $($rg.name) -n $clusterName" -ForegroundColor White
        Write-Host ""
        Write-Host "2. Access options:" -ForegroundColor Gray
        Write-Host "   - Use a VM in the same VNet (jump box)" -ForegroundColor White
        Write-Host "   - Configure VPN or ExpressRoute" -ForegroundColor White
        Write-Host "   - Use Azure Bastion" -ForegroundColor White
        
        if ($enablePublicFqdn -eq "yes") {
            Write-Host "   - Use public FQDN (enabled)" -ForegroundColor White
        }
        
    } else {
        Write-Host "`n=== FAILED ===" -ForegroundColor Red
        Write-Host $result
        Write-Host "`nCommon issues:" -ForegroundColor Yellow
        Write-Host "- Cluster name already exists"
        Write-Host "- Insufficient quota in region"
        Write-Host "- Invalid VM size"
        Write-Host "- VNet/Subnet configuration issues"
        Write-Host "- Network plugin compatibility"
    }
    
    Read-Host "`nPress Enter"
}

# Main Loop
do {
    Show-Menu
    $choice = Read-Host "Select option (1-3)"
    
    switch ($choice) {
        '1' { Check-PrivateNodes }
        '2' { Create-PrivateCluster }
        '3' { 
            Write-Host "`nGoodbye!" -ForegroundColor Green
            exit 
        }
        default {
            Write-Host "`nInvalid choice" -ForegroundColor Red
            Start-Sleep -Seconds 2
        }
    }
} while ($choice -ne '3')
