<#
CIS 5.2.1 - Prefer Using Dedicated AKS Service Accounts
Description: Audit and remediation tool for CIS 5.2.1 compliance
Requirements: kubectl in PATH, kubeconfig configured, Azure CLI for AKS features
#>

# Console helpers
function Info($m)  { Write-Host $m -ForegroundColor Cyan }
function Ok($m)    { Write-Host $m -ForegroundColor Green }
function Warn($m)  { Write-Host $m -ForegroundColor Yellow }
function Err($m)   { Write-Host $m -ForegroundColor Red }
function Pause-Enter { Read-Host "Press Enter to continue..." | Out-Null }

# ===== SELECTION HELPERS =====



function Select-Namespace {
    param([string]$Prompt = "Select namespace")
    
    try {
        $nsJson = kubectl get namespaces -o json 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $nsJson) {
            Err "Failed to get namespaces"
            return $null
        }
        
        $namespaces = ($nsJson | ConvertFrom-Json).items
        if ($namespaces.Count -eq 0) {
            Warn "No namespaces found"
            return $null
        }
        
        Write-Host "\nAvailable Namespaces:" -ForegroundColor Cyan
        for ($i = 0; $i -lt $namespaces.Count; $i++) {
            $status = $namespaces[$i].status.phase
            Write-Host "  $($i + 1). $($namespaces[$i].metadata.name) [$status]"
        }
        
        do {
            $choice = Read-Host "\n$Prompt (enter number)"
            $ok = [int]::TryParse($choice,[ref]$null)
        } while (-not $ok -or [int]$choice -lt 1 -or [int]$choice -gt $namespaces.Count)
        
        return $namespaces[[int]$choice - 1].metadata.name
    } catch {
        Err "Error selecting namespace: $_"
        return $null
    }
}

# ===== CIS 5.2.1 AUDIT FUNCTIONS =====

function Find-DefaultSA-RoleBindings {
    Write-Host "`n=== 1.1 Checking RoleBindings assigned to default ServiceAccount ===" -ForegroundColor Cyan
    
    try {
        $rbJson = kubectl get rolebinding --all-namespaces -o json 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $rbJson) {
            Err "Failed to get RoleBindings"
            return
        }
        
        $rbItems = ($rbJson | ConvertFrom-Json).items
        $violations = @()
        
        foreach ($rb in $rbItems) {
            if ($rb.subjects) {
                foreach ($subject in $rb.subjects) {
                    if ($subject.kind -eq "ServiceAccount" -and $subject.name -eq "default") {
                        $violations += "Namespace: $($rb.metadata.namespace) | RB: $($rb.metadata.name)"
                    }
                }
            }
        }
        
        if ($violations.Count -gt 0) {
            Err "Found $($violations.Count) RoleBinding violations:"
            $violations | ForEach-Object { Write-Host "  $_" }
        } else {
            Ok "No RoleBinding violations found"
        }
        
        return $violations
    } catch {
        Err "Error checking RoleBindings: $_"
    }
}

function Find-DefaultSA-ClusterRoleBindings {
    Write-Host "`n=== 1.2 Checking ClusterRoleBindings assigned to default ServiceAccount ===" -ForegroundColor Cyan
    
    try {
        $crbJson = kubectl get clusterrolebinding -o json 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $crbJson) {
            Err "Failed to get ClusterRoleBindings"
            return
        }
        
        $crbItems = ($crbJson | ConvertFrom-Json).items
        $violations = @()
        
        foreach ($crb in $crbItems) {
            if ($crb.subjects) {
                foreach ($subject in $crb.subjects) {
                    if ($subject.kind -eq "ServiceAccount" -and $subject.name -eq "default") {
                        $violations += "CRB: $($crb.metadata.name)"
                    }
                }
            }
        }
        
        if ($violations.Count -gt 0) {
            Err "Found $($violations.Count) ClusterRoleBinding violations:"
            $violations | ForEach-Object { Write-Host "  $_" }
        } else {
            Ok "No ClusterRoleBinding violations found"
        }
        
        return $violations
    } catch {
        Err "Error checking ClusterRoleBindings: $_"
    }
}





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

# ===== CIS 5.2.1 REMEDIATION FUNCTIONS =====

