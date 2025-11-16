<#
CIS 5.2.1 - Prefer Using Dedicated AKS Service Accounts (Compact Version)
Description: Simplified audit and remediation tool for CIS 5.2.1 compliance
Requirements: kubectl in PATH, kubeconfig configured
#>

# Console helpers
function Info($m)  { Write-Host $m -ForegroundColor Cyan }
function Ok($m)    { Write-Host $m -ForegroundColor Green }
function Warn($m)  { Write-Host $m -ForegroundColor Yellow }
function Err($m)   { Write-Host $m -ForegroundColor Red }

# Select namespace helper
function Select-Namespace {
    param([string]$Prompt = "Select namespace")
    
    try {
        $nsJson = kubectl get namespaces -o json 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $nsJson) { return $null }
        
        $namespaces = ($nsJson | ConvertFrom-Json).items
        Write-Host "\nAvailable Namespaces:" -ForegroundColor Cyan
        for ($i = 0; $i -lt $namespaces.Count; $i++) {
            Write-Host "  $($i + 1). $($namespaces[$i].metadata.name)"
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

# Core audit functions
function Find-DefaultSA-Violations {
    Write-Host "\n=== Checking Default ServiceAccount Violations ===" -ForegroundColor Cyan
    
    $violations = @()
    
    # Check RoleBindings
    $rbJson = kubectl get rolebinding --all-namespaces -o json 2>$null
    if ($LASTEXITCODE -eq 0 -and $rbJson) {
        $rbItems = ($rbJson | ConvertFrom-Json).items
        foreach ($rb in $rbItems) {
            if ($rb.subjects) {
                foreach ($subject in $rb.subjects) {
                    if ($subject.kind -eq "ServiceAccount" -and $subject.name -eq "default") {
                        $violations += "RoleBinding: $($rb.metadata.namespace)/$($rb.metadata.name)"
                    }
                }
            }
        }
    }
    
    # Check ClusterRoleBindings
    $crbJson = kubectl get clusterrolebinding -o json 2>$null
    if ($LASTEXITCODE -eq 0 -and $crbJson) {
        $crbItems = ($crbJson | ConvertFrom-Json).items
        foreach ($crb in $crbItems) {
            if ($crb.subjects) {
                foreach ($subject in $crb.subjects) {
                    if ($subject.kind -eq "ServiceAccount" -and $subject.name -eq "default") {
                        $violations += "ClusterRoleBinding: $($crb.metadata.name)"
                    }
                }
            }
        }
    }
    
    # Check Deployments
    $deployJson = kubectl get deployments --all-namespaces -o json 2>$null
    if ($LASTEXITCODE -eq 0 -and $deployJson) {
        $deployItems = ($deployJson | ConvertFrom-Json).items
        foreach ($deploy in $deployItems) {
            $saName = $deploy.spec.template.spec.serviceAccountName
            if ([string]::IsNullOrWhiteSpace($saName) -or $saName -eq "default") {
                $violations += "Deployment: $($deploy.metadata.namespace)/$($deploy.metadata.name)"
            }
        }
    }
    
    if ($violations.Count -gt 0) {
        Err "Found $($violations.Count) violations:"
        $violations | ForEach-Object { Write-Host "  ❌ $_" -ForegroundColor Red }
    } else {
        Ok "✅ No violations found"
    }
    
    return $violations
}

# Core remediation functions - Step 1: Create ServiceAccount
function Create-ServiceAccount {
    Write-Host "\n=== Step 1: Create ServiceAccount ===" -ForegroundColor Cyan
    
    $namespace = Select-Namespace -Prompt "Select namespace for ServiceAccount"
    if (-not $namespace) { return }
    
    $saName = Read-Host "Enter ServiceAccount name (e.g., myapp-sa)"
    if ([string]::IsNullOrWhiteSpace($saName)) {
        Warn "ServiceAccount name is required"
        return
    }
    
    try {
        kubectl create serviceaccount $saName -n $namespace
        if ($LASTEXITCODE -eq 0) {
            Ok "✅ ServiceAccount '$saName' created in namespace '$namespace'"
        } else {
            Err "❌ Failed to create ServiceAccount"
        }
    } catch {
        Err "Error: $_"
    }
}

# Step 2: Create Role
function Create-Role {
    Write-Host "\n=== Step 2: Create Role ===" -ForegroundColor Cyan
    
    $namespace = Select-Namespace -Prompt "Select namespace for Role"
    if (-not $namespace) { return }
    
    $roleName = Read-Host "Enter Role name (e.g., myapp-role)"
    if ([string]::IsNullOrWhiteSpace($roleName)) {
        Warn "Role name is required"
        return
    }
    
    Write-Host "\nPermission templates:" -ForegroundColor Cyan
    Write-Host "  1) Basic (get,list,watch pods,services,configmaps)"
    Write-Host "  2) Pod Manager (full pod permissions)"
    Write-Host "  3) Config Reader (get,list,watch configmaps,secrets)"
    Write-Host "  4) Custom"
    
    $choice = Read-Host "Select template (1-4)"
    
    try {
        switch ($choice) {
            "1" { kubectl create role $roleName --verb=get,list,watch --resource=pods,services,configmaps -n $namespace }
            "2" { kubectl create role $roleName --verb=get,list,watch,create,update,patch,delete --resource=pods -n $namespace }
            "3" { kubectl create role $roleName --verb=get,list,watch --resource=configmaps,secrets -n $namespace }
            "4" {
                $verbs = Read-Host "Enter verbs (comma-separated)"
                $resources = Read-Host "Enter resources (comma-separated)"
                kubectl create role $roleName --verb=$verbs --resource=$resources -n $namespace
            }
            default { Warn "Invalid choice"; return }
        }
        
        if ($LASTEXITCODE -eq 0) {
            Ok "✅ Role '$roleName' created in namespace '$namespace'"
        } else {
            Err "❌ Failed to create Role"
        }
    } catch {
        Err "Error: $_"
    }
}

# Step 3: Create RoleBinding
function Create-RoleBinding {
    Write-Host "\n=== Step 3: Create RoleBinding ===" -ForegroundColor Cyan
    
    $namespace = Select-Namespace -Prompt "Select namespace"
    if (-not $namespace) { return }
    
    # Get ServiceAccounts
    $saJson = kubectl get serviceaccounts -n $namespace -o json 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $saJson) {
        Err "Failed to get ServiceAccounts"
        return
    }
    
    $serviceAccounts = ($saJson | ConvertFrom-Json).items
    if ($serviceAccounts.Count -eq 0) {
        Err "No ServiceAccounts found"
        return
    }
    
    Write-Host "\nServiceAccounts:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $serviceAccounts.Count; $i++) {
        Write-Host "  $($i + 1). $($serviceAccounts[$i].metadata.name)"
    }
    
    do {
        $choice = Read-Host "Select ServiceAccount (enter number)"
        $ok = [int]::TryParse($choice,[ref]$null)
    } while (-not $ok -or [int]$choice -lt 1 -or [int]$choice -gt $serviceAccounts.Count)
    
    $saName = $serviceAccounts[[int]$choice - 1].metadata.name
    
    # Get Roles
    $rolesJson = kubectl get roles -n $namespace -o json 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $rolesJson) {
        Err "Failed to get Roles"
        return
    }
    
    $roles = ($rolesJson | ConvertFrom-Json).items
    if ($roles.Count -eq 0) {
        Err "No Roles found"
        return
    }
    
    Write-Host "\nRoles:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $roles.Count; $i++) {
        Write-Host "  $($i + 1). $($roles[$i].metadata.name)"
    }
    
    do {
        $choice = Read-Host "Select Role (enter number)"
        $ok = [int]::TryParse($choice,[ref]$null)
    } while (-not $ok -or [int]$choice -lt 1 -or [int]$choice -gt $roles.Count)
    
    $roleName = $roles[[int]$choice - 1].metadata.name
    $bindingName = "$saName-$roleName-binding"
    
    try {
        kubectl create rolebinding $bindingName --role=$roleName --serviceaccount="$namespace`:$saName" -n $namespace
        
        if ($LASTEXITCODE -eq 0) {
            Ok "✅ RoleBinding '$bindingName' created successfully!"
        } else {
            Err "❌ Failed to create RoleBinding"
        }
    } catch {
        Err "Error: $_"
    }
}

