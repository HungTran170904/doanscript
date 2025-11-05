<#
CIS 5.2.1 - Service Account Management Script
Description: Interactive menu for managing ServiceAccounts in Kubernetes/AKS
Requirements: kubectl in PATH, kubeconfig configured
#>

function Test-Kubectl {
    # Check if kubectl command exists
    $kubectlCommand = Get-Command kubectl -ErrorAction SilentlyContinue
    if (-not $kubectlCommand) {
        Write-Host "Error: 'kubectl' is not available. Please install kubectl and configure kubeconfig." -ForegroundColor Red
        return $false
    }
    
    # Check if we can connect to cluster
    try {
        $null = kubectl cluster-info 2>&1
        if ($LASTEXITCODE -eq 0) {
            $kver = kubectl version --client -o json 2>$null | ConvertFrom-Json
            if ($kver.clientVersion) {
                Write-Host "kubectl: v$($kver.clientVersion.gitVersion)" -ForegroundColor Green
            } else {
                Write-Host "kubectl: Connected" -ForegroundColor Green
            }
            return $true
        } else {
            Write-Host "kubectl found but cannot connect to cluster. Check kubeconfig." -ForegroundColor Yellow
            Write-Host "Continuing with limited functionality..." -ForegroundColor Yellow
            return $true
        }
    } catch {
        Write-Host "Warning when checking kubectl: $_" -ForegroundColor Yellow
        return $true
    }
}

function List-AllServiceAccounts {
    Write-Host "`n--- List all ServiceAccounts (all namespaces) ---`n" -ForegroundColor Cyan
    kubectl get serviceaccounts --all-namespaces
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error running 'kubectl get serviceaccounts'." -ForegroundColor Red
    }
    Write-Host "`n(To view details of a specific SA: choose option 2 and enter SA name + namespace.)`n"
}

function Show-SA-Details {
    param(
        [string]$saName,
        [string]$ns
    )

    if ([string]::IsNullOrWhiteSpace($saName) -or [string]::IsNullOrWhiteSpace($ns)) {
        Write-Host "Service account name and namespace cannot be empty." -ForegroundColor Yellow
        return
    }

    Write-Host "`n--- YAML information for ServiceAccount '$saName' in namespace '$ns' ---`n" -ForegroundColor Cyan
    kubectl get serviceaccount $saName -n $ns -o yaml 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ServiceAccount $saName not found in namespace $ns." -ForegroundColor Red
        return
    }

    Write-Host "`n--- Pods using this ServiceAccount in namespace '$ns' ---`n" -ForegroundColor Cyan
    try {
        $podsJson = kubectl get pods -n $ns -o json
        if ($LASTEXITCODE -ne 0 -or -not $podsJson) {
            throw "Unable to get pod list."
        }

        $podsObj = $podsJson | ConvertFrom-Json
        $pods = @()
        if ($podsObj -and $podsObj.items) {
            $pods = $podsObj.items | Where-Object { $_.spec.serviceAccountName -eq $saName }
        }

        if ($pods -and $pods.Count -gt 0) {
            foreach ($p in $pods) {
                $name = $p.metadata.name
                $phase = $p.status.phase
                $node  = $p.spec.nodeName
                if ($null -eq $node -or [string]::IsNullOrWhiteSpace($node)) {
                    $nodeDisplay = "-"
                } else {
                    $nodeDisplay = $node
                }
                Write-Host ("{0,-40} {1,-10} {2}" -f $name, $phase, $nodeDisplay)
            }
        } else {
            Write-Host "No pods found using this service account in namespace $ns."
        }
    } catch {
        Write-Host "Unable to get pod list: $_" -ForegroundColor Red
    }

    Write-Host "`n--- RoleBindings (namespace-level) referencing this SA ---`n" -ForegroundColor Cyan
    try {
        $rbJson = kubectl get rolebinding --all-namespaces -o json
        if ($LASTEXITCODE -ne 0 -or -not $rbJson) { throw "Unable to get RoleBindings." }
        $rbItems = ($rbJson | ConvertFrom-Json).items
        $matchedRB = @()
        foreach ($rb in $rbItems) {
            if ($rb.subjects) {
                foreach ($s in $rb.subjects) {
                    if ($s.kind -eq "ServiceAccount" -and $s.name -eq $saName -and (($s.namespace -eq $ns) -or (-not $s.namespace))) {
                        $matchedRB += [PSCustomObject]@{
                            Namespace = $rb.metadata.namespace
                            Name      = $rb.metadata.name
                            RoleRef   = ($rb.roleRef.kind + "/" + $rb.roleRef.name)
                        }
                        break
                    }
                }
            }
        }
        if ($matchedRB.Count -gt 0) {
            $matchedRB | Format-Table -AutoSize
        } else {
            Write-Host "No RoleBindings found referencing this SA."
        }
    } catch {
        Write-Host "Error getting RoleBindings: $_" -ForegroundColor Red
    }

    Write-Host "`n--- ClusterRoleBindings referencing this SA ---`n" -ForegroundColor Cyan
    try {
        $crbJson = kubectl get clusterrolebinding -o json
        if ($LASTEXITCODE -ne 0 -or -not $crbJson) { throw "Unable to get ClusterRoleBindings." }
        $crbItems = ($crbJson | ConvertFrom-Json).items
        $matchedCRB = @()
        foreach ($crb in $crbItems) {
            if ($crb.subjects) {
                foreach ($s in $crb.subjects) {
                    if ($s.kind -eq "ServiceAccount" -and $s.name -eq $saName -and (($s.namespace -eq $ns) -or (-not $s.namespace))) {
                        $matchedCRB += [PSCustomObject]@{
                            Name    = $crb.metadata.name
                            RoleRef = ($crb.roleRef.kind + "/" + $crb.roleRef.name)
                        }
                        break
                    }
                }
            }
        }
        if ($matchedCRB.Count -gt 0) {
            $matchedCRB | Format-Table -AutoSize
        } else {
            Write-Host "No ClusterRoleBindings found referencing this SA."
        }
    } catch {
        Write-Host "Error getting ClusterRoleBindings: $_" -ForegroundColor Red
    }

    Write-Host "`n--- Related Token / Secret (if any) ---`n" -ForegroundColor Cyan
    try {
        $secJson = kubectl get secrets -n $ns --field-selector type=kubernetes.io/service-account-token -o json
        if ($LASTEXITCODE -eq 0 -and $secJson) {
            ($secJson | ConvertFrom-Json).items |
                Where-Object {
                    $_.annotations -and $_.annotations.'kubernetes.io/service-account.name' -eq $saName
                } |
                ForEach-Object {
                    "{0} (type: {1})" -f $_.metadata.name, $_.type
                }
        } else {
            Write-Host "Unable to list secrets or no service-account-token type secrets found."
        }
    } catch {
        Write-Host "Unable to list secrets: $_" -ForegroundColor Red
    }

    Write-Host "`n(Display complete.)`n"
}

