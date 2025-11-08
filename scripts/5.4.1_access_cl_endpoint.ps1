# AKS Control Plane Access Management Tool
# Manage API Server access settings

function Show-Menu {
    Clear-Host
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  AKS Control Plane Access Management" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. Check API Server access status"
    Write-Host "2. Enable private cluster"
    Write-Host "3. Restrict access by authorized IP ranges"
    Write-Host "4. Exit"
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
        $privateStatus = if ($clusters[$i].apiServerAccessProfile.enablePrivateCluster) { "Private" } else { "Public" }
        Write-Host "$($i + 1). $($clusters[$i].name) [$privateStatus]"
    }
    
    $choice = Read-Host "`nSelect cluster"
    return $clusters[$choice - 1]
}

function Check-APIServerAccess {
    Write-Host "`n=== Check API Server Access Status ===" -ForegroundColor Yellow
    
    if (-not (Select-Subscription)) { return }
    
    $rg = Select-ResourceGroup
    if (-not $rg) { return }
    
    $cluster = Select-AKSCluster -ResourceGroupName $rg.name
    if (-not $cluster) { 
        Read-Host "`nPress Enter"
        return 
    }
    
    Write-Host "`nRetrieving access configuration for: $($cluster.name)..." -ForegroundColor Yellow
    
    # Get detailed access profile
    $accessProfile = az aks show `
        --resource-group $rg.name `
        --name $cluster.name `
        --query "{publicFQDN:apiServerAccessProfile.enablePublicFqdn, privateCluster:apiServerAccessProfile.enablePrivateCluster, authorizedIPs:apiServerAccessProfile.authorizedIpRanges, fqdn:fqdn, privateFqdn:privateFqdn}" `
        --output json | ConvertFrom-Json
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "`nFailed to retrieve cluster information" -ForegroundColor Red
        Read-Host "Press Enter"
        return
    }
    
    # Display results
    Write-Host "`n=== API Server Access Configuration ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Cluster: " -NoNewline
    Write-Host "$($cluster.name)" -ForegroundColor White
    Write-Host "Resource Group: " -NoNewline
    Write-Host "$($rg.name)" -ForegroundColor White
    Write-Host ""
    
    # Private Cluster Status
    Write-Host "Private Cluster: " -NoNewline
    if ($accessProfile.privateCluster -eq $true) {
        Write-Host "ENABLED" -ForegroundColor Green
        Write-Host "  - Private FQDN: $($accessProfile.privateFqdn)" -ForegroundColor Gray
    } else {
        Write-Host "DISABLED" -ForegroundColor Yellow
    }
    
    # Public FQDN Status
    Write-Host "Public FQDN: " -NoNewline
    if ($accessProfile.publicFQDN -eq $true) {
        Write-Host "ENABLED" -ForegroundColor Green
        Write-Host "  - FQDN: $($accessProfile.fqdn)" -ForegroundColor Gray
    } elseif ($accessProfile.publicFQDN -eq $false) {
        Write-Host "DISABLED" -ForegroundColor Red
    } else {
        Write-Host "N/A (Public cluster)" -ForegroundColor Yellow
        Write-Host "  - FQDN: $($accessProfile.fqdn)" -ForegroundColor Gray
    }
    
    # Authorized IP Ranges
    Write-Host "`nAuthorized IP Ranges: " -NoNewline
    if ($accessProfile.authorizedIPs -and $accessProfile.authorizedIPs.Count -gt 0) {
        Write-Host "CONFIGURED" -ForegroundColor Green
        foreach ($ip in $accessProfile.authorizedIPs) {
            Write-Host "  - $ip" -ForegroundColor Gray
        }
    } else {
        Write-Host "NOT CONFIGURED" -ForegroundColor Yellow
        Write-Host "  - All IPs allowed (not recommended for production)" -ForegroundColor Gray
    }
    
    # Security Recommendations
    Write-Host "`n=== Security Recommendations ===" -ForegroundColor Cyan
    
    if ($accessProfile.privateCluster -ne $true) {
        Write-Host "[!] " -ForegroundColor Yellow -NoNewline
        Write-Host "Consider enabling private cluster for better security"
    }
    
    if (-not $accessProfile.authorizedIPs -or $accessProfile.authorizedIPs.Count -eq 0) {
        Write-Host "[!] " -ForegroundColor Yellow -NoNewline
        Write-Host "Configure authorized IP ranges to restrict access"
    }
    
    if ($accessProfile.privateCluster -eq $true -and $accessProfile.authorizedIPs) {
        Write-Host "[OK] " -ForegroundColor Green -NoNewline
        Write-Host "Good security posture - private cluster with IP restrictions"
    }
    
    Read-Host "`nPress Enter"
}