# Step 4: Show deployment example
function Show-Deployment-Example {
    Write-Host "\n=== Step 4: Update Deployment ===" -ForegroundColor Cyan
    
    $namespace = Select-Namespace -Prompt "Select namespace"
    if (-not $namespace) { return }
    
    $saJson = kubectl get serviceaccounts -n $namespace -o json 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $saJson) {
        Err "Failed to get ServiceAccounts"
        return
    }
    
    $serviceAccounts = ($saJson | ConvertFrom-Json).items | Where-Object { $_.metadata.name -ne "default" }
    if ($serviceAccounts.Count -eq 0) {
        Err "No dedicated ServiceAccounts found"
        return
    }
    
    Write-Host "\nServiceAccounts:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $serviceAccounts.Count; $i++) {
        Write-Host "  $($i + 1). $($serviceAccounts[$i].metadata.name)"
    }
    
    do {
        $choice = Read-Host "Select ServiceAccount (enter number)"
        $ok = [int]::TryParse($choice,[ref]$null)
    } while (-not $ok -or [int]$choice -lt 1 -or [int]$choice -gt $serviceAccounts.Count)
    
    $saName = $serviceAccounts[[int]$choice - 1].metadata.name
    $appName = Read-Host "Enter app name (e.g., myapp)"
    
    if ([string]::IsNullOrWhiteSpace($appName)) { $appName = "myapp" }
    
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
      serviceAccountName: $saName  # 👈 Key line!
      containers:
        - name: $appName
          image: nginx:latest
          ports:
            - containerPort: 80
"@
    
    Write-Host "\nDeployment YAML:" -ForegroundColor Yellow
    Write-Host $yaml -ForegroundColor White
    
    Write-Host "\nTo apply:" -ForegroundColor Cyan
    Write-Host "kubectl apply -f deployment.yaml"
    
    Write-Host "\nTo patch existing deployment:" -ForegroundColor Cyan
    Write-Host "kubectl patch deployment $appName -n $namespace -p '{\"spec\":{\"template\":{\"spec\":{\"serviceAccountName\":\"$saName\"}}}}'"
}

