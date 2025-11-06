function CheckPrivilegedContainers {
    $podsJson = kubectl get pods -n free5gc -o json | ConvertFrom-Json
    $results = @()
    
    foreach($pod in $podsJson.items){
        $containers = $pod.spec.containers + $pod.spec.initContainers + $pod.spec.ephemeralContainers
        foreach($container in $containers){
            if ($container.securityContext.privileged -eq $true){
                $results += [PSCustomObject]@{
                    Namespace = $pod.metadata.namespace
                    PodName = $pod.metadata.name
                }
                break
            }
        }
    }

    return $results
}

# --- Main Script ---
Write-Host "----Checking section 4.2.1: Minimize the admission of privileged containers----" -ForegroundColor Yellow

# Check default service account usage
$results = CheckPrivilegedContainers
if ($results.Count -eq 0) {
    Write-Host "No pods have privileged security context." -ForegroundColor Green
} else {
    Write-Host "Privileged security context is enabled in these pods:" -ForegroundColor Yellow
    $results | Format-Table -AutoSize
}