function Create-Simple-Role {
    Write-Host "`n=== Step 2: Create Role ===" -ForegroundColor Cyan
    Write-Host "This creates a Role with specific permissions in a namespace." -ForegroundColor Gray
    
    # Select namespace
    $namespace = Select-Namespace -Prompt "Select namespace for Role"
    if (-not $namespace) { return }
    
    # Get role name
    $roleName = Read-Host "Enter Role name (e.g., myapp-role)"
    if ([string]::IsNullOrWhiteSpace($roleName)) {
        Warn "Role name is required"
        return
    }
    
    # Simple permission templates
    Write-Host "`nCommon permission templates:" -ForegroundColor Cyan
    Write-Host "  1) Basic App (get,list,watch pods,services,configmaps)"
    Write-Host "  2) Pod Manager (full pod permissions)"
    Write-Host "  3) Config Reader (get,list,watch configmaps,secrets)"
    Write-Host "  4) Custom permissions"
    
    $permChoice = Read-Host "Select template (1-4)"
    
    try {
        switch ($permChoice) {
            "1" {
                kubectl create role $roleName --verb=get,list,watch --resource=pods,services,configmaps -n $namespace
                Info "Created basic app role with read permissions on pods, services, configmaps"
            }
            "2" {
                kubectl create role $roleName --verb=get,list,watch,create,update,patch,delete --resource=pods -n $namespace
                Info "Created pod manager role with full pod permissions"
            }
            "3" {
                kubectl create role $roleName --verb=get,list,watch --resource=configmaps,secrets -n $namespace
                Info "Created config reader role with read permissions on configmaps and secrets"
            }
            "4" {
                $verbs = Read-Host "Enter verbs (comma-separated, e.g., get,list,watch)"
                $resources = Read-Host "Enter resources (comma-separated, e.g., pods,services)"
                kubectl create role $roleName --verb=$verbs --resource=$resources -n $namespace
                Info "Created custom role"
            }
            default {
                Warn "Invalid choice"
                return
            }
        }
        
        if ($LASTEXITCODE -eq 0) {
            Ok "✅ Role '$roleName' created successfully in namespace '$namespace'"
            Info "Next step: Create RoleBinding to link ServiceAccount to this Role (option 3)"
        } else {
            Err "❌ Failed to create Role"
        }
        
    } catch {
        Err "Error creating Role: $_"
    }
}

function Create-Simple-RoleBinding {
    Write-Host "`n=== Step 3: Create RoleBinding ===" -ForegroundColor Cyan
    Write-Host "This links a ServiceAccount to a Role, granting the permissions." -ForegroundColor Gray
    
    # Select namespace
    $namespace = Select-Namespace -Prompt "Select namespace"
    if (-not $namespace) { return }
    
    # List and select ServiceAccount
    try {
        $saJson = kubectl get serviceaccounts -n $namespace -o json 2>$null
        if ($LASTEXITCODE -eq 0 -and $saJson) {
            $serviceAccounts = ($saJson | ConvertFrom-Json).items
            if ($serviceAccounts.Count -gt 0) {
                Write-Host "`nAvailable ServiceAccounts in '$namespace':" -ForegroundColor Cyan
                for ($i = 0; $i -lt $serviceAccounts.Count; $i++) {
                    Write-Host "  $($i + 1). $($serviceAccounts[$i].metadata.name)"
                }
                
                do {
                    $choice = Read-Host "`nSelect ServiceAccount (enter number)"
                    $ok = [int]::TryParse($choice,[ref]$null)
                } while (-not $ok -or [int]$choice -lt 1 -or [int]$choice -gt $serviceAccounts.Count)
                
                $saName = $serviceAccounts[[int]$choice - 1].metadata.name
            } else {
                Err "No ServiceAccounts found in namespace $namespace"
                Info "Please create a ServiceAccount first (option 1)"
                return
            }
        } else {
            Err "Failed to get ServiceAccounts"
            return
        }
    } catch {
        Err "Error getting ServiceAccounts: $_"
        return
    }
    
    # List and select Role
    try {
        $rolesJson = kubectl get roles -n $namespace -o json 2>$null
        if ($LASTEXITCODE -eq 0 -and $rolesJson) {
            $roles = ($rolesJson | ConvertFrom-Json).items
            if ($roles.Count -gt 0) {
                Write-Host "`nAvailable Roles in '$namespace':" -ForegroundColor Cyan
                for ($i = 0; $i -lt $roles.Count; $i++) {
                    Write-Host "  $($i + 1). $($roles[$i].metadata.name)"
                }
                
                do {
                    $choice = Read-Host "`nSelect Role (enter number)"
                    $ok = [int]::TryParse($choice,[ref]$null)
                } while (-not $ok -or [int]$choice -lt 1 -or [int]$choice -gt $roles.Count)
                
                $roleName = $roles[[int]$choice - 1].metadata.name
            } else {
                Err "No Roles found in namespace $namespace"
                Info "Please create a Role first (option 2)"
                return
            }
        } else {
            Err "Failed to get Roles"
            return
        }
    } catch {
        Err "Error getting Roles: $_"
        return
    }
    
    # Create RoleBinding name
    $bindingName = "$saName-$roleName-binding"
    
    # Show what will be created
    Write-Host "`nCreating RoleBinding:" -ForegroundColor Yellow
    Write-Host "  Name: $bindingName"
    Write-Host "  ServiceAccount: $saName"
    Write-Host "  Role: $roleName"
    Write-Host "  Namespace: $namespace"
    
    $confirm = Read-Host "`nContinue? (yes/no)"
    if ($confirm -ne "yes") {
        Info "Operation cancelled"
        return
    }
    
    try {
        kubectl create rolebinding $bindingName --role=$roleName --serviceaccount="$namespace`:$saName" -n $namespace
        
        if ($LASTEXITCODE -eq 0) {
            Ok "✅ RoleBinding '$bindingName' created successfully!"
            Write-Host ""
            Ok "🎉 Setup complete! ServiceAccount '$saName' now has permissions defined in Role '$roleName'"
            Info "Next step: Update your Deployment to use serviceAccountName: $saName (option 4)"
        } else {
            Err "❌ Failed to create RoleBinding"
        }
        
    } catch {
        Err "Error creating RoleBinding: $_"
    }
}

