function CheckPrivilegedContainers {
    $podsJson = kubectl get pods -n free5gc -o json | ConvertFrom-Json
    $results = @()
    
    foreach($pod in $podsJson.items){
        if ($pod.spec.hostNetwork -eq $true){
            $results += [PSCustomObject]@{
                Namespace = $pod.metadata.namespace
                PodName = $pod.metadata.name
            }
        }
    }

    return $results
}

# --- Main Script ---
Write-Host "----Checking section 4.2.4: Minimize the admission of containers wishing to share the host network namespace ----" -ForegroundColor Yellow

# Check default service account usage
$results = CheckPrivilegedContainers
if ($results.Count -eq 0) {
    Write-Host "No pods set hostNetwork to true." -ForegroundColor Green
} else {
    Write-Host "HostNetwork is enabled in these pods:" -ForegroundColor Yellow
    $results | Format-Table -AutoSize
}