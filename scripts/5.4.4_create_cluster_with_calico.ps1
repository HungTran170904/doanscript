# Quick Helper: Create AKS Cluster with Calico for Azure Student Accounts
# This script creates a minimal cluster with network policy enabled from the start

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Create AKS with Calico (Student)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This script creates a minimal AKS cluster with Calico network policy" -ForegroundColor Gray
Write-Host "Optimized for Azure Student accounts with limited quota" -ForegroundColor Gray
Write-Host ""

# Configuration
Write-Host "--- Configuration ---" -ForegroundColor Yellow
$resourceGroup = Read-Host "Resource group name (e.g., rg-aks-demo)"
$clusterName = Read-Host "Cluster name (e.g., aks-calico-demo)"
$location = Read-Host "Location (default: japaneast)"
if ([string]::IsNullOrWhiteSpace($location)) { $location = "japaneast" }

Write-Host ""
Write-Host "--- Cluster Specifications ---" -ForegroundColor Yellow
Write-Host "Node Count: 1 (minimal for student account)" -ForegroundColor Gray
Write-Host "Node Size: Standard_D2s_v3 (2 vCPU, 8GB RAM)" -ForegroundColor Gray
Write-Host "Network Plugin: kubenet (lightweight)" -ForegroundColor Gray
Write-Host "Network Policy: Calico (enabled from start)" -ForegroundColor Green
Write-Host "SSH Keys: Auto-generated" -ForegroundColor Gray
Write-Host ""

$confirm = Read-Host "Create cluster with above configuration? (yes/no)"
if ($confirm -ne "yes") {
    Write-Host "Cancelled" -ForegroundColor Red
    exit
}

Write-Host ""
Write-Host "Creating AKS cluster with Calico..." -ForegroundColor Yellow
Write-Host "This will take 5-10 minutes..." -ForegroundColor Gray
Write-Host "Started: $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

# Create cluster
$result = az aks create `
    --resource-group $resourceGroup `
    --name $clusterName `
    --location $location `
    --node-count 1 `
    --node-vm-size Standard_D2s_v3 `
    --network-plugin kubenet `
    --network-policy calico `
    --generate-ssh-keys `
    --output json 2>&1

Write-Host ""
Write-Host "Completed: $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Gray

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "=== SUCCESS ===" -ForegroundColor Green
    Write-Host "Cluster created with Calico network policy!" -ForegroundColor Green
    Write-Host ""
    Write-Host "CIS Benchmark 5.4.4: " -NoNewline
    Write-Host "COMPLIANT" -ForegroundColor Green -BackgroundColor DarkGreen
    Write-Host ""
    
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "1. Get credentials:" -ForegroundColor Gray
    Write-Host "   az aks get-credentials --resource-group $resourceGroup --name $clusterName" -ForegroundColor White
    Write-Host ""
    Write-Host "2. Verify Calico is running:" -ForegroundColor Gray
    Write-Host "   kubectl get pods -n kube-system | grep calico" -ForegroundColor White
    Write-Host ""
    Write-Host "3. Create NetworkPolicy:" -ForegroundColor Gray
    Write-Host "   kubectl apply -f <your-network-policy.yaml>" -ForegroundColor White
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "=== FAILED ===" -ForegroundColor Red
    Write-Host $result
    Write-Host ""
    Write-Host "Common issues:" -ForegroundColor Yellow
    Write-Host "- Resource group doesn't exist (create it first)"
    Write-Host "- Still insufficient quota (check with: az vm list-usage --location $location)"
    Write-Host "- Cluster name already exists"
    Write-Host ""
}