function Create-DedicatedServiceAccount {
    Write-Host "`n=== Step 1: Create ServiceAccount ===" -ForegroundColor Cyan
    Write-Host "This creates a dedicated ServiceAccount for your application." -ForegroundColor Gray
    
    # Choose namespace option
    Write-Host "`nNamespace options:" -ForegroundColor Cyan
    Write-Host "  1) Use existing namespace"
    Write-Host "  2) Create new namespace"
    
    $nsChoice = Read-Host "Your choice (1-2)"
    
    if ($nsChoice -eq "1") {
        $namespace = Select-Namespace -Prompt "Select namespace for ServiceAccount"
        if (-not $namespace) { return }
    } elseif ($nsChoice -eq "2") {
        $namespace = Read-Host "Enter new namespace name (e.g., myapp-prod)"
        if ([string]::IsNullOrWhiteSpace($namespace)) {
            Warn "Namespace name is required"
            return
        }
        
        # Create namespace
        Write-Host "Creating namespace '$namespace'..." -ForegroundColor Cyan
        kubectl create namespace $namespace 2>$null
        if ($LASTEXITCODE -eq 0) {
            Ok "Namespace '$namespace' created"
        } else {
            Warn "Namespace might already exist (continuing...)"
        }
    } else {
        Warn "Invalid choice"
        return
    }
    
    # Get ServiceAccount name
    $saName = Read-Host "Enter ServiceAccount name (e.g., myapp-sa)"
    if ([string]::IsNullOrWhiteSpace($saName)) {
        Warn "ServiceAccount name is required"
        return
    }
    
    # Show what will be created
    Write-Host "`nCreating ServiceAccount:" -ForegroundColor Yellow
    Write-Host "  Name: $saName"
    Write-Host "  Namespace: $namespace"
    
    try {
        # Create ServiceAccount
        kubectl create serviceaccount $saName -n $namespace
        
        if ($LASTEXITCODE -eq 0) {
            Ok "✅ ServiceAccount '$saName' created successfully in namespace '$namespace'"
            Info "Next step: Create a Role to define permissions (option 2)"
        } else {
            Err "❌ Failed to create ServiceAccount"
            Info "ServiceAccount might already exist. Check with: kubectl get sa -n $namespace"
        }
        
    } catch {
        Err "Error creating ServiceAccount: $_"
    }
}