# Test permissions
function Test-Permissions {
    Write-Host "\n=== Test ServiceAccount Permissions ===" -ForegroundColor Cyan
    
    $namespace = Select-Namespace -Prompt "Select namespace"
    if (-not $namespace) { return }
    
    $saJson = kubectl get serviceaccounts -n $namespace -o json 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $saJson) {
        Err "Failed to get ServiceAccounts"
        return
    }
    
    $serviceAccounts = ($saJson | ConvertFrom-Json).items
    Write-Host "\nServiceAccounts:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $serviceAccounts.Count; $i++) {
        Write-Host "  $($i + 1). $($serviceAccounts[$i].metadata.name)"
    }
    
    do {
        $choice = Read-Host "Select ServiceAccount (enter number)"
        $ok = [int]::TryParse($choice,[ref]$null)
    } while (-not $ok -or [int]$choice -lt 1 -or [int]$choice -gt $serviceAccounts.Count)
    
    $saName = $serviceAccounts[[int]$choice - 1].metadata.name
    
    $tests = @("get pods", "list pods", "create pods", "get services", "get configmaps", "get secrets")
    
    Write-Host "\nPermission test results:" -ForegroundColor Cyan
    foreach ($test in $tests) {
        $parts = $test -split " "
        $result = kubectl auth can-i $parts[0] $parts[1] --as="system:serviceaccount:$namespace`:$saName" -n $namespace 2>$null
        if ($result -eq "yes") {
            Write-Host "  ✅ $test" -ForegroundColor Green
        } else {
            Write-Host "  ❌ $test" -ForegroundColor Red
        }
    }
}

# Generate simple report
function Generate-Report {
    Write-Host "\n=== Generate Compliance Report ===" -ForegroundColor Cyan
    
    $reportFile = "CIS-5.2.1-Report-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
    $report = @()
    
    $report += "CIS 5.2.1 Service Account Compliance Report"
    $report += "Generated: $(Get-Date)"
    $report += "=" * 50
    
    # Check violations
    $violations = Find-DefaultSA-Violations
    
    $report += ""
    $report += "SUMMARY:"
    if ($violations.Count -eq 0) {
        $report += "STATUS: COMPLIANT ✅"
    } else {
        $report += "STATUS: NON-COMPLIANT ❌"
        $report += "Violations: $($violations.Count)"
        $violations | ForEach-Object { $report += "  - $_" }
    }
    
    $report | Out-File -FilePath $reportFile -Encoding UTF8
    Ok "Report saved to: $reportFile"
}

# Check kubectl availability
function Test-Kubectl {
    $kubectlCommand = Get-Command kubectl -ErrorAction SilentlyContinue
    if (-not $kubectlCommand) {
        Err "kubectl not found. Please install kubectl and configure kubeconfig."
        return $false
    }
    
    try {
        $null = kubectl cluster-info 2>&1
        if ($LASTEXITCODE -eq 0) {
            Ok "kubectl: Connected to cluster"
            return $true
        } else {
            Warn "kubectl found but cannot connect to cluster"
            return $true
        }
    } catch {
        Warn "Warning checking kubectl: $_"
        return $true
    }
}

# Main menu
if (-not (Test-Kubectl)) {
    exit 1
}

$exitProgram = $false
while (-not $exitProgram) {
    Write-Host "=" * 60 -ForegroundColor DarkGray
    Write-Host "CIS 5.2.1 - ServiceAccount Security (Compact)" -ForegroundColor Green
    Write-Host "=" * 60 -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "🎯 WORKFLOW: SA → Role → RoleBinding → Deployment" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "=== MAIN WORKFLOW ==="
    Write-Host "  1) Create ServiceAccount"
    Write-Host "  2) Create Role"
    Write-Host "  3) Create RoleBinding"
    Write-Host "  4) Show Deployment example"
    Write-Host ""
    Write-Host "=== AUDIT & TEST ==="
    Write-Host "  5) Check violations"
    Write-Host "  6) Test permissions"
    Write-Host "  7) Generate report"
    Write-Host "  8) Exit"
    Write-Host ""
    
    $choice = Read-Host "Your choice (1-8)"
    
    switch ($choice) {
        "1" { Create-ServiceAccount; Read-Host "Press Enter to continue" }
        "2" { Create-Role; Read-Host "Press Enter to continue" }
        "3" { Create-RoleBinding; Read-Host "Press Enter to continue" }
        "4" { Show-Deployment-Example; Read-Host "Press Enter to continue" }
        "5" { Find-DefaultSA-Violations; Read-Host "Press Enter to continue" }
        "6" { Test-Permissions; Read-Host "Press Enter to continue" }
        "7" { Generate-Report; Read-Host "Press Enter to continue" }
        "8" { Write-Host "Goodbye!" -ForegroundColor Green; $exitProgram = $true }
        default { Warn "Invalid choice. Please choose 1-8."; Start-Sleep -Seconds 1 }
    }
}