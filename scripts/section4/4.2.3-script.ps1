function CheckPrivilegedContainers {
    $podsJson = kubectl get pods --all-namespaces -o json | ConvertFrom-Json
    $results = @()
    
    foreach($pod in $podsJson.items){
        if ($pod.spec.hostPID -eq $true){
            $results += [PSCustomObject]@{
                Namespace = $pod.metadata.namespace
                PodName = $pod.metadata.name
            }
        }
    }

    return $results
}

# --- Main Script ---
Write-Host "----Checking section 4.2.3: Minimize the admission of containers wishing to share the host process ID namespace ----" -ForegroundColor Yellow

# Check default service account usage
$results = CheckPrivilegedContainers
if ($results.Count -eq 0) {
    Write-Host "No pods set hostPID to true." -ForegroundColor Green
} else {
    Write-Host "HostPID is enabled in these pods:" -ForegroundColor Yellow
    $results | Format-Table -AutoSize
}