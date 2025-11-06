param(
    [string]$EnableModify
)

function CheckMountedSAToken {
    param (
        [object]$PodsJson
    )

    $results = @()
    foreach ($pod in $PodsJson.items) {
        $hasMountToken = $false

        if (-not $pod.spec.automountServiceAccountToken) {
            $serviceAccountName = $pod.spec.serviceAccountName
            $sa = kubectl get sa $serviceAccountName -n $pod.metadata.namespace -o json | ConvertFrom-Json
            if ($sa.automountServiceAccountToken -eq $false){
                continue
            }
        }
        elseif ($pod.spec.automountServiceAccountToken -eq $false) {
            continue
        }

        $results += [PSCustomObject]@{
            Namespace = $pod.metadata.namespace
            PodName = $pod.metadata.name
        }
    }
    
    return $results
}

function UpdateMountedSAToken {
    param (
        [object]$PodsJson
    )
    
    $namespaces = kubectl get ns -o json | ConvertFrom-Json | Select-Object -ExpandProperty items | ForEach-Object { $_.metadata.name }
    foreach ($ns in $namespaces) {
        Write-Host "Processing namespace '$ns'..." -ForegroundColor Cyan

        # Disable token mount to all service accounts if not set
        $serviceAccountsJson = kubectl get sa -n $ns -o json | ConvertFrom-json
        foreach($sa in $serviceAccountsJson.items) {
            if (-not ($sa | Get-Member -Name automountServiceAccountToken)) {
                $sa | Add-Member -NotePropertyName automountServiceAccountToken -NotePropertyValue $false
                $sa | ConvertTo-Json -Depth 10 | kubectl apply -f -
            }
        }
    }

    foreach ($pod in $podsJson.items) {
        if (-not ($pod.spec | Get-Member -Name automountServiceAccountToken)) {
            $pod.spec | Add-Member -NotePropertyName automountServiceAccountToken -NotePropertyValue $false
            $pod | ConvertTo-Json -Depth 10 | kubectl apply -f -
        }
    }
}

# --- Main Script ---
Write-Host "----Checking section 4.1.6: Ensure that Service Account Tokens are only mounted where necessary----" -ForegroundColor Yellow

# Check default service account usage
$podsJson = kubectl get pods --all-namespaces -o json | ConvertFrom-Json
$results = CheckMountedSAToken -PodsJson $podsJson
if ($results.Count -eq 0) {
    Write-Host "No pods are mounted service account tokens." -ForegroundColor Green
} else {
    Write-Host "Service account tokens are in use in these pods:" -ForegroundColor Yellow
    $results | Format-Table -AutoSize

    if ($EnableModify -eq "true"){
        UpdateMountedSAToken -PodsJson $podsJson
    }
}