function Show-HelpfulCommandsAndDocs {
    Write-Host "`n--- Useful Commands for ServiceAccount / RBAC ---`n" -ForegroundColor Cyan

    $commands = @(
        "kubectl get serviceaccounts --all-namespaces",
        "kubectl get serviceaccount <name> -n <namespace> -o yaml",
        "kubectl describe serviceaccount <name> -n <namespace>",
        "kubectl get rolebinding --all-namespaces -o yaml | less",
        "kubectl get clusterrolebinding -o yaml | less",
        "kubectl create serviceaccount <name> -n <namespace>",
        "kubectl create role <role-name> --verb=get,list,watch --resource=pods -n <namespace>",
        "kubectl create rolebinding <rb-name> --role=<role-name> --serviceaccount=<namespace>:<sa-name> -n <namespace>",
        "kubectl auth can-i <verb> <resource> --as=system:serviceaccount:<namespace>:<sa-name>",
        "kubectl get pods -n <namespace> -o json | jq '.items[] | select(.spec.serviceAccountName==""<sa-name>"") | .metadata.name'"
    )

    foreach ($c in $commands) {
        Write-Host " - $c"
    }

    Write-Host "`n--- Useful Reference Documentation ---`n" -ForegroundColor Yellow
    Write-Host "1) Kubernetes Service Accounts: https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/"
    Write-Host "2) Kubernetes RBAC: https://kubernetes.io/docs/reference/access-authn-authz/rbac/"
    Write-Host "3) Azure AKS RBAC: https://learn.microsoft.com/azure/aks/manage-azure-rbac"
    Write-Host "`nYou can copy the URLs above to your browser for detailed reading.`n"
}

# Main menu loop
if (-not (Test-Kubectl)) {
    Write-Host "Stopping program because kubectl is not available." -ForegroundColor Red
    exit 1
}

$exitProgram = $false
while (-not $exitProgram) {
    Write-Host "==========================================" -ForegroundColor DarkGray
    Write-Host "Menu - ServiceAccount Management" -ForegroundColor Green
    Write-Host "1) List all ServiceAccounts (all namespaces)"
    Write-Host "2) View details of a ServiceAccount (enter name & namespace)"
    Write-Host "3) Show useful commands and documentation"
    Write-Host "4) Exit"
    $choice = Read-Host "Choose [1-4]"

    switch ($choice) {
        "1" { List-AllServiceAccounts }
        "2" {
            $sa = Read-Host "Enter ServiceAccount name (e.g., my-app-sa)"
            $ns = Read-Host "Enter namespace of ServiceAccount (e.g., default)"
            Show-SA-Details -saName $sa -ns $ns
        }
        "3" { Show-HelpfulCommandsAndDocs }
        "4" {
            Write-Host "Exiting program. Goodbye!" -ForegroundColor Green
            $exitProgram = $true
        }
        default {
            Write-Host "Invalid choice. Please choose 1, 2, 3, or 4." -ForegroundColor Yellow
        }
    }
}
