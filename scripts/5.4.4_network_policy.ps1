# AKS Network Policy Management Tool
# CIS Benchmark 5.4.4 - Ensure Network Policy is Enabled

function Show-Menu {
    Clear-Host
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  AKS Network Policy Management" -ForegroundColor Cyan
    Write-Host "  CIS Benchmark 5.4.4" -ForegroundColor Gray
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. Check Network Policy Engine status"
    Write-Host "2. Install Calico Network Policy"
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

function Check-NetworkPolicy {
    Write-Host "`n=== Check Network Policy Status ===" -ForegroundColor Yellow
    Write-Host "CIS Benchmark 5.4.4: Ensure Network Policy is Enabled" -ForegroundColor Gray
    Write-Host ""
    
    if (-not (Select-Subscription)) { return }
    
    $rg = Select-ResourceGroup
    if (-not $rg) { return }
    
    $cluster = Select-AKSCluster -ResourceGroupName $rg.name
    if (-not $cluster) { 
        Read-Host "`nPress Enter"
        return 
    }
    
    Write-Host "`nChecking Network Policy configuration for: $($cluster.name)..." -ForegroundColor Yellow
    
    # Get network policy configuration
    $networkPolicy = az aks show `
        --name $cluster.name `
        --resource-group $rg.name `
        --query "networkProfile.networkPolicy" `
        --output tsv
    
    # Get additional network profile information
    $networkProfile = az aks show `
        --name $cluster.name `
        --resource-group $rg.name `
        --query "networkProfile.{networkPolicy:networkPolicy, networkPlugin:networkPlugin, networkMode:networkMode, podCidr:podCidr, serviceCidr:serviceCidr, dnsServiceIP:dnsServiceIp}" `
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
    
    # Network Policy Status (CIS Benchmark check)
    Write-Host "Network Policy Engine: " -NoNewline
    
    if ([string]::IsNullOrWhiteSpace($networkPolicy) -or $networkPolicy -eq "null" -or $networkPolicy -eq "none") {
        if ($networkPolicy -eq "none") {
            Write-Host "none" -ForegroundColor Red
        } else {
            Write-Host "NOT CONFIGURED" -ForegroundColor Red
        }
        Write-Host "  Status: " -NoNewline
        Write-Host "NON-COMPLIANT" -ForegroundColor Red -BackgroundColor DarkRed
    } else {
        Write-Host "$networkPolicy" -ForegroundColor Green
        Write-Host "  Status: " -NoNewline
        Write-Host "COMPLIANT" -ForegroundColor Green -BackgroundColor DarkGreen
    }
    
    Write-Host ""
    Write-Host "--- Network Profile ---" -ForegroundColor Cyan
    
    # Network Plugin
    Write-Host "Network Plugin: " -NoNewline
    if ($networkProfile.networkPlugin) {
        Write-Host "$($networkProfile.networkPlugin)" -ForegroundColor Gray
    } else {
        Write-Host "Not configured" -ForegroundColor Yellow
    }
    
    # Network Mode
    if ($networkProfile.networkMode) {
        Write-Host "Network Mode: $($networkProfile.networkMode)" -ForegroundColor Gray
    }
    
    # Pod CIDR
    if ($networkProfile.podCidr) {
        Write-Host "Pod CIDR: $($networkProfile.podCidr)" -ForegroundColor Gray
    }
    
    # Service CIDR
    if ($networkProfile.serviceCidr) {
        Write-Host "Service CIDR: $($networkProfile.serviceCidr)" -ForegroundColor Gray
    }
    
    # DNS Service IP
    if ($networkProfile.dnsServiceIP) {
        Write-Host "DNS Service IP: $($networkProfile.dnsServiceIP)" -ForegroundColor Gray
    }
    
    # CIS Benchmark Explanation
    Write-Host "`n--- CIS Benchmark 5.4.4 ---" -ForegroundColor Cyan
    Write-Host "Requirement: Network Policy must be enabled and configured" -ForegroundColor Gray
    Write-Host "Purpose: Control traffic flow between pods using least privilege" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Supported Network Policy Engines:" -ForegroundColor Gray
    Write-Host "  - Azure Network Policy Manager" -ForegroundColor Gray
    Write-Host "  - Calico (recommended)" -ForegroundColor Gray
    Write-Host "  - Cilium (Azure CNI Overlay)" -ForegroundColor Gray
    
    # Security Benefits and Recommendations
    Write-Host "`n--- Security Analysis ---" -ForegroundColor Cyan
    
    if ([string]::IsNullOrWhiteSpace($networkPolicy) -or $networkPolicy -eq "null" -or $networkPolicy -eq "none") {
        Write-Host "[!] CRITICAL: Network Policy is NOT enabled" -ForegroundColor Red
        Write-Host ""
        Write-Host "Risks without Network Policy:" -ForegroundColor Yellow
        Write-Host "  - All pods can communicate without restrictions" -ForegroundColor Red
        Write-Host "  - No traffic segmentation or isolation" -ForegroundColor Red
        Write-Host "  - Backend services exposed to all pods" -ForegroundColor Red
        Write-Host "  - Database accessible from any pod" -ForegroundColor Red
        Write-Host "  - Increased attack surface" -ForegroundColor Red
        Write-Host ""
        Write-Host "Recommendations:" -ForegroundColor Cyan
        Write-Host "  1. Install Calico or Azure Network Policy (Option 2)" -ForegroundColor Yellow
        Write-Host "  2. Define NetworkPolicy rules for pod communication" -ForegroundColor Yellow
        Write-Host "  3. Apply least privilege principle to traffic flow" -ForegroundColor Yellow
    } else {
        Write-Host "[OK] Network Policy is enabled with: $networkPolicy" -ForegroundColor Green
        Write-Host ""
        Write-Host "Security Benefits:" -ForegroundColor Green
        Write-Host "  [OK] Traffic control between pods" -ForegroundColor Green
        Write-Host "  [OK] Least privilege network access" -ForegroundColor Green
        Write-Host "  [OK] Backend service protection" -ForegroundColor Green
        Write-Host "  [OK] Network segmentation capability" -ForegroundColor Green
        
        Write-Host "`nNext Steps:" -ForegroundColor Cyan
        Write-Host "  1. Create NetworkPolicy YAML manifests" -ForegroundColor Gray
        Write-Host "  2. Define ingress/egress rules for pods" -ForegroundColor Gray
        Write-Host "  3. Apply policies using: kubectl apply -f <policy.yaml>" -ForegroundColor Gray
        Write-Host "  4. Test and verify traffic restrictions" -ForegroundColor Gray
    }
    
    # Resource Requirements Warning
    if ([string]::IsNullOrWhiteSpace($networkPolicy) -or $networkPolicy -eq "null" -or $networkPolicy -eq "none") {
        Write-Host "`n--- Resource Requirements ---" -ForegroundColor Cyan
        Write-Host "Before enabling Network Policy:" -ForegroundColor Yellow
        Write-Host "  - Minimum 2 nodes (recommended: 3 nodes)" -ForegroundColor Gray
        Write-Host "  - Additional memory: ~128MB per node" -ForegroundColor Gray
        Write-Host "  - Additional CPU: ~300 millicores per node" -ForegroundColor Gray
        Write-Host "  - Rolling update will occur (similar to cluster upgrade)" -ForegroundColor Gray
        Write-Host "  - Operation may take 15-30 minutes" -ForegroundColor Gray
    }
    
    # Network Policy Examples
    if ($networkPolicy -eq "calico" -or $networkPolicy -eq "azure") {
        Write-Host "`n--- Example NetworkPolicy ---" -ForegroundColor Cyan
        Write-Host "Basic deny-all policy:" -ForegroundColor Gray
        Write-Host @"
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
  namespace: default
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
"@ -ForegroundColor DarkGray
    }
    
    Read-Host "`nPress Enter"
}

function Install-CalicoNetworkPolicy {
    Write-Host "`n=== Install Calico Network Policy ===" -ForegroundColor Yellow
    Write-Host "CIS Benchmark 5.4.4 Remediation" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "IMPORTANT WARNINGS:" -ForegroundColor Red
    Write-Host "- This operation triggers a ROLLING UPDATE of ALL node pools" -ForegroundColor Yellow
    Write-Host "- Each node will be RE-IMAGED simultaneously" -ForegroundColor Yellow
    Write-Host "- Operation is LONG-RUNNING (15-30 minutes)" -ForegroundColor Yellow
    Write-Host "- Similar disruption to cluster upgrade operation" -ForegroundColor Yellow
    Write-Host "- Buffer nodes added temporarily to minimize disruption" -ForegroundColor Yellow
    Write-Host "- Cluster operations (including delete) will be blocked" -ForegroundColor Yellow
    Write-Host ""
    
    Write-Host "Resource Requirements:" -ForegroundColor Cyan
    Write-Host "- Minimum 2 nodes (recommended: 3+ nodes)" -ForegroundColor Gray
    Write-Host "- Additional ~128MB memory per node" -ForegroundColor Gray
    Write-Host "- Additional ~300 millicores CPU per node" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "About Calico:" -ForegroundColor Cyan
    Write-Host "- Open-source network policy engine" -ForegroundColor Gray
    Write-Host "- Provides network segmentation and isolation" -ForegroundColor Gray
    Write-Host "- Supports advanced network policies" -ForegroundColor Gray
    Write-Host "- Production-ready and widely used" -ForegroundColor Gray
    Write-Host ""
    
    $confirm = Read-Host "Do you want to proceed with Calico installation? (yes/no)"
    if ($confirm -ne "yes") {
        Write-Host "Operation cancelled" -ForegroundColor Red
        Read-Host "`nPress Enter"
        return
    }
    
    if (-not (Select-Subscription)) { return }
    
    $rg = Select-ResourceGroup
    if (-not $rg) { return }
    
    $cluster = Select-AKSCluster -ResourceGroupName $rg.name
    if (-not $cluster) { 
        Read-Host "`nPress Enter"
        return 
    }
    
    # Check current network policy status
    Write-Host "`nChecking current configuration..." -ForegroundColor Yellow
    
    $currentPolicy = az aks show `
        --name $cluster.name `
        --resource-group $rg.name `
        --query "networkProfile.networkPolicy" `
        --output tsv
    
    $networkPlugin = az aks show `
        --name $cluster.name `
        --resource-group $rg.name `
        --query "networkProfile.networkPlugin" `
        --output tsv
    
    Write-Host "Current Network Policy: " -NoNewline
    if ([string]::IsNullOrWhiteSpace($currentPolicy) -or $currentPolicy -eq "null") {
        Write-Host "None" -ForegroundColor Yellow
    } else {
        Write-Host "$currentPolicy" -ForegroundColor Cyan
    }
    
    Write-Host "Network Plugin: $networkPlugin" -ForegroundColor Gray
    
    # Check if already using Calico
    if ($currentPolicy -eq "calico") {
        Write-Host "`nCalico is already installed on this cluster!" -ForegroundColor Green
        Read-Host "`nPress Enter"
        return
    }
    
    # Check if another policy engine is installed
    if (![string]::IsNullOrWhiteSpace($currentPolicy) -and $currentPolicy -ne "null") {
        Write-Host "`nWARNING: This cluster already has '$currentPolicy' network policy installed" -ForegroundColor Yellow
        Write-Host "Switching from one network policy engine to another may cause disruptions" -ForegroundColor Yellow
        $switchConfirm = Read-Host "Continue anyway? (yes/no)"
        if ($switchConfirm -ne "yes") {
            Write-Host "Operation cancelled" -ForegroundColor Red
            Read-Host "`nPress Enter"
            return
        }
    }
    
    # Special warning for Kubenet + Calico -> Azure CNI Overlay + Calico
    if ($networkPlugin -eq "kubenet") {
        Write-Host "`nIMPORTANT - Kubenet Cluster Notice:" -ForegroundColor Yellow
        Write-Host "- In Kubenet clusters: Calico is used as both CNI and network policy" -ForegroundColor Gray
        Write-Host "- In Azure CNI clusters: Calico is only for network policy enforcement" -ForegroundColor Gray
        Write-Host "- This can cause a short delay for pod outbound traffic" -ForegroundColor Gray
        Write-Host "- Consider using Cilium instead if upgrading to Azure CNI Overlay" -ForegroundColor Gray
        Write-Host ""
    }
    
    # Final confirmation
    Write-Host "`n--- Configuration Summary ---" -ForegroundColor Yellow
    Write-Host "Cluster: $($cluster.name)"
    Write-Host "Resource Group: $($rg.name)"
    Write-Host "Current Network Policy: $(if ([string]::IsNullOrWhiteSpace($currentPolicy) -or $currentPolicy -eq 'null') { 'None' } else { $currentPolicy })"
    Write-Host "New Network Policy: Calico" -ForegroundColor Green
    Write-Host "Operation: Rolling update of all nodes"
    Write-Host "Estimated Time: 15-30 minutes"
    Write-Host ""
    
    $finalConfirm = Read-Host "Install Calico Network Policy? (yes/no)"
    if ($finalConfirm -ne "yes") {
        Write-Host "Operation cancelled" -ForegroundColor Red
        Read-Host "`nPress Enter"
        return
    }
    
    # Ask about quota limitations (for student accounts)
    Write-Host "`nDo you have vCPU quota limitations? (e.g. Azure Student account)" -ForegroundColor Cyan
    Write-Host "If yes, we'll disable surge nodes (--max-surge 0) to save quota" -ForegroundColor Gray
    $useMaxUnavailable = Read-Host "Limited quota? (yes/no, default: no)"
    
    Write-Host "`nInstalling Calico Network Policy..." -ForegroundColor Yellow
    Write-Host "This will take 15-30 minutes. Please be patient..." -ForegroundColor Gray
    Write-Host "Started: $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Gray
    
    if ($useMaxUnavailable -eq "yes") {
        Write-Host "Mode: Quota-saving (--max-surge 0, no buffer nodes)" -ForegroundColor Yellow
    } else {
        Write-Host "Mode: Standard (with surge nodes for faster update)" -ForegroundColor Gray
    }
    Write-Host ""
    
    # Execute installation
    if ($useMaxUnavailable -eq "yes") {
        # For limited quota: Disable surge by setting max-surge to 0
        # This avoids creating buffer nodes that consume vCPU quota
        Write-Host "Note: For system node pools, using max-surge 0 approach..." -ForegroundColor Gray
        
        # Get all node pools
        $nodePools = az aks nodepool list -g $rg.name --cluster-name $cluster.name --query "[].name" -o tsv
        
        # Update each node pool to disable surge
        foreach ($poolName in $nodePools) {
            Write-Host "  Configuring node pool: $poolName" -ForegroundColor Gray
            az aks nodepool update `
                --resource-group $rg.name `
                --cluster-name $cluster.name `
                --name $poolName `
                --max-surge 0 `
                --output none 2>&1 | Out-Null
        }
        
        Write-Host "Node pool configuration completed. Installing Calico..." -ForegroundColor Gray
        
        # Now update network policy
        $result = az aks update `
            --resource-group $rg.name `
            --name $cluster.name `
            --network-policy calico `
            --output json 2>&1
    } else {
        # Standard installation with surge nodes
        $result = az aks update `
            --resource-group $rg.name `
            --name $cluster.name `
            --network-policy calico `
            --output json 2>&1
    }
    
    Write-Host ""
    Write-Host "Completed: $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Gray
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n=== SUCCESS ===" -ForegroundColor Green
        Write-Host "Calico Network Policy installed successfully!" -ForegroundColor Green
        Write-Host ""
        Write-Host "CIS Benchmark 5.4.4: " -NoNewline
        Write-Host "COMPLIANT" -ForegroundColor Green -BackgroundColor DarkGreen
        Write-Host ""
        
        Write-Host "Calico Features Enabled:" -ForegroundColor Cyan
        Write-Host "[OK] Network policy enforcement" -ForegroundColor Green
        Write-Host "[OK] Pod-to-pod traffic control" -ForegroundColor Green
        Write-Host "[OK] Ingress/Egress rule support" -ForegroundColor Green
        Write-Host "[OK] Network segmentation" -ForegroundColor Green
        Write-Host ""
        
        Write-Host "Next Steps:" -ForegroundColor Cyan
        Write-Host "1. Verify installation:" -ForegroundColor Gray
        Write-Host "   kubectl get pods -n kube-system | grep calico" -ForegroundColor White
        Write-Host ""
        Write-Host "2. Create NetworkPolicy resources:" -ForegroundColor Gray
        Write-Host "   - Define ingress/egress rules for your pods" -ForegroundColor White
        Write-Host "   - Use label selectors to target specific pods" -ForegroundColor White
        Write-Host "   - Apply least privilege principle" -ForegroundColor White
        Write-Host ""
        Write-Host "3. Example NetworkPolicy YAML:" -ForegroundColor Gray
        Write-Host @"
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-policy
  namespace: default
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 8080
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: database
    ports:
    - protocol: TCP
      port: 5432
"@ -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "4. Apply policy:" -ForegroundColor Gray
        Write-Host "   kubectl apply -f network-policy.yaml" -ForegroundColor White
        Write-Host ""
        Write-Host "5. Test and verify traffic restrictions" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Documentation:" -ForegroundColor Cyan
        Write-Host "https://learn.microsoft.com/en-us/azure/aks/use-network-policies" -ForegroundColor Blue
        
    } else {
        Write-Host "`n=== FAILED ===" -ForegroundColor Red
        Write-Host $result
        Write-Host ""
        
        # Check for quota error
        if ($result -match "InsufficientVCPUQuota" -or $result -match "quota") {
            Write-Host "=== QUOTA LIMITATION DETECTED ===" -ForegroundColor Red
            Write-Host ""
            Write-Host "IMPORTANT: Azure Student accounts have ZERO remaining vCPU quota!" -ForegroundColor Red
            Write-Host "Network policy installation requires rolling update which needs temporary nodes." -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Unfortunately, you CANNOT install network policy on an existing cluster" -ForegroundColor Red
            Write-Host "with zero quota. Azure needs at least some quota for the update process." -ForegroundColor Red
            Write-Host ""
            
            Write-Host "=== SOLUTIONS ===" -ForegroundColor Cyan
            Write-Host ""
            
            Write-Host "Option 1: Create NEW cluster with Calico (RECOMMENDED)" -ForegroundColor Green
            Write-Host "  Network policy can be enabled during cluster creation WITHOUT needing extra quota:" -ForegroundColor Gray
            Write-Host ""
            Write-Host "  az aks create \" -ForegroundColor White
            Write-Host "    --resource-group $($rg.name) \" -ForegroundColor White
            Write-Host "    --name aks-with-calico \" -ForegroundColor White
            Write-Host "    --node-count 1 \" -ForegroundColor White
            Write-Host "    --node-vm-size Standard_B2s \" -ForegroundColor White
            Write-Host "    --network-plugin kubenet \" -ForegroundColor White
            Write-Host "    --network-policy calico \" -ForegroundColor White
            Write-Host "    --generate-ssh-keys" -ForegroundColor White
            Write-Host ""
            Write-Host "  Note: This creates a NEW cluster with Calico enabled from the start" -ForegroundColor Gray
            Write-Host ""
            
            Write-Host "Option 2: Request quota increase" -ForegroundColor Cyan
            Write-Host "  - Go to Azure Portal → Quotas" -ForegroundColor Gray
            Write-Host "  - Request increase for 'standardBSFamily' in 'japaneast'" -ForegroundColor Gray
            Write-Host "  - Wait for approval (may take 1-2 days)" -ForegroundColor Gray
            Write-Host "  - Link: https://learn.microsoft.com/en-us/azure/quotas/view-quotas" -ForegroundColor Blue
            Write-Host ""
            
            Write-Host "Option 3: Delete some resources to free up quota" -ForegroundColor Cyan
            Write-Host "  - Check current VMs in region: az vm list --query ""[?location=='japaneast']""" -ForegroundColor Gray
            Write-Host "  - Delete unused VMs or clusters" -ForegroundColor Gray
            Write-Host "  - Wait a few minutes for quota to be released" -ForegroundColor Gray
            Write-Host "  - Try again" -ForegroundColor Gray
            Write-Host ""
            
            Write-Host "Option 4: Use different region with available quota" -ForegroundColor Cyan
            Write-Host "  - Check quota in other regions: az vm list-usage --location eastus" -ForegroundColor Gray
            Write-Host "  - Create cluster in region with available quota" -ForegroundColor Gray
            Write-Host ""
            
            Write-Host "=== WHY THIS HAPPENS ===" -ForegroundColor Yellow
            Write-Host "Azure Student accounts have very limited quotas (typically 4 vCPUs total)." -ForegroundColor Gray
            Write-Host "Your current cluster is using ALL available quota (0 remaining)." -ForegroundColor Gray
            Write-Host "Network policy updates require temporary 'surge' nodes for rolling update," -ForegroundColor Gray
            Write-Host "even with --max-surge 0, the update process itself needs some capacity buffer." -ForegroundColor Gray
            Write-Host ""
            
            Write-Host "=== RECOMMENDATION ===" -ForegroundColor Green
            Write-Host "For learning/testing with Azure Student account:" -ForegroundColor Cyan
            Write-Host "1. Delete this cluster" -ForegroundColor White
            Write-Host "2. Create NEW cluster with --network-policy calico from the start" -ForegroundColor White
            Write-Host "3. Use 1 node with Standard_B2s (cheapest, fits in quota)" -ForegroundColor White
            Write-Host ""
        } else {
            Write-Host "Common issues:" -ForegroundColor Yellow
            Write-Host "- Insufficient nodes (need minimum 2 nodes)"
            Write-Host "- Cluster already has another network policy engine"
            Write-Host "- Insufficient resources on nodes"
            Write-Host "- Network plugin incompatibility"
            Write-Host "- Cluster is in failed or updating state"
            Write-Host ""
            Write-Host "Troubleshooting:" -ForegroundColor Cyan
            Write-Host "1. Check cluster state: az aks show -g $($rg.name) -n $($cluster.name) --query provisioningState"
            Write-Host "2. Verify node count: kubectl get nodes"
            Write-Host "3. Check node resources: kubectl top nodes"
            Write-Host "4. Review activity log in Azure Portal"
        }
    }
    
    Read-Host "`nPress Enter"
}

# Main Loop
do {
    Show-Menu
    $choice = Read-Host "Select option (1-3)"
    
    switch ($choice) {
        '1' { Check-NetworkPolicy }
        '2' { Install-CalicoNetworkPolicy }
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