function Show-Deployment-Example {
    Write-Host "`n=== Step 4: Update Deployment to use ServiceAccount ===" -ForegroundColor Cyan
    Write-Host "This shows how to update your Deployment to use the ServiceAccount." -ForegroundColor Gray
    
    # Select namespace
    $namespace = Select-Namespace -Prompt "Select namespace"
    if (-not $namespace) { return }
    
    # Select ServiceAccount
    try {
        $saJson = kubectl get serviceaccounts -n $namespace -o json 2>$null
        if ($LASTEXITCODE -eq 0 -and $saJson) {
            $serviceAccounts = ($saJson | ConvertFrom-Json).items | Where-Object { $_.metadata.name -ne "default" }
            if ($serviceAccounts.Count -gt 0) {
                Write-Host "`nAvailable ServiceAccounts in '$namespace':" -ForegroundColor Cyan
                for ($i = 0; $i -lt $serviceAccounts.Count; $i++) {
                    Write-Host "  $($i + 1). $($serviceAccounts[$i].metadata.name)"
                }
                
                do {
                    $choice = Read-Host "`nSelect ServiceAccount (enter number)"
                    $ok = [int]::TryParse($choice,[ref]$null)
                } while (-not $ok -or [int]$choice -lt 1 -or [int]$choice -gt $serviceAccounts.Count)
                
                $saName = $serviceAccounts[[int]$choice - 1].metadata.name
            } else {
                Err "No dedicated ServiceAccounts found in namespace $namespace"
                Info "Please create a ServiceAccount first (option 1)"
                return
            }
        } else {
            Err "Failed to get ServiceAccounts"
            return
        }
    } catch {
        Err "Error getting ServiceAccounts: $_"
        return
    }
    
    $appName = Read-Host "Enter your application name (e.g., myapp)"
    if ([string]::IsNullOrWhiteSpace($appName)) {
        $appName = "myapp"
    }
    
    $yaml = @"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $appName
  namespace: $namespace
spec:
  replicas: 2
  selector:
    matchLabels:
      app: $appName
  template:
    metadata:
      labels:
        app: $appName
    spec:
      serviceAccountName: $saName  # 👈 This is the key line!
      containers:
        - name: $appName
          image: nginx:latest  # Replace with your image
          ports:
            - containerPort: 80
"@
    
    Write-Host "`n" + ("=" * 60) -ForegroundColor Yellow
    Write-Host "DEPLOYMENT YAML EXAMPLE" -ForegroundColor Yellow
    Write-Host ("=" * 60) -ForegroundColor Yellow
    Write-Host $yaml -ForegroundColor White
    Write-Host ("=" * 60) -ForegroundColor Yellow
    
    Write-Host "`nTo apply this deployment:" -ForegroundColor Cyan
    Write-Host "1. Save the YAML above to a file (e.g., deployment.yaml)"
    Write-Host "2. Run: kubectl apply -f deployment.yaml"
    
    Write-Host "`nTo patch an existing deployment:" -ForegroundColor Cyan
    Write-Host "kubectl patch deployment $appName -n $namespace -p '{\"spec\":{\"template\":{\"spec\":{\"serviceAccountName\":\"$saName\"}}}}'"
    
    Write-Host "`nTo verify the deployment uses the ServiceAccount:" -ForegroundColor Cyan
    Write-Host "kubectl get pods -n $namespace -o yaml | grep serviceAccountName"
}





