param(
    [string]$EnableModify
)

function CheckServiceAccounts {
    $results = @()
    $serviceAccountsJson = kubectl get sa --all-namespaces -o json | ConvertFrom-json
    
    foreach($sa in $serviceAccountsJson.items) {
        if ($sa.automountServiceAccountToken -ne $false) {
            $results += [PSCustomObject]@{
                Namespace = $sa.metadata.namespace
                ServiceAccountName = $sa.metadata.name
            }
        }
    }

    return $results
}

function UpdateServiceAccounts {
    param (
        [object]$SAEntries
    )

    foreach($saEntry in $SAEntries) {
        $parts = $saEntry -split "/"
        if ($parts.Count -ne 2) {
            Write-Host "Skipping invalid SA entry: $saEntry" -ForegroundColor Red
            continue
        }
        $ns = $parts[0]
        $saName = $parts[1]
        
        $sa = kubectl get sa $saName -n $ns -o json | ConvertFrom-json
        if($sa.automountServiceAccountToken -ne $false){
            if (-not ($sa | Get-Member -Name automountServiceAccountToken)) {
                $sa | Add-Member -NotePropertyName automountServiceAccountToken -NotePropertyValue $false
            }
            else { $sa.automountServiceAccountToken = $false }
            $sa | ConvertTo-Json -Depth 10 | kubectl apply -f -
        }
    }
}

# --- Main Script ---
Write-Host "----Checking section 4.1.6: Ensure that Service Account Tokens are only mounted where necessary----" -ForegroundColor Yellow

$results = CheckServiceAccounts
if ($results.Count -eq 0) {
    Write-Host "No service accounts enabling automountServiceAccountToken" -ForegroundColor Green
} else {
    Write-Host "Tokens are enabled in use in these service accounts:" -ForegroundColor Yellow
    $results | Format-Table -AutoSize

    if ($EnableModify -eq "true"){
        Write-Host "Enter the list of service accounts to update (format: namespace/service-account-name, separated by commas):" -ForegroundColor Cyan
        $saEntriesStr = Read-Host
        $saEntries = $saEntriesStr -split "," | ForEach-Object { $_.Trim() }
        UpdateServiceAccounts -SAEntries $saEntries
    }
}