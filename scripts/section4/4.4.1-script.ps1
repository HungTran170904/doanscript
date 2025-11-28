param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $true)]
    [string]$ClusterName
)

Write-Host "Checking current AKS network policy..." -ForegroundColor Cyan
$networkPolicy = az aks show -g $ResourceGroup -n $ClusterName --query "networkProfile.networkPolicy" -o tsv

if (-not $networkPolicy -or $networkPolicy -eq "none") {
    Write-Host "`nThe current CNI does not support network policies." -ForegroundColor Yellow
    Write-Host "Please choose a network policy engine to install:`n"
    Write-Host "  1. Calico"
    Write-Host "  2. Azure NPM"
    Write-Host "  3. Cilium (overlay mode)"
    Write-Host "  4. None (skip installation)`n"

    $option = Read-Host "Enter your choice (1-4)"

    switch ($option) {
        "1" {
            Write-Host "`nInstalling Calico network policy..." -ForegroundColor Cyan
            az aks update -g $ResourceGroup -n $ClusterName --network-policy calico
        }
        "2" {
            Write-Host "`nInstalling Azure NPM network policy..." -ForegroundColor Cyan
            az aks update -g $ResourceGroup -n $ClusterName --network-policy azure
        }
        "3" {
            Write-Host "`nEnabling Cilium overlay mode..." -ForegroundColor Cyan
            az aks update -g $ResourceGroup -n $ClusterName --network-plugin azure --network-plugin-mode overlay
        }
        "4" {
            Write-Host "`nSkipping network policy installation." -ForegroundColor Yellow
        }
        Default {
            Write-Host "`nInvalid selection. Please run the script again and choose between 1-4." -ForegroundColor Red
        }
    }
}
else {
    Write-Host "`nThe cluster already has a network policy configured: $networkPolicy" -ForegroundColor Green
}