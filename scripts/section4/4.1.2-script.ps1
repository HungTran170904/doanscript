param(
    [string]$EnableModify
)

# --- Function to check for secret access ---
function CheckSecretAccess {
    param (
        [object]$RolesJson,
        [string]$Type
    )

    $results = @()

    foreach ($role in $RolesJson.items) {
        $hasSecretAccess = $false

        foreach ($rule in @($role.rules)) {
            if (-not $rule) { continue }

            $resources = @($rule.resources) | Where-Object { $_ -ne $null }
            $verbs     = @($rule.verbs) | Where-Object { $_ -ne $null }

            if (($resources -contains "secrets" -or $resources -contains "*") -and
                ($verbs -contains "*" -or $verbs -contains "get" -or
                 $verbs -contains "watch" -or $verbs -contains "list")) {
                $hasSecretAccess = $true
            }
        }

        if ($hasSecretAccess) {
            $results += [PSCustomObject]@{
                Type             = $Type
                Namespace        = $role.metadata.namespace
                RoleName         = $role.metadata.name
                HasSecretAccess  = $hasSecretAccess
            }
        }
    }

    return $results
}

# --- Function to remove secret access rules ---
function RemoveSecretAccessRules {
    param (
        [object]$RolesJson,
        [string]$Type
    )

    foreach ($role in $RolesJson) {
        $updatedRules = @()

        foreach ($rule in @($role.rules)) {
            if (-not $rule) { continue }

            $resources = @($rule.resources) | Where-Object { $_ -ne $null }
            $verbs     = @($rule.verbs) | Where-Object { $_ -ne $null }

            $hasSecretAccess = ($resources -contains "secrets" -or $resources -contains "*") -and
                               ($verbs -contains "*" -or $verbs -contains "get" -or
                                $verbs -contains "watch" -or $verbs -contains "list")

            if (-not $hasSecretAccess) {
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

# --- Main script ---
Write-Host "----Checking section 4.1.2: Minimize access to secrets----" -ForegroundColor Yellow

$rolesJson = kubectl get roles --all-namespaces -o json | ConvertFrom-Json
$clusterRolesJson = kubectl get clusterroles -o json | ConvertFrom-Json

$roleResults = CheckSecretAccess -RolesJson $rolesJson -Type "Role"
$clusterRoleResults = CheckSecretAccess -RolesJson $clusterRolesJson -Type "ClusterRole"

$allResults = @($roleResults) + @($clusterRoleResults)

if ($allResults.Count -eq 0) {
    Write-Host "No secret access found in any Role or ClusterRole." -ForegroundColor Green
} else {
    Write-Host "Secret access detected in the following RBAC definitions:" -ForegroundColor Yellow
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