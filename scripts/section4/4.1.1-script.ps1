param(
    [string]$EnableModify
)

function CheckBindingOfClusterAdminRole {
    param (
        [object]$ClusterRoleBindingsJson
    )

    $results = @()

    foreach ($binding in $ClusterRoleBindingsJson.items) {
        if ($binding.roleRef.name -eq "cluster-admin") {
            $results += [PSCustomObject]@{
                ClusterRoleBindingName = $binding.metadata.name
            }
        }
    }

    return $results
}

function RemoveBindingOfClusterAdminRole {
    # Prompt user
    Write-Host "Please enter list of unused cluster role bindings of role 'cluster-admin' (separated by ,):" -ForegroundColor Cyan
    $bindingsStr = Read-Host

    # Split and trim
    $bindings = $bindingsStr -split "," | ForEach-Object { $_.Trim() }

    # Delete each binding
    foreach ($binding in $bindings) {
        Write-Host "Deleting clusterrolebinding '$binding'..."
        kubectl delete clusterrolebinding $binding
    }
}

# --- Main Script ---
Write-Host "----Checking section 4.1.1: Ensure that the cluster-admin role is only used where required ----" -ForegroundColor Yellow

# Check
$clusterRoleBindingsJson = kubectl get clusterrolebinding -o json | ConvertFrom-Json
$results = CheckBindingOfClusterAdminRole -ClusterRoleBindingsJson $clusterRoleBindingsJson

# Display
if ($results.Count -eq 0) {
    Write-Host "No binding found to cluster role cluster-admin." -ForegroundColor Green
} else {
    Write-Host "Cluster role binding detected in the following RBAC definitions:" -ForegroundColor Yellow
    $results | Format-Table -AutoSize

    if ($EnableModify -eq "true"){
        RemoveBindingOfClusterAdminRole
    }
}