function Enable-PrivateCluster {
    Write-Host "`n=== Enable Private Cluster ===" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "IMPORTANT NOTES:" -ForegroundColor Red
    Write-Host "- Private cluster can only be enabled during cluster creation" -ForegroundColor Yellow
    Write-Host "- Existing public clusters cannot be converted to private" -ForegroundColor Yellow
    Write-Host "- You must create a NEW cluster with --enable-private-cluster flag" -ForegroundColor Yellow
    Write-Host ""
    
    $choice = Read-Host "Do you want to create a new private AKS cluster? (yes/no)"
    if ($choice -ne "yes") {
        Write-Host "Operation cancelled" -ForegroundColor Red
        Read-Host "`nPress Enter"
        return
    }
    
    if (-not (Select-Subscription)) { return }
    
    $rg = Select-ResourceGroup -Prompt "Select resource group for new cluster"
    if (-not $rg) { return }
    
    Write-Host "`n--- Cluster Configuration ---" -ForegroundColor Cyan
    $clusterName = Read-Host "Enter new cluster name"
    
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
    
    # Additional configuration options
    Write-Host "`n--- Additional Options (press Enter to use defaults) ---" -ForegroundColor Cyan
    
    $nodeCount = Read-Host "Node count (default: 3)"
    if ([string]::IsNullOrWhiteSpace($nodeCount)) { $nodeCount = "3" }
    
    $nodeSize = Read-Host "Node VM size (default: Standard_DS2_v2)"
    if ([string]::IsNullOrWhiteSpace($nodeSize)) { $nodeSize = "Standard_DS2_v2" }
    
    $enablePublicFqdn = Read-Host "Enable public FQDN? (yes/no, default no)"
    
    # Confirm configuration
    Write-Host "`n--- Configuration Summary ---" -ForegroundColor Yellow
    Write-Host "Cluster Name: $clusterName"
    Write-Host "Resource Group: $($rg.name)"
    Write-Host "Location: $($rg.location)"
    Write-Host "Node Count: $nodeCount"
    Write-Host "Node Size: $nodeSize"
    Write-Host "Private Cluster: Enabled"
    Write-Host "Public FQDN: $(if ($enablePublicFqdn -eq 'yes') { 'Enabled' } else { 'Disabled' })"
    
    $confirm = Read-Host "`nCreate private cluster? (yes/no)"
    if ($confirm -ne "yes") {
        Write-Host "Operation cancelled" -ForegroundColor Red
        Read-Host "`nPress Enter"
        return
    }
    
    Write-Host "`nCreating private AKS cluster..." -ForegroundColor Yellow
    Write-Host "This may take 10-15 minutes..." -ForegroundColor Gray
    Write-Host "Started: $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Gray
    
    # Build command
    $command = "az aks create --resource-group $($rg.name) --name $clusterName --enable-private-cluster --node-count $nodeCount --node-vm-size $nodeSize --generate-ssh-keys"
    
    if ($enablePublicFqdn -eq "yes") {
        $command += " --enable-public-fqdn"
    }
    
    Write-Host "`nExecuting: $command" -ForegroundColor Gray
    
    $result = Invoke-Expression "$command --output json 2>&1"
    
    Write-Host "Completed: $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Gray
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n=== SUCCESS ===" -ForegroundColor Green
        Write-Host "Private cluster created successfully!"
        Write-Host ""
        Write-Host "Next steps:" -ForegroundColor Cyan
        Write-Host "1. Get credentials: az aks get-credentials -g $($rg.name) -n $clusterName"
        Write-Host "2. To access the private cluster, you need to be in the same VNet or use VPN/ExpressRoute"
        Write-Host "3. Alternatively, create a jump box VM in the same VNet"
    } else {
        Write-Host "`n=== FAILED ===" -ForegroundColor Red
        Write-Host $result
        Write-Host "`nCommon issues:" -ForegroundColor Yellow
        Write-Host "- Cluster name already exists"
        Write-Host "- Insufficient quota in region"
        Write-Host "- Invalid VM size"
    }
    
    Read-Host "`nPress Enter"
}

