param(
    [string]$EnableModify
)

# Function to check for wildcards in Role/ClusterRole JSON
function CheckPodCreate {
    param (
        [object]$RolesJson,
        [string]$Type
    )

    $results = @()

    foreach ($role in $RolesJson.items) {
        $hasPodCreate = $false

        foreach ($rule in $role.rules) {
            if (-not $rule) { continue }

            # Normalize arrays (avoid nulls)
            $resources = @($rule.resources) | Where-Object { $_ -ne $null }
            $verbs     = @($rule.verbs) | Where-Object { $_ -ne $null }

            # Check wildcards
            if ($apiGroups -contains "*" -or $resources -contains "*" -or $verbs -contains "*") {
                $hasPodCreate = $true
            }
        }

        if ($hasPodCreate) {
            $results += [PSCustomObject]@{
                Type             = $Type
                Namespace        = $role.metadata.namespace
                RoleName         = $role.metadata.name
                HasPodCreate = $hasPodCreate
            }
        }
    }

    return $results
}

# Function to remove secret access rules
function RemoveSecretAccessRules {
    param (
        [object]$RolesJson,
        [string]$Type
    )

    foreach ($role in $RolesJson) {
        $updatedRules = @()

        foreach ($rule in @($role.rules)) {
            if (-not $rule) { continue }

            $apiGroups = @($rule.apiGroups) | Where-Object { $_ -ne $null }
            $resources = @($rule.resources) | Where-Object { $_ -ne $null }
            $verbs     = @($rule.verbs) | Where-Object { $_ -ne $null }

            $containsWildcard =  ($apiGroups -contains "*" -or $resources -contains "*" -or $verbs -contains "*")
            if (-not $containsWildcard) {
                $updatedRules += $rule
            }
        }

        if ($updatedRules.Count -ne @($role.rules).Count) {
            Write-Host "Updating $Type '$($role.metadata.name)' in namespace '$($role.metadata.namespace)'..." -ForegroundColor Yellow
            $role.rules = $updatedRules
            $role | ConvertTo-Json -Depth 10 | kubectl apply -f -
        }
    }
}

# --- Main Script ---
Write-Host "----Checking section 4.1.4: Minimize access to create Pods----" -ForegroundColor Yellow

# Get JSON for roles and clusterroles
$rolesJson = kubectl get roles --all-namespaces -o json | ConvertFrom-Json
$clusterRolesJson = kubectl get clusterroles -o json | ConvertFrom-Json

# Analyze both
$roleResults = CheckPodCreate -RolesJson $rolesJson -Type "Role"
$clusterRoleResults = CheckPodCreate -RolesJson $clusterRolesJson -Type "ClusterRole"

# Combine results
$allResults = $roleResults + $clusterRoleResults

# Display
if ($allResults.Count -eq 0) {
    Write-Host "No pod creation permission found in any Role or ClusterRole." -ForegroundColor Green
} else {
    Write-Host "Pod creation permission detected in the following RBAC definitions:" -ForegroundColor Yellow
    $allResults | Format-Table -AutoSize

    if ($EnableModify -eq "true") {
        # --- Remove Role secret access ---
        Write-Host "Enter Roles to remove secret access (format: namespace/name, separated by commas):" -ForegroundColor Cyan
        $roleNamesStr = Read-Host
        $roleNames = $roleNamesStr -split "," | ForEach-Object { $_.Trim() }
        $rolesJsonToUpdate = @()

        foreach ($roleEntry in $roleNames) {
            $parts = $roleEntry -split "/"
            if ($parts.Count -ne 2) {
                Write-Host "Skipping invalid Role entry: $roleEntry" -ForegroundColor Red
                continue
            }
            $namespace = $parts[0]
            $name = $parts[1]
            $rolesJsonToUpdate += kubectl get role $name -n $namespace -o json | ConvertFrom-Json
        }
        RemoveSecretAccessRules -Type "Role" -RolesJson $rolesJsonToUpdate

        # --- Remove ClusterRole secret access ---
        Write-Host "Enter ClusterRoles to remove secret access (separated by commas):" -ForegroundColor Cyan
        $clusterRoleNamesStr = Read-Host
        $clusterRoleNames = $clusterRoleNamesStr -split "," | ForEach-Object { $_.Trim() }
        $clusterRolesJsonToUpdate = @()
        foreach ($roleName in $clusterRoleNames) {
            $clusterRolesJsonToUpdate += kubectl get clusterrole $roleName -o json | ConvertFrom-Json
        }
        RemoveSecretAccessRules -Type "ClusterRole" -RolesJson $clusterRolesJsonToUpdate
    }
}