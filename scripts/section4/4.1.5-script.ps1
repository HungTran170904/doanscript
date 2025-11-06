param(
    [string]$EnableModify
)

function CheckDefaultSAUsage {
    param (
        [object]$PodsJson
    )

    $results = @()
    foreach ($pod in $PodsJson.items) {
        if ($pod.spec.serviceAccountName -eq "default") {
            $results += [PSCustomObject]@{
                Namespace = $pod.metadata.namespace
                PodName = $pod.metadata.name
            }
        }
    }
    
    return $results
}

function UpdateDefaultSAConfig{
    $namespaces = kubectl get ns -o json | ConvertFrom-Json | Select-Object -ExpandProperty items | ForEach-Object { $_.metadata.name }
    
    foreach ($ns in $namespaces) {
        Write-Host "Processing namespace '$ns'..." -ForegroundColor Cyan

        # Update default SA to disable token mount
        $defaultSA = kubectl get sa default -n $ns -o json | ConvertFrom-Json
        if (-not ($defaultSA | Get-Member -Name automountServiceAccountToken)) {
            $defaultSA | Add-Member -NotePropertyName automountServiceAccountToken -NotePropertyValue $false
        } else {
            $defaultSA.automountServiceAccountToken = $false
        }
        $defaultSA | ConvertTo-Json -Depth 10 | kubectl apply -f -

        # Delete RoleBindings pointing to default SA
        $roleBindings = kubectl get rolebinding -n $ns -o json | ConvertFrom-Json
        foreach ($rb in $roleBindings.items) {
            foreach ($subject in @($rb.subjects)) {
                if ($subject.kind -eq "ServiceAccount" -and $subject.name -eq "default") {
                    Write-Host "Deleting RoleBinding '$($rb.metadata.name)' in namespace '$ns'..." -ForegroundColor Yellow
                    kubectl delete rolebinding $rb.metadata.name -n $ns
                }
            }
        }

        # Delete ClusterRoleBindings pointing to default SA
        $clusterRoleBindings = kubectl get clusterrolebinding -o json | ConvertFrom-Json
        foreach ($crb in $clusterRoleBindings.items) {
            foreach ($subject in @($crb.subjects)) {
                if ($subject.kind -eq "ServiceAccount" -and $subject.name -eq "default" -and $subject.namespace -eq $ns) {
                    Write-Host "Deleting ClusterRoleBinding '$($crb.metadata.name)' for default SA in namespace '$ns'..." -ForegroundColor Yellow
                    kubectl delete clusterrolebinding $crb.metadata.name
                }
            }
        }
    }
    Write-Host "Default ServiceAccounts hardened successfully." -ForegroundColor Green
}

# --- Main Script ---
Write-Host "----Checking section 4.1.5: Ensure that default service accounts are not actively used----" -ForegroundColor Yellow

# Check default service account usage
$podsJson = kubectl get pods --all-namespaces -o json | ConvertFrom-Json
$results = CheckDefaultSAUsage -PodsJson $podsJson
if ($results.Count -eq 0) {
    Write-Host "No pods are using the default service account." -ForegroundColor Green
} else {
    Write-Host "Default service account is in use in these pods:" -ForegroundColor Yellow
    $results | Format-Table -AutoSize

    if ($EnableModify -eq "true"){
        UpdateDefaultSAConfig
    }
}