function Restrict-AccessByIP {
    Write-Host "`n=== Restrict Access by Authorized IP Ranges ===" -ForegroundColor Yellow
    
    if (-not (Select-Subscription)) { return }
    
    $rg = Select-ResourceGroup
    if (-not $rg) { return }
    
    $cluster = Select-AKSCluster -ResourceGroupName $rg.name
    if (-not $cluster) { 
        Read-Host "`nPress Enter"
        return 
    }
    
    # Show current configuration
    Write-Host "`nCurrent authorized IP ranges:" -ForegroundColor Cyan
    $currentIPs = az aks show `
        --resource-group $rg.name `
        --name $cluster.name `
        --query "apiServerAccessProfile.authorizedIpRanges" `
        --output json | ConvertFrom-Json
    
    if ($currentIPs -and $currentIPs.Count -gt 0) {
        foreach ($ip in $currentIPs) {
            Write-Host "  - $ip" -ForegroundColor Gray
        }
    } else {
        Write-Host "  - None (all IPs allowed)" -ForegroundColor Yellow
    }
    
    # Check if private cluster
    $isPrivate = az aks show `
        --resource-group $rg.name `
        --name $cluster.name `
        --query "apiServerAccessProfile.enablePrivateCluster" `
        --output tsv
    
    if ($isPrivate -eq "true") {
        Write-Host "`nWARNING: This is a private cluster." -ForegroundColor Yellow
        Write-Host "IP restrictions apply only to public access (if enabled)." -ForegroundColor Yellow
        Write-Host ""
    }
    
    Write-Host "`n--- Configuration Options ---" -ForegroundColor Cyan
    Write-Host "1. Add/Update IP ranges"
    Write-Host "2. Remove all IP restrictions (allow all)"
    Write-Host "3. Get my current public IP"
    Write-Host "4. Cancel"
    
    $option = Read-Host "`nSelect option"
    
    switch ($option) {
        '1' {
            Write-Host "`n--- Add/Update IP Ranges ---" -ForegroundColor Cyan
            Write-Host "Enter IP ranges in CIDR notation (e.g. 203.0.113.0/24)" -ForegroundColor Gray
            Write-Host "Separate multiple ranges with commas (e.g. 203.0.113.0/24,198.51.100.0/24)" -ForegroundColor Gray
            Write-Host "Press Enter without input to add your current public IP" -ForegroundColor Gray
            Write-Host ""
            
            $ipRanges = Read-Host "IP ranges"
            
            # If empty, get current public IP
            if ([string]::IsNullOrWhiteSpace($ipRanges)) {
                Write-Host "`nGetting your current public IP..." -ForegroundColor Yellow
                try {
                    $myIP = (Invoke-WebRequest -Uri "https://api.ipify.org" -UseBasicParsing).Content.Trim()
                    Write-Host "Your public IP: $myIP" -ForegroundColor Green
                    $ipRanges = "$myIP/32"
                    Write-Host "Will use: $ipRanges" -ForegroundColor Cyan
                } catch {
                    Write-Host "Failed to get public IP: $_" -ForegroundColor Red
                    Read-Host "`nPress Enter"
                    return
                }
            }
            
            Write-Host "`n--- Configuration Summary ---" -ForegroundColor Yellow
            Write-Host "Cluster: $($cluster.name)"
            Write-Host "Resource Group: $($rg.name)"
            Write-Host "Authorized IP Ranges: $ipRanges"
            
            $confirm = Read-Host "`nApply IP restrictions? (yes/no)"
            if ($confirm -ne "yes") {
                Write-Host "Operation cancelled" -ForegroundColor Red
                Read-Host "`nPress Enter"
                return
            }
            
            Write-Host "`nUpdating API server authorized IP ranges..." -ForegroundColor Yellow
            Write-Host "This may take 2-3 minutes..." -ForegroundColor Gray
            
            $result = az aks update `
                --resource-group $rg.name `
                --name $cluster.name `
                --api-server-authorized-ip-ranges $ipRanges `
                --output json 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "`n=== SUCCESS ===" -ForegroundColor Green
                Write-Host "IP restrictions applied successfully!"
                Write-Host "`nAuthorized IP ranges:" -ForegroundColor Cyan
                $ipRanges -split ',' | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }
                Write-Host "`nNOTE: Only these IPs can access the API server" -ForegroundColor Yellow
            } else {
                Write-Host "`n=== FAILED ===" -ForegroundColor Red
                Write-Host $result
                Write-Host "`nCommon issues:" -ForegroundColor Yellow
                Write-Host "- Invalid CIDR format"
                Write-Host "- Maximum 200 IP ranges allowed"
                Write-Host "- Cannot use with fully private cluster (without public FQDN)"
            }
        }
        
        '2' {
            Write-Host "`nWARNING: This will allow ALL IPs to access the API server!" -ForegroundColor Red
            $confirm = Read-Host "Are you sure? (yes/no)"
            
            if ($confirm -ne "yes") {
                Write-Host "Operation cancelled" -ForegroundColor Red
                Read-Host "`nPress Enter"
                return
            }
            
            Write-Host "`nRemoving IP restrictions..." -ForegroundColor Yellow
            
            $result = az aks update `
                --resource-group $rg.name `
                --name $cluster.name `
                --api-server-authorized-ip-ranges "" `
                --output json 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "`n=== SUCCESS ===" -ForegroundColor Green
                Write-Host "IP restrictions removed - all IPs now allowed"
                Write-Host "`nWARNING: This is not recommended for production!" -ForegroundColor Red
            } else {
                Write-Host "`n=== FAILED ===" -ForegroundColor Red
                Write-Host $result
            }
        }
        
        '3' {
            Write-Host "`nGetting your current public IP..." -ForegroundColor Yellow
            try {
                $myIP = (Invoke-WebRequest -Uri "https://api.ipify.org" -UseBasicParsing).Content.Trim()
                Write-Host "`nYour public IP: " -NoNewline
                Write-Host "$myIP" -ForegroundColor Green
                Write-Host "CIDR notation: " -NoNewline
                Write-Host "$myIP/32" -ForegroundColor Cyan
                Write-Host "`nUse this value when adding IP ranges (option 1)" -ForegroundColor Gray
            } catch {
                Write-Host "Failed to get public IP: $_" -ForegroundColor Red
            }
        }
        
        '4' {
            Write-Host "Operation cancelled" -ForegroundColor Red
        }
        
        default {
            Write-Host "Invalid option" -ForegroundColor Red
        }
    }
    
    Read-Host "`nPress Enter"
}

# Main Loop
do {
    Show-Menu
    $choice = Read-Host "Select option (1-4)"
    
    switch ($choice) {
        '1' { Check-APIServerAccess }
        '2' { Enable-PrivateCluster }
        '3' { Restrict-AccessByIP }
        '4' { 
            Write-Host "`nGoodbye!" -ForegroundColor Green
            exit 
        }
        default {
            Write-Host "`nInvalid choice" -ForegroundColor Red
            Start-Sleep -Seconds 2
        }
    }
} while ($choice -ne '4')