function Remove-DefaultSA-Bindings {
    Write-Host "`n=== 2.8 Remove bindings from default ServiceAccount ===" -ForegroundColor Cyan
    
    Write-Host "\nScope options:"
    Write-Host "  1) Specific namespace"
    Write-Host "  2) All namespaces (cluster-wide)"
    
    $scopeChoice = Read-Host "\nSelect scope (1-2)"
    
    if ($scopeChoice -eq "1") {
        $namespace = Select-Namespace -Prompt "Select namespace to clean up"
        if (-not $namespace) { return }
    } elseif ($scopeChoice -eq "2") {
        $namespace = "all"
    } else {
        Warn "Invalid choice"
        return
    }
    
    Warn "This will remove RoleBindings/ClusterRoleBindings from default ServiceAccount"
    $confirm = Read-Host "Continue? (yes/no)"
    
    if ($confirm -ne "yes") {
        Info "Operation cancelled"
        return
    }
    
    try {
        # Backup first
        $backupDir = "backup-default-sa-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
        Info "Creating backups in: $backupDir"
        
        if ($namespace -eq "all") {
            # Remove ClusterRoleBindings
            $crbJson = kubectl get clusterrolebinding -o json
            $crbItems = ($crbJson | ConvertFrom-Json).items
            
            foreach ($crb in $crbItems) {
                if ($crb.subjects) {
                    foreach ($subject in $crb.subjects) {
                        if ($subject.kind -eq "ServiceAccount" -and $subject.name -eq "default") {
                            $backupFile = "$backupDir\clusterrolebinding-$($crb.metadata.name).yaml"
                            kubectl get clusterrolebinding $crb.metadata.name -o yaml > $backupFile
                            kubectl delete clusterrolebinding $crb.metadata.name
                            Info "Removed ClusterRoleBinding: $($crb.metadata.name)"
                            break
                        }
                    }
                }
            }
        } else {
            # Remove RoleBindings in specific namespace
            $rbJson = kubectl get rolebinding -n $namespace -o json
            $rbItems = ($rbJson | ConvertFrom-Json).items
            
            foreach ($rb in $rbItems) {
                if ($rb.subjects) {
                    foreach ($subject in $rb.subjects) {
                        if ($subject.kind -eq "ServiceAccount" -and $subject.name -eq "default") {
                            $backupFile = "$backupDir\rolebinding-$($rb.metadata.name).yaml"
                            kubectl get rolebinding $rb.metadata.name -n $namespace -o yaml > $backupFile
                            kubectl delete rolebinding $rb.metadata.name -n $namespace
                            Info "Removed RoleBinding: $($rb.metadata.name)"
                            break
                        }
                    }
                }
            }
        }
        
        Ok "Bindings removed. Backups saved to: $backupDir"
        Info "To restore: kubectl apply -f $backupDir\"
    } catch {
        Err "Error removing bindings: $_"
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
    Write-Host "=================================================" -ForegroundColor DarkGray
    Write-Host "CIS 5.2.1 - Prefer Using Dedicated Service Accounts" -ForegroundColor Green
    Write-Host "=================================================" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "🎯 SIMPLE WORKFLOW:" -ForegroundColor Yellow
    Write-Host "   Create ServiceAccount → Create Role → Create RoleBinding → Update Deployment" -ForegroundColor Gray
    Write-Host ""
    Write-Host "=== AUDIT & VERIFICATION ==="
    Write-Host "  1) Run complete audit"
    Write-Host ""
    Write-Host "=== MAIN WORKFLOW (Recommended Order) ==="
    Write-Host "  2) Create ServiceAccount"
    Write-Host "  3) Create Role (define permissions)"
    Write-Host "  4) Create RoleBinding (link SA to Role)"
    Write-Host "  5) Update Deployment to use SA"
    Write-Host "  6) Exit"
    Write-Host ""
    $choice = Read-Host "Your choice (1-6)"

    switch ($choice) {
        "1" { 
            Write-Host "`n=== COMPLETE CIS 5.2.1 AUDIT ===" -ForegroundColor Magenta
            Find-DefaultSA-RoleBindings
            Find-DefaultSA-ClusterRoleBindings
            
            # Check workloads using default ServiceAccount
            Write-Host "`n=== 1.3 Checking workloads using default ServiceAccount ===" -ForegroundColor Cyan
            try {
                $deployJson = kubectl get deployments --all-namespaces -o json 2>$null
                if ($LASTEXITCODE -eq 0 -and $deployJson) {
                    $deployItems = ($deployJson | ConvertFrom-Json).items
                    $violations = @()
                    
                    foreach ($deploy in $deployItems) {
                        $saName = $deploy.spec.template.spec.serviceAccountName
                        if ([string]::IsNullOrWhiteSpace($saName) -or $saName -eq "default") {
                            $violations += "Deployment: $($deploy.metadata.namespace)/$($deploy.metadata.name)"
                        }
                    }
                    
                    if ($violations.Count -gt 0) {
                        Err "Found $($violations.Count) workload violations:"
                        $violations | ForEach-Object { Write-Host "  $_" }
                    } else {
                        Ok "No workload violations found"
                    }
                } else {
                    Warn "Failed to get Deployments"
                }
            } catch {
                Err "Error checking workloads: $_"
            }
            
            Read-Host "Press Enter to continue"
        }
        "2" { Create-DedicatedServiceAccount; Read-Host "Press Enter to continue" }
        "3" { Create-Simple-Role; Read-Host "Press Enter to continue" }
        "4" { Create-Simple-RoleBinding; Read-Host "Press Enter to continue" }
        "5" { Show-Deployment-Example; Read-Host "Press Enter to continue" }
        "6" {
            Write-Host "Goodbye!" -ForegroundColor Green
            $exitProgram = $true
        }
        default {
            Write-Host "Invalid choice. Please choose 1-6." -ForegroundColor Yellow
            Start-Sleep -Seconds 2
        }
    }
}
