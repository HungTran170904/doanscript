param(
    [string]$EnableModify
)

function CheckNetworkPolicies {
    $namespaces = kubectl get ns -o json | ConvertFrom-Json | Select-Object -ExpandProperty items | ForEach-Object { $_.metadata.name }
    $results = @()

    foreach($ns in $namespaces){
        $networkPoliciesJson = kubectl get networkpolicy -n $ns -o json | ConvertFrom-Json
        if ($networkPoliciesJson.items.Count -eq 0){
            $results += [PSCustomObject]@{
                Namespace = $ns
            }
        }
    }

    return $results
}

function SetupDefaultDenyNetworkPolicy {
    param(
        [object]$Namespaces
    )

    # Define default deny ingress NetworkPolicy YAML
    $defaultNetworkPolicy = @'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
spec:
  podSelector: {}
  policyTypes:
    - Ingress
'@

    foreach ($ns in $Namespaces) {
        Write-Host "Applying default deny NetworkPolicy to namespace: $ns"
        $defaultNetworkPolicy | kubectl apply -n $ns -f -
    }
}

# --- Main Script ---
Write-Host "----Checking section 4.4.2: Ensure that all Namespaces have Network Policies defined ----" -ForegroundColor Yellow

# Check default service account usage
$results = CheckNetworkPolicies
if ($results.Count -eq 0) {
    Write-Host "All namespaces have network policies." -ForegroundColor Green
} else {
    Write-Host "No network policies is set in in these namespaces:" -ForegroundColor Yellow
    $results | Format-Table -AutoSize

    if ($EnableModify -eq "true") {
        Write-Host "Enter list of namespace names to apply default network policy (separated by commas):" -ForegroundColor Cyan
        $namespacesStr = Read-Host
        $namespaces = $namespacesStr -split "," | ForEach-Object { $_.Trim() }
        SetupDefaultDenyNetworkPolicy -Namespaces $namespaces
